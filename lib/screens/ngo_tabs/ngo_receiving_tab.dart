import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';

class NgoReceivingTab extends StatelessWidget {
  final String uid;
  const NgoReceivingTab({super.key, required this.uid});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _confirmWithPhoto(BuildContext context, String donationId, String volunteerUid, String donorUid) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 25
    );

    if (photo != null) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.teal)));

      List<int> imageBytes = await photo.readAsBytes();
      String base64ReceiptString = base64Encode(imageBytes);

      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Completed',
        'dropoffTime': DateTime.now(),
        'photoProofUrl': base64ReceiptString,
        'photoUrl': FieldValue.delete(),
      });

      // NGO Points
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'rankScore': FieldValue.increment(10),
        'deliveriesReceived': FieldValue.increment(1),
      });

      // Volunteer Points
      if (volunteerUid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(volunteerUid).update({
          'rankScore': FieldValue.increment(20),
          'deliveriesMade': FieldValue.increment(1),
        });
      }

      // Donor Points & Counter
      if (donorUid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(donorUid).update({
          'rankScore': FieldValue.increment(15),
          'donationsMade': FieldValue.increment(1), // FIXED: Now tracking donor impact count
        });
      }

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 Receipt Confirmed! Points awarded.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20), width: double.infinity, color: Colors.teal.shade800,
            child: const Row(children: [Icon(Icons.corporate_fare, color: Colors.white), SizedBox(width: 10), Text("Receiving Hub Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
          ),
          const Padding(padding: EdgeInsets.all(16.0), child: Text("Incoming Food Rescues", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('donations')
                  .where('suggestedNgoId', isEqualTo: uid)
                  .where('status', isEqualTo: 'En Route')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), Text("No incoming deliveries.", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 16))]));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    String vUid = data['volunteerUid'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)), child: Row(children: [Icon(Icons.motorcycle, size: 14, color: Colors.teal.shade700), const SizedBox(width: 4), Text("Volunteer is arriving", style: TextStyle(color: Colors.teal.shade800, fontSize: 10, fontWeight: FontWeight.bold))])), Text(data['category'] ?? 'Veg Only', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
                          const SizedBox(height: 15),
                          Text("📦 ${data['foodItem']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Feeds approx ${data['quantity']} people", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 15),

                          if (vUid.isNotEmpty)
                            FutureBuilder<List<DocumentSnapshot>>(
                                future: Future.wait([
                                  FirebaseFirestore.instance.collection('users').doc(vUid).get(),
                                  FirebaseFirestore.instance.collection('users').doc(uid).get(),
                                ]),
                                builder: (context, volSnapshot) {
                                  if (volSnapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(color: Colors.teal);
                                  if (!volSnapshot.hasData || !volSnapshot.data![0].exists) return const Text("Volunteer disconnected");

                                  var vData = volSnapshot.data![0].data() as Map<String, dynamic>;
                                  var nData = volSnapshot.data![1].data() as Map<String, dynamic>;

                                  double dist = Geolocator.distanceBetween(vData['latitude'] ?? 0, vData['longitude'] ?? 0, nData['latitude'] ?? 0, nData['longitude'] ?? 0) / 1000;
                                  
                                  return Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: Colors.teal),
                                      const SizedBox(width: 8),
                                      Text(vData['name'] ?? 'Hero', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const Spacer(),
                                      Text("${dist.toStringAsFixed(1)} km", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                                    ],
                                  );
                                }
                            ),

                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity, height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmWithPhoto(context, doc.id, vUid, data['donorUid'] ?? ''),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Confirm Receipt', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
