import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/needy_spots_service.dart';
import '../gamification/squads_hub_screen.dart';

class NgoHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  const NgoHomeTab({super.key, required this.userData, required this.uid});
  @override State<NgoHomeTab> createState() => _NgoHomeTabState();
}

class _NgoHomeTabState extends State<NgoHomeTab> {
  bool isProcessing = false;

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
                      widget.userData['distributorName'] ?? widget.userData['organizationName'] ?? 'Hub Dashboard', 
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
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Incoming Food Requests", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
              
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('donations')
                    .where('selectedNgoId', isEqualTo: widget.uid)
                    .where('status', whereIn: ['NGO Requested', 'En Route'])
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No active requests.", style: TextStyle(color: Colors.grey))));

                  return Column(
                    children: snapshot.data!.docs.map((post) {
                      Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
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
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isRequested ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(6)), child: Text(isRequested ? "PENDING REQUEST" : "EN ROUTE", style: TextStyle(color: isRequested ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold))),
                                Text(postData['category'] ?? 'Food', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ]),
                              const SizedBox(height: 15),
                              Text("📦 ${postData['foodItem']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text("Quantity: ${postData['quantity']} meals", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                              const Divider(height: 30),
                              Row(children: [
                                const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 18)),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(postData['volunteerName'] ?? 'Volunteer', style: const TextStyle(fontWeight: FontWeight.bold)), Text(distStr, style: const TextStyle(fontSize: 11, color: Colors.blueGrey))])),
                              ]),
                              const SizedBox(height: 20),
                              if (isRequested) SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: isProcessing ? null : () => _acceptIncomingRescue(post.id), child: const Text("RECEIVE THIS FOOD", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))))
                              else const Center(child: Text("Volunteer is arriving... Ask for photo on delivery!", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Supply to People in Need (Nearby)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),
              const Text("Identify these spots to distribute your surplus food stocks.", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 15),

              ...NeedySpotsService.getNearbySpots(ngoLat, ngoLon).map((spot) {
                IconData icon = Icons.engineering;
                Color color = Colors.orange;
                if (spot['type'] == 'Orphanage') { icon = Icons.child_care; color = Colors.pink; }
                if (spot['type'] == 'Old Age Home') { icon = Icons.elderly; color = Colors.blue; }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                  title: Text(spot['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("${spot['distKm'].toStringAsFixed(1)} km away • ${spot['type']}"),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=${spot['lat']},${spot['lon']}";
                    launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                  },
                );
              }).toList(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }
}
