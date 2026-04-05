import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../widgets/countdown_timer_widget.dart';

class AvailableDonationCard extends StatelessWidget {
  final Map<String, dynamic> donation;
  final String donationId;
  final double vLat;
  final double vLon;
  final String volunteerUid;

  const AvailableDonationCard({super.key, required this.donation, required this.donationId, required this.vLat, required this.vLon, required this.volunteerUid});

  // --- WAVE 1: STRICT ACCEPTANCE POLICY ---
  Future<void> _acceptDonation(BuildContext context) async {
    // 1. Show a loading spinner so they don't double-click
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)));

    // 2. FETCH VOLUNTEER'S FRESH USER DATA
    DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance.collection('users').doc(volunteerUid).get();
    if (!volunteerDoc.exists) {
      if (context.mounted) Navigator.pop(context);
      return;
    }
    Map<String, dynamic> vData = volunteerDoc.data() as Map<String, dynamic>;

    // 3. MANDATORY PROFILE PHOTO ENFORCEMENT
    String vPhoto = vData['profileImageUrl'] ?? '';

    if (vPhoto.isEmpty) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading spinner
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            // FIXED THE CONST ERROR HERE:
            title: Row(children: [const Icon(Icons.photo_camera, color: Colors.orange), const SizedBox(width: 8), Text("Photo Required", style: TextStyle(color: Colors.orange.shade800))]),
            content: const Text("Fraudsters hate friction. To prevent fake deliveries, you must have a profile photo uploaded to your account before you can accept food rescues.\n\nPlease visit your Profile Tab to take a photo."),
            actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), onPressed: () => Navigator.pop(context), child: const Text("Understood", style: TextStyle(color: Colors.white)))],
          ),
        );
      }
      return; // Stop the acceptance flow here!
    }

    // 4. Security Check: Does this volunteer already have an active delivery?
    QuerySnapshot activeCheck = await FirebaseFirestore.instance.collection('donations')
        .where('volunteerUid', isEqualTo: volunteerUid)
        .where('status', whereIn: ['Accepted', 'Picked Up', 'En Route'])
        .get();

    if (activeCheck.docs.isNotEmpty) {
      if (context.mounted) {
        Navigator.pop(context); // Remove loading spinner
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("⚠️ You already have an active rescue! Please complete or cancel it before accepting another."),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    // 5. If safe, photo exists, and no active rescues, accept the donation
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Accepted', 'volunteerUid': volunteerUid, 'acceptedAt': FieldValue.serverTimestamp()
    });

    if (context.mounted) Navigator.pop(context);
  }

  // --- URL LAUNCHER METHODS ---
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openGoogleMaps(double lat, double lon) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon";
    final Uri launchUri = Uri.parse(googleMapsUrl);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Could not launch maps: $e");
    }
  }

  // --- FETCH ALL NEARBY NGOS ---
  Future<List<Map<String, dynamic>>> _fetchAllNearbyNGOs(double dLat, double dLon, String foodCategory) async {
    QuerySnapshot ngoSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'NGO').get();
    List<Map<String, dynamic>> nearbyNgos = [];

    for (var doc in ngoSnapshot.docs) {
      Map<String, dynamic> ngo = doc.data() as Map<String, dynamic>;

      if ((ngo['foodPreference'] ?? 'Any') == 'Veg Only' && (foodCategory == 'Non-Veg' || foodCategory == 'Both (Mixed)')) continue;

      double nLat = ngo['latitude'] ?? 0.0;
      double nLon = ngo['longitude'] ?? 0.0;
      double distKm = Geolocator.distanceBetween(dLat, dLon, nLat, nLon) / 1000;

      if (distKm <= 20.0) {
        nearbyNgos.add({
          'name': ngo['distributorName'] ?? ngo['ngoName'] ?? 'NGO Hub',
          'distKm': distKm,
          'type': ngo['distributorType'] ?? 'Hub'
        });
      }
    }
    nearbyNgos.sort((a, b) => (a['distKm'] as double).compareTo(b['distKm'] as double));
    return nearbyNgos;
  }

  @override
  Widget build(BuildContext context) {
    double dLat = donation['latitude'] ?? 0.0;
    double dLon = donation['longitude'] ?? 0.0;
    double distKm = Geolocator.distanceBetween(vLat, vLon, dLat, dLon) / 1000;

    int etaMinutes = (distKm * 2).ceil();
    DateTime expiryTime = (donation['exactExpiryTime'] as Timestamp).toDate();
    int minsToExpiry = expiryTime.difference(DateTime.now()).inMinutes;

    bool isRisky = (etaMinutes + 15) > minsToExpiry;
    List<dynamic> tags = donation['specialTags'] ?? [];

    return Card(
      elevation: 4, margin: const EdgeInsets.only(bottom: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP BANNER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: isRisky ? Colors.red.shade50 : Colors.green.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [Icon(Icons.directions_bike, size: 16, color: isRisky ? Colors.red : Colors.green), const SizedBox(width: 6), Text("ETA: $etaMinutes min (${distKm.toStringAsFixed(1)} km)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isRisky ? Colors.red.shade800 : Colors.green.shade800))]),
                Row(children: [Icon(isRisky ? Icons.warning_amber : Icons.verified, size: 16, color: isRisky ? Colors.red : Colors.green), const SizedBox(width: 4), Text(isRisky ? "Risky (Low Time)" : "Safe to Deliver", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isRisky ? Colors.red.shade800 : Colors.green.shade800))]),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. FOOD INFO
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 60, width: 60, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Icon(donation['hasPhoto'] == true ? Icons.fastfood : Icons.image_not_supported, color: Colors.grey.shade400)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(donation['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(children: [const Icon(Icons.people, size: 14, color: Colors.orange), const SizedBox(width: 4), Text("Feeds ${donation['quantity']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(width: 10), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: Text(donation['category'] ?? 'Veg', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)))]),
                        ],
                      ),
                    ),
                  ],
                ),

                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 6, children: tags.map((tag) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.shade200)), child: Text(tag, style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold)))).toList()),
                ],

                const SizedBox(height: 12), CountdownTimerWidget(expiryTimestamp: donation['exactExpiryTime'] as Timestamp?),
                const Divider(height: 24),

                // 3. LOGISTICS INFO
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PICKUP DETAILS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      InkWell(
                          onTap: () => _openGoogleMaps(dLat, dLon),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.location_on, size: 18, color: Colors.blue.shade700), const SizedBox(width: 8), Expanded(child: Text(donation['fullAddress'] ?? 'Address not provided', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)))])
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                          onTap: () => _makePhoneCall(donation['donorContact'] ?? ''),
                          child: Row(children: [Icon(Icons.phone, size: 18, color: Colors.green.shade700), const SizedBox(width: 8), Text(donation['donorContact'] ?? 'No Number', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green, decoration: TextDecoration.underline))])
                      ),
                      const SizedBox(height: 10),
                      Row(children: [Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700), const SizedBox(width: 8), Text("Instructions: ${donation['pickupInstruction'] ?? 'Front Desk'}", style: const TextStyle(fontSize: 12, color: Colors.black87))]),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 4. DROPOFF OPTIONS
                Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("POSSIBLE DROPOFF HUBS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchAllNearbyNGOs(dLat, dLon, donation['category'] ?? 'Veg Only'),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 30, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const Row(children: [Icon(Icons.warning, size: 16, color: Colors.red), SizedBox(width: 6), Text("No nearby hubs. Direct distribution required.", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red))]);
                            }

                            List<Map<String, dynamic>> ngos = snapshot.data!;

                            return Column(
                              children: ngos.take(3).map((ngo) => Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  children: [
                                    Icon(Icons.corporate_fare, size: 16, color: Colors.teal.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(ngo['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                    Text("${ngo['distKm'].toStringAsFixed(1)} km", style: TextStyle(fontSize: 12, color: Colors.teal.shade800, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )).toList(),
                            );
                          }
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 5. ACTION BUTTON
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isRisky ? Colors.orange.shade700 : Colors.green.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                        onPressed: () => _acceptDonation(context),
                        child: Text(isRisky ? "Accept Risky Rescue" : "Accept Rescue", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                    )
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}