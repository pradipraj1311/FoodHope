import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ActiveDeliveryCard extends StatelessWidget {
  final String volunteerUid;

  const ActiveDeliveryCard({super.key, required this.volunteerUid});

  // --- MAPS & PHONE UTILS ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openGoogleMaps(double lat, double lon) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon";
    final Uri launchUri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  }

  // --- ACTION: MARK AS PICKED UP ---
  Future<void> _markAsPickedUp(BuildContext context, String donationId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.orange)));

    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Picked Up',
      'pickedUpAt': FieldValue.serverTimestamp(),
    });

    if (context.mounted) Navigator.pop(context); // close dialog
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Listen ONLY for active deliveries assigned to THIS volunteer
        stream: FirebaseFirestore.instance.collection('donations')
            .where('volunteerUid', isEqualTo: volunteerUid)
            .where('status', whereIn: ['Accepted', 'Picked Up', 'En Route']) // En Route is sometimes used as a synonym for Picked Up
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: Colors.green)));
          }

          // If they have no active deliveries, return nothing (an empty box)
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const SizedBox.shrink();
          }

          // We assume they can only have ONE active delivery at a time (enforced by Wave 1)
          var doc = snapshot.data!.docs.first;
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';
          bool isPickedUp = status == 'Picked Up' || status == 'En Route';

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isPickedUp ? Colors.teal.shade300 : Colors.orange.shade300, width: 2),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- HEADER BAR ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isPickedUp ? Colors.teal.shade50 : Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  ),
                  child: Row(
                    children: [
                      Icon(isPickedUp ? Icons.local_shipping : Icons.restaurant_menu, color: isPickedUp ? Colors.teal.shade700 : Colors.orange.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(isPickedUp ? "STEP 2: DROPOFF AT NGO" : "STEP 1: PICKUP FOOD", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: isPickedUp ? Colors.teal.shade800 : Colors.orange.shade800)),
                            Text(data['foodItem'] ?? 'Food Rescue', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Text("Feeds ${data['quantity'] ?? '?'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                ),

                // --- DYNAMIC ADDRESS SECTION ---
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isPickedUp ? "DESTINATION: HUB" : "PICKUP FROM DONOR", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                      const SizedBox(height: 8),

                      // The Name
                      Text(
                        isPickedUp ? (data['suggestedNgoName'] ?? 'NGO Hub') : (data['businessName'] ?? 'Local Donor'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),

                      // The Location Button
                      InkWell(
                        onTap: () {
                          if (isPickedUp) {
                            // TODO: In a production app, fetch the NGO's actual coordinates from the Users collection based on data['suggestedNgoId']
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ensure NGO address is stored in this document to open maps.")));
                          } else {
                            _openGoogleMaps(data['latitude'] ?? 0.0, data['longitude'] ?? 0.0);
                          }
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(child: Text(isPickedUp ? "Navigate to Hub (Check Hub Details)" : (data['fullAddress'] ?? 'Address not provided'), style: const TextStyle(fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // The Phone Button
                      if (!isPickedUp) // Usually you call Donor for pickup
                        InkWell(
                          onTap: () => _makePhoneCall(data['donorContact'] ?? ''),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 18, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(data['donorContact'] ?? 'No Number', style: const TextStyle(fontSize: 14, color: Colors.green, decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),

                      if (!isPickedUp) ...[
                        const SizedBox(height: 10),
                        Row(children: [const Icon(Icons.info_outline, size: 16, color: Colors.grey), const SizedBox(width: 6), Text("Instr: ${data['pickupInstruction'] ?? 'Front Desk'}", style: const TextStyle(fontSize: 12, color: Colors.black87, fontStyle: FontStyle.italic))]),
                      ]
                    ],
                  ),
                ),

                // --- DYNAMIC ACTION BUTTON ---
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPickedUp ? Colors.teal.shade700 : Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isPickedUp
                          ? () {
                        // Show a dialog telling them to wait for the NGO
                        showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Row(children: [Icon(Icons.qr_code_scanner, color: Colors.teal), SizedBox(width: 8), Text("Verification")]),
                              content: const Text("You have arrived at the NGO Hub.\n\nTo complete this delivery and get your points, ask the NGO coordinator to open their 'Receiving Tab' and take a photo of the food!"),
                              actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), onPressed: () => Navigator.pop(context), child: const Text("Got it", style: TextStyle(color: Colors.white)))],
                            )
                        );
                      }
                          : () => _markAsPickedUp(context, doc.id),
                      icon: Icon(isPickedUp ? Icons.check_circle_outline : Icons.shopping_bag),
                      label: Text(isPickedUp ? "Waiting for NGO Verification..." : "I have picked up the food", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              ],
            ),
          );
        }
    );
  }
}