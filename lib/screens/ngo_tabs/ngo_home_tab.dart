import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../gamification/squads_hub_screen.dart';

class NgoHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  const NgoHomeTab({super.key, required this.userData, required this.uid});
  @override State<NgoHomeTab> createState() => _NgoHomeTabState();
}

class _NgoHomeTabState extends State<NgoHomeTab> {
  bool isProcessing = false;

  // NGO accepts the volunteer's request
  Future<void> _acceptIncomingRescue(String donationId) async {
    setState(() => isProcessing = true);
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'En Route',
    });
    setState(() => isProcessing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rescue Accepted! Volunteer notified."), backgroundColor: Colors.teal));
    }
  }

  @override
  Widget build(BuildContext context) {
    double ngoLat = (widget.userData['latitude'] ?? 0.0).toDouble();
    double ngoLon = (widget.userData['longitude'] ?? 0.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity, 
          padding: const EdgeInsets.all(20), 
          decoration: BoxDecoration(color: Colors.teal.shade800), 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    const Text("Receiving Hub", style: TextStyle(color: Colors.white70, fontSize: 16)), 
                    const SizedBox(height: 5), 
                    Text(
                      widget.userData['distributorName'] ?? widget.userData['ngoName'] ?? 'Hub Dashboard', 
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    )
                  ]
                ),
              ),
              IconButton(
                icon: const Icon(Icons.groups, color: Colors.greenAccent, size: 30),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SquadsHubScreen(userData: widget.userData, uid: widget.uid))
                  );
                },
              ),
            ],
          )
        ),
        const Padding(padding: EdgeInsets.all(16.0), child: Text("Incoming Food Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
        
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('selectedNgoId', isEqualTo: widget.uid)
                .where('status', whereIn: ['NGO Requested', 'En Route'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.radar, size: 60, color: Colors.grey.shade300), const SizedBox(height: 15), const Text("No active requests.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))]));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index]; Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
                  String status = postData['status'] ?? '';
                  bool isRequested = status == 'NGO Requested';
                  
                  double vLat = (postData['volunteerLatitude'] ?? 0.0).toDouble(); 
                  double vLon = (postData['volunteerLongitude'] ?? 0.0).toDouble();
                  String distStr = "Calculating...";
                  if (ngoLat != 0.0 && vLat != 0.0) { distStr = "${(Geolocator.distanceBetween(ngoLat, ngoLon, vLat, vLon) / 1000).toStringAsFixed(1)} km away"; }

                  return Card(
                    elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: isRequested ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Text(isRequested ? "PENDING REQUEST" : "EN ROUTE", style: TextStyle(color: isRequested ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                              Text(postData['category'] ?? 'Food', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text("📦 ${postData['foodItem']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Quantity: ${postData['quantity']} meals", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                          const Divider(height: 30),
                          Row(
                            children: [
                              const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 18)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(postData['volunteerName'] ?? 'Volunteer', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(distStr, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (isRequested)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: isProcessing ? null : () => _acceptIncomingRescue(post.id),
                                child: const Text("RECEIVE THIS FOOD", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            )
                          else
                            const Center(child: Text("Volunteer is arriving... Ask for photo on delivery!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
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
