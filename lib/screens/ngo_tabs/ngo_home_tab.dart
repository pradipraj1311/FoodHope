import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart'; // IMPORT GEOLOCATOR

class NgoHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const NgoHomeTab({super.key, required this.userData, required this.uid});

  @override
  State<NgoHomeTab> createState() => _NgoHomeTabState();
}

class _NgoHomeTabState extends State<NgoHomeTab> {
  bool isUploading = false;

  // THE CAMERA VERIFICATION PROTOCOL
  Future<void> _verifyWithCamera(BuildContext context, String donationId) async {
    try {
      final picker = ImagePicker();
      // Forces the use of the Camera to prevent uploading fake internet photos!
      final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);

      if (pickedFile != null) {
        setState(() => isUploading = true);
        File imageFile = File(pickedFile.path);

        final storageRef = FirebaseStorage.instance.ref().child('delivery_proofs').child('$donationId.jpg');
        await storageRef.putFile(imageFile);
        String proofUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
          'status': 'Completed',
          'dropoffTime': DateTime.now(),
          'proofImageUrl': proofUrl, // Secure Proof Saved
        });

        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
          'totalDeliveriesReceived': FieldValue.increment(1)
        });

        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Verified! Delivery Complete.")));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Camera Failed (Ensure permissions are granted): $e")));
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double ngoLat = widget.userData['latitude'] ?? 0.0;
    double ngoLon = widget.userData['longitude'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.teal.shade800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Receiving Hub", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 5),
              Text(widget.userData['distributorName'] ?? widget.userData['ngoName'] ?? 'NGO Dashboard', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const Padding(padding: EdgeInsets.all(16.0), child: Text("Incoming Food Rescues", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
        if (isUploading) const LinearProgressIndicator(color: Colors.teal), // Loading bar for image upload

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').where('selectedNgoId', isEqualTo: widget.uid).where('status', isEqualTo: 'Picked Up').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar, size: 60, color: Colors.grey.shade300), const SizedBox(height: 15),
                      const Text("No volunteers are currently en route to your location.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index]; Map<String, dynamic> postData = post.data() as Map<String, dynamic>;

                  // CALCULATE VOLUNTEER DISTANCE
                  double vLat = postData['volunteerLatitude'] ?? 0.0;
                  double vLon = postData['volunteerLongitude'] ?? 0.0;
                  String distStr = "Calcluating...";
                  if (ngoLat != 0.0 && vLat != 0.0) {
                    double distKm = Geolocator.distanceBetween(ngoLat, ngoLon, vLat, vLon) / 1000;
                    distStr = "${distKm.toStringAsFixed(1)} km away";
                  }

                  return Card(
                    elevation: 3, shadowColor: Colors.teal.withOpacity(0.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.teal.shade100)), margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(children: [Icon(Icons.directions_car, color: Colors.blue, size: 20), SizedBox(width: 8), Text("On The Way", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14))]),
                              Text(distStr, style: TextStyle(color: Colors.grey.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const Divider(height: 20),

                          Text("📦 ${postData['foodItem']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Feeds approx ${postData['quantity']} people", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),

                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Volunteer Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)), const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.person, size: 16, color: Colors.teal), const SizedBox(width: 8), Text(postData['volunteerName'] ?? 'Unknown')]), const SizedBox(height: 4),

                                // FIX: SHOW THE PHONE NUMBER
                                Row(children: [const Icon(Icons.phone, size: 16, color: Colors.teal), const SizedBox(width: 8), Text(postData['volunteerContact'] ?? 'Phone hidden')]),
                              ],
                            ),
                          ),

                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity, height: 50, // Made slightly bigger for text
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: isUploading ? null : () => _verifyWithCamera(context, post.id),
                              icon: const Icon(Icons.camera_alt),

                              // UPDATED TEXT
                              label: const Text(
                                  "Open camera to receive food and tell\nto click one photo of food",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, height: 1.2)
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}