import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../../../services/needy_spots_service.dart';

class ActiveDeliveryCard extends StatefulWidget {
  final String volunteerUid;
  const ActiveDeliveryCard({super.key, required this.volunteerUid});

  @override
  State<ActiveDeliveryCard> createState() => _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends State<ActiveDeliveryCard> {
  final TextEditingController _otpController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openGoogleMaps(double lat, double lon) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon";
    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    }
  }

  // --- STEP 1: PICKUP VERIFICATION ---
  Future<void> _verifyOtpAndPickup(String donationId, String correctOtp, String donorUid) async {
    if (_otpController.text.trim() != correctOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN! Ask the donor for the 4-digit code."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);
    
    // 1. Update Donation Status
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Picked Up',
      'pickedUpAt': FieldValue.serverTimestamp(),
    });

    // 2. Award Points to Donor (Immediate Reward)
    await FirebaseFirestore.instance.collection('users').doc(donorUid).update({
      'rankScore': FieldValue.increment(20),
      'donationsMade': FieldValue.increment(1),
    });

    setState(() => _isProcessing = false);
    _otpController.clear();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Pickup Confirmed! Donor rewarded 20 pts."), backgroundColor: Colors.green));
    }
  }

  // --- STEP 2: DROP-OFF COMPLETION ---
  Future<void> _completeWithPhoto(String donationId, String type, String destinationName, String? ngoId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);

    if (photo != null) {
      setState(() => _isProcessing = true);
      List<int> imageBytes = await photo.readAsBytes();
      String base64Proof = base64Encode(imageBytes);

      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Completed',
        'dropoffTime': FieldValue.serverTimestamp(),
        'photoProofUrl': base64Proof,
        'actualDestination': destinationName,
        'destinationType': type,
      });

      // Point Multipliers
      int points = 30; // Default NGO
      if (type == 'Labor Colony') points = 50;
      if (type == 'Orphanage' || type == 'Old Age Home') points = 60; // Highest for vulnerable groups

      await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).update({
        'rankScore': FieldValue.increment(points),
        'deliveriesMade': FieldValue.increment(1),
      });

      if (ngoId != null && type == 'NGO') {
        await FirebaseFirestore.instance.collection('users').doc(ngoId).update({
          'rankScore': FieldValue.increment(10),
          'deliveriesReceived': FieldValue.increment(1),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Amazing! $points points awarded for your help at $destinationName! 🛡️"),
          backgroundColor: Colors.green,
        ));
      }
      setState(() => _isProcessing = false);
    }
  }

  void _showDestinationPicker(BuildContext context, String donationId, double vLat, double vLon, String? ngoId, String? ngoName) {
    List<Map<String, dynamic>> nearbyNeedy = NeedySpotsService.getNearbySpots(vLat, vLon);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Choose Delivery Target", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Orphanages & Old Age Homes give the most points! ✨", style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 20),
              
              Expanded(
                child: ListView(
                  children: [
                    const Text("NEARBY DISTRIBUTION SPOTS", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...nearbyNeedy.map((spot) {
                      IconData icon = Icons.engineering;
                      Color color = Colors.orange;
                      if (spot['type'] == 'Orphanage') { icon = Icons.child_care; color = Colors.pink; }
                      if (spot['type'] == 'Old Age Home') { icon = Icons.elderly; color = Colors.blue; }

                      return ListTile(
                        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                        title: Text(spot['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${spot['distKm'].toStringAsFixed(1)} km • ${spot['type']}"),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _completeWithPhoto(donationId, spot['type'], spot['name'], null);
                          },
                          child: const Text("Deliver"),
                        ),
                      );
                    }).toList(),
                    
                    const Divider(height: 40),
                    
                    if (ngoId != null) ...[
                      const Text("NGO HUB", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.bold)),
                      ListTile(
                        leading: const CircleAvatar(backgroundColor: Colors.tealOpacity, child: Icon(Icons.corporate_fare, color: Colors.teal)),
                        title: Text(ngoName ?? "Assigned Hub"),
                        subtitle: const Text("30 Points Reward"),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          onPressed: () {
                            Navigator.pop(context);
                            _completeWithPhoto(donationId, 'NGO', ngoName ?? 'NGO Hub', ngoId);
                          },
                          child: const Text("Deliver"),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donations')
            .where('volunteerUid', isEqualTo: widget.volunteerUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();

          List<DocumentSnapshot> active = snapshot.data?.docs.where((doc) {
            String status = doc['status'] ?? '';
            return ['Accepted', 'Picked Up', 'En Route'].contains(status);
          }).toList() ?? [];

          if (active.isEmpty) return const SizedBox.shrink();

          var data = active.first.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';
          bool isPickedUp = status == 'Picked Up';
          String donationId = active.first.id;

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              border: Border.all(color: isPickedUp ? Colors.blue.shade100 : Colors.orange.shade100),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isPickedUp ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Icon(isPickedUp ? Icons.local_shipping : Icons.shopping_bag, color: isPickedUp ? Colors.blue : Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isPickedUp ? "Deliver to Needy" : "Pickup from Donor",
                          style: TextStyle(fontWeight: FontWeight.w900, color: isPickedUp ? Colors.blue.shade900 : Colors.orange.shade900, fontSize: 12),
                        ),
                      ),
                      if (_isProcessing) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['foodItem'] ?? 'Food Rescue', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      if (!isPickedUp) ...[
                        Text("From: ${data['businessName'] ?? 'Donor'}", style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                        const SizedBox(height: 15),
                        const Text("Enter PIN from Donor:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: "4-Digit PIN",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true, fillColor: Colors.grey.shade50,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _verifyOtpAndPickup(donationId, data['pickupOtp'] ?? '', data['donorUid'] ?? ''),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text("VERIFY"),
                            )
                          ],
                        ),
                      ] else ...[
                        const Text("FOOD READY FOR DROP-OFF! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.navigation),
                            label: const Text("SELECT DESTINATION"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: () => _showDestinationPicker(
                              context, 
                              donationId, 
                              (data['latitude'] ?? 0.0).toDouble(), 
                              (data['longitude'] ?? 0.0).toDouble(),
                              data['suggestedNgoId'],
                              data['suggestedNgoName']
                            ),
                          ),
                        )
                      ],
                    ],
                  ),
                )
              ],
            ),
          );
        }
    );
  }
}
