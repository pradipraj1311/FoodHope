import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Senior Dev Refresh: Auto-refresh UI every minute to handle expiry logic
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String city = widget.userData['city'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RankMotivationalBanner(uid: widget.uid, city: city, role: 'Donor'),
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
              label: const Text("Post Food Rescue", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            )
          )
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text("NGO HUB DEMANDS 📢", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('needs')
              .where('city', isEqualTo: city)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("No urgent demands from Hubs.", style: TextStyle(color: Colors.grey, fontSize: 11)),
              );
            }
            return SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: snapshot.data!.docs.map((doc) {
                  var need = doc.data() as Map<String, dynamic>;
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(16), 
                      border: Border.all(color: Colors.teal.shade100)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(need['ngoName'] ?? 'Hub', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal), overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text("${need['mealsNeeded']} Meals Needed", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),

        const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), child: Text("Active Donations", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54))),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('donorUid', isEqualTo: widget.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.orange));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No active postings.", style: TextStyle(color: Colors.grey)));

              // SENIOR DEV FIX: Real-time Expiry Filter
              var activeDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String status = data['status'] ?? '';
                bool isActive = ['Available', 'Accepted', 'Picked Up', 'NGO Requested', 'En Route'].contains(status);
                
                if (isActive && data['exactExpiryTime'] != null) {
                  DateTime expiry = (data['exactExpiryTime'] as Timestamp).toDate();
                  if (expiry.isBefore(DateTime.now())) return false; // Auto-hide expired
                }
                return isActive;
              }).toList();

              if (activeDocs.isEmpty) return const Center(child: Text("No active food postings.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                itemCount: activeDocs.length,
                itemBuilder: (context, index) {
                  var post = activeDocs[index]; 
                  Map<String, dynamic> data = post.data() as Map<String, dynamic>;
                  String status = data['status'] ?? 'Available'; 

                  return Card(
                    elevation: 3, 
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade100)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              Text(data['foodItem'] ?? 'Food Item', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                                child: Text(status, style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold))
                              )
                            ]
                          ),
                          const SizedBox(height: 10),
                          CountdownTimerWidget(expiryTimestamp: data['exactExpiryTime'] as Timestamp?),
                          
                          // FIXED: Pickup PIN display for Donor when Volunteer accepts
                          if (status == 'Accepted') ...[
                            const Divider(height: 30),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
                              child: Column(
                                children: [
                                  const Text("VOLUNTEER ON THE WAY - GIVE THIS PIN:", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                                  const SizedBox(height: 4),
                                  Text(data['pickupOtp'] ?? '----', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 10, color: Colors.red)),
                                ],
                              ),
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
