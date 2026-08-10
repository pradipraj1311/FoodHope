import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/rank_motivational_banner.dart';
import '../../widgets/countdown_timer_widget.dart';
import 'widgets/post_food_sheet.dart';

class DonorHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  const DonorHomeTab({super.key, required this.userData, required this.uid});

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RankMotivationalBanner(uid: widget.uid, city: widget.userData['city'] ?? 'Unknown', role: 'Donor'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
          child: SizedBox(
            width: double.infinity, height: 60, 
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600, 
                foregroundColor: Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ), 
              onPressed: () => showModalBottomSheet(
                context: context, 
                isScrollControlled: true, 
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), 
                builder: (context) => PostFoodSheet(userData: widget.userData, uid: widget.uid)
              ), 
              icon: const Icon(Icons.add_circle, size: 28), 
              label: const Text("Post Food Rescue", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            )
          )
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("Active Donations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('donorUid', isEqualTo: widget.uid)
                .where('status', whereIn: ['Available', 'Accepted', 'Picked Up', 'NGO Requested', 'En Route'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("You have no active food postings.", style: TextStyle(color: Colors.grey)));

              // Real-time Expiry Re-evaluation
              var activeDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                
                if (data['exactExpiryTime'] != null) {
                  DateTime expiry = (data['exactExpiryTime'] as Timestamp).toDate();
                  // If food is expired, we hide it from the active list
                  if (expiry.isBefore(DateTime.now())) {
                    // Update DB in background if it's still available
                    if (data['status'] == 'Available') {
                      FirebaseFirestore.instance.collection('donations').doc(doc.id).update({'status': 'Expired'});
                    }
                    return false;
                  }
                }
                return true;
              }).toList();

              if (activeDocs.isEmpty) return const Center(child: Text("No active food postings.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                itemCount: activeDocs.length,
                itemBuilder: (context, index) {
                  var post = activeDocs[index]; 
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
                  String currentStatus = postData['status']; 
                  
                  bool isAccepted = currentStatus == 'Accepted';
                  bool isInTransit = ['Picked Up', 'NGO Requested', 'En Route'].contains(currentStatus);

                  return Card(
                    elevation: 2, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Expanded(child: Text(postData['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), 
                                decoration: BoxDecoration(
                                  color: isInTransit ? Colors.purple.shade100 : (isAccepted ? Colors.blue.shade100 : Colors.green.shade100), 
                                  borderRadius: BorderRadius.circular(10)
                                ), 
                                child: Text(
                                  currentStatus == 'NGO Requested' ? 'Waiting for Hub' : currentStatus, 
                                  style: TextStyle(color: isInTransit ? Colors.purple.shade800 : (isAccepted ? Colors.blue.shade800 : Colors.green.shade800), fontWeight: FontWeight.bold)
                                )
                              )
                            ]
                          ),
                          const SizedBox(height: 10), 
                          Row(children: [const Icon(Icons.people, size: 16, color: Colors.orange), const SizedBox(width: 8), Text("Feeds ${postData['quantity']}")]),
                          const SizedBox(height: 8), 
                          CountdownTimerWidget(expiryTimestamp: postData['exactExpiryTime'] as Timestamp?),
                          
                          // PIN Section: Show only when Volunteer has Accepted
                          if (currentStatus == 'Accepted') ...[
                            const Divider(height: 20), 
                            Container(
                              width: double.infinity, 
                              padding: const EdgeInsets.all(12), 
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)), 
                              child: Column(
                                children: [
                                  const Text("Give this PIN to the Volunteer:", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)), 
                                  Text(
                                    postData['pickupOtp'] ?? '----',
                                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.red.shade900)
                                  )
                                ]
                              )
                            ), 
                            const SizedBox(height: 8)
                          ],
                          
                          if (currentStatus == 'Available') ...[
                            const SizedBox(height: 15), 
                            SizedBox(
                              width: double.infinity, 
                              child: OutlinedButton(
                                onPressed: () async { await FirebaseFirestore.instance.collection('donations').doc(post.id).update({'status': 'Cancelled'}); }, 
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.red), 
                                child: const Text("Cancel Donation")
                              )
                            )
                          ]
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
