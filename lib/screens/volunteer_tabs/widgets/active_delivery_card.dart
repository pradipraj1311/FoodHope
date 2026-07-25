import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';

class ActiveDeliveryCard extends StatefulWidget {
  final String volunteerUid;
  const ActiveDeliveryCard({super.key, required this.volunteerUid});

  @override
  State<ActiveDeliveryCard> createState() => _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends State<ActiveDeliveryCard> {
  final TextEditingController _otpController = TextEditingController();
  bool _isProcessing = false;

  // Mock Labor Colonies (RERA Verified Simulator)
  final List<Map<String, dynamic>> _mockLaborColonies = [
    {'name': 'Metro Construction Site A', 'lat': 22.705, 'lon': 72.870, 'workers': 150},
    {'name': 'Shanti Nagar Labor Colony', 'lat': 22.695, 'lon': 72.858, 'workers': 220},
    {'name': 'Piplag Dev Camp', 'lat': 22.685, 'lon': 72.845, 'workers': 90},
  ];

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
    
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Picked Up',
      'pickedUpAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('users').doc(donorUid).update({
      'rankScore': FieldValue.increment(20),
      'donationsMade': FieldValue.increment(1),
    });

    setState(() => _isProcessing = false);
    _otpController.clear();
  }

  // --- STEP 2A: REQUEST NGO DROP-OFF ---
  Future<void> _requestNgoDropoff(String donationId, String ngoId, String ngoName) async {
    setState(() => _isProcessing = true);
    
    // Fetch volunteer info to send to NGO
    DocumentSnapshot vDoc = await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).get();
    Map<String, dynamic> vData = vDoc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'NGO Requested',
      'selectedNgoId': ngoId,
      'selectedNgoName': ngoName,
      'volunteerName': vData['name'] ?? 'Hero',
      'volunteerContact': vData['contact'] ?? '',
      'volunteerLatitude': vData['latitude'] ?? 0.0,
      'volunteerLongitude': vData['longitude'] ?? 0.0,
    });

    setState(() => _isProcessing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent to NGO Hub! Waiting for them to accept."), backgroundColor: Colors.blue));
    }
  }

  // --- STEP 2B: COMPLETE LABOR DROP-OFF ---
  Future<void> _completeWithPhoto(String donationId, bool isLaborColony, String? destinationName) async {
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
        'actualDestination': destinationName ?? 'Community Dropoff',
        'deliveredToLabor': isLaborColony,
      });

      await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).update({
        'rankScore': FieldValue.increment(isLaborColony ? 50 : 30),
        'deliveriesMade': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isLaborColony ? "Hero! 50 points awarded for helping labor camp! 🛡️" : "Hub Delivery Complete! 30 points awarded."),
          backgroundColor: Colors.green,
        ));
      }
      setState(() => _isProcessing = false);
    }
  }

  void _showDestinationPicker(BuildContext context, String donationId, double vLat, double vLon, String? suggestedNgoId, String? suggestedNgoName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Target Destination", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Directly feeding labor camps gives 50 PTS! 🛡️", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 20),
              
              const Text("NEARBY LABOR COLONIES", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              ..._mockLaborColonies.map((lc) {
                double dist = Geolocator.distanceBetween(vLat, vLon, lc['lat'], lc['lon']) / 1000;
                return ListTile(
                  leading: const Icon(Icons.engineering, color: Colors.orange),
                  title: Text(lc['name']),
                  subtitle: Text("${dist.toStringAsFixed(1)} km away"),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    onPressed: () {
                      Navigator.pop(context);
                      _completeWithPhoto(donationId, true, lc['name']);
                    },
                    child: const Text("Deliver"),
                  ),
                );
              }).toList(),
              
              const Divider(height: 30),
              
              ListTile(
                leading: const Icon(Icons.corporate_fare, color: Colors.teal),
                title: Text(suggestedNgoName ?? "Impact NGO Hub"),
                subtitle: const Text("Requires NGO interaction"),
                trailing: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (suggestedNgoId != null) {
                      _requestNgoDropoff(donationId, suggestedNgoId, suggestedNgoName!);
                    }
                  },
                  child: const Text("Request"),
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
            return ['Accepted', 'Picked Up', 'NGO Requested', 'En Route'].contains(status);
          }).toList() ?? [];

          if (active.isEmpty) return const SizedBox.shrink();

          var data = active.first.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';
          String donationId = active.first.id;

          bool isPickedUp = status == 'Picked Up';
          bool isRequested = status == 'NGO Requested';
          bool isEnRoute = status == 'En Route';

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              border: Border.all(color: (isRequested || isEnRoute) ? Colors.blue.shade100 : Colors.orange.shade100),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isRequested || isEnRoute) ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Icon(isEnRoute ? Icons.local_shipping : (isRequested ? Icons.hourglass_top : Icons.shopping_bag), color: (isRequested || isEnRoute) ? Colors.blue : Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEnRoute ? "STEP 3: DROP-OFF AT HUB" : (isRequested ? "WAITING FOR NGO HUB..." : (isPickedUp ? "CHOOSE DESTINATION" : "STEP 1: COLLECT FOOD")),
                          style: TextStyle(fontWeight: FontWeight.w900, color: (isRequested || isEnRoute) ? Colors.blue.shade900 : Colors.orange.shade900, fontSize: 12),
                        ),
                      ),
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
                      
                      if (status == 'Accepted') ...[
                        const Text("Give donor your name then enter their PIN:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(hintText: "Enter PIN", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _verifyOtpAndPickup(donationId, data['pickupOtp'] ?? '', data['donorUid'] ?? ''),
                              child: const Text("VERIFY"),
                            )
                          ],
                        ),
                      ] else if (isPickedUp) ...[
                        const Text("FOOD PICKED UP! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share_location),
                            label: const Text("CHOOSE DROP-OFF TARGET"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.all(16)),
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
                      ] else if (isRequested) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 10),
                              Expanded(child: Text("Hub: ${data['selectedNgoName']}\nhas been notified. Please wait.", style: const TextStyle(fontSize: 12, color: Colors.blue))),
                            ],
                          ),
                        ),
                      ] else if (isEnRoute) ...[
                        const Text("NGO ACCEPTED! 🚀", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text("Head to ${data['selectedNgoName']}", style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("I HAVE ARRIVED - TAKE PHOTO"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.all(16)),
                            onPressed: () => _completeWithPhoto(donationId, false, data['selectedNgoName']),
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
