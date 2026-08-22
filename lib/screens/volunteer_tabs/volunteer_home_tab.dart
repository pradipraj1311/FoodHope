import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

import 'widgets/active_delivery_card.dart';
import 'widgets/available_donation_card.dart';
import '../gamification/city_leaderboard_screen.dart';
import '../gamification/squads_hub_screen.dart';
import '../../widgets/rank_motivational_banner.dart';

class VolunteerHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const VolunteerHomeTab({super.key, required this.userData, required this.uid});

  @override
  State<VolunteerHomeTab> createState() => _VolunteerHomeTabState();
}

class _VolunteerHomeTabState extends State<VolunteerHomeTab> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
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
    double vLat = (widget.userData['latitude'] ?? 0.0).toDouble();
    double vLon = (widget.userData['longitude'] ?? 0.0).toDouble();
    String vehicleType = widget.userData['vehicleType'] ?? 'Scooter / Motorcycle';
    String city = widget.userData['city'] ?? 'Your City';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: RankMotivationalBanner(uid: widget.uid, city: city, role: 'Volunteer'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "Hello, ${widget.userData['name']?.split(' ')[0] ?? 'Hero'}!",
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)
                            ),
                            Text("Volunteer in $city", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shield, color: Colors.blueAccent, size: 28),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadsHubScreen(userData: widget.userData, uid: widget.uid))),
                            ),
                            IconButton(
                              icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityLeaderboardScreen(currentUserUid: widget.uid, userCity: city, userRole: 'Volunteer'))),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 25),
                    ActiveDeliveryCard(volunteerUid: widget.uid),
                    
                    // NGO NEEDS SECTION (SENIOR DEV FEATURE)
                    const SizedBox(height: 25),
                    const Text("NGO HUB DEMANDS 📢", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('needs')
                          .where('city', isEqualTo: city)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text("No urgent demands from Hubs.", style: TextStyle(color: Colors.grey, fontSize: 12));
                        return SizedBox(
                          height: 110,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: snapshot.data!.docs.map((doc) {
                              var need = doc.data() as Map<String, dynamic>;
                              return Container(
                                width: 220,
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white, 
                                  borderRadius: BorderRadius.circular(16), 
                                  border: Border.all(color: Colors.teal.shade100, width: 2),
                                  boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 10)]
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(need['ngoName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.teal), overflow: TextOverflow.ellipsis),
                                    const Spacer(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("Needs ${need['mealsNeeded']} Meals", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                        const Icon(Icons.emergency, color: Colors.red, size: 16),
                                      ],
                                    ),
                                    const Text("Ready to receive now", style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 25),
                    const Text("Live Rescues Nearby", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('donations')
                  .where('status', isEqualTo: 'Available')
                  .where('city', isEqualTo: city)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: Colors.green)));
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("No active rescues.", style: TextStyle(color: Colors.grey)))));

                List<DocumentSnapshot> freshDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['exactExpiryTime'] == null) return false;
                  DateTime expiry = (data['exactExpiryTime'] as Timestamp).toDate();
                  return expiry.isAfter(DateTime.now());
                }).toList();

                if (freshDocs.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No fresh food available.", style: TextStyle(color: Colors.grey)))));

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      var doc = freshDocs[index];
                      return AvailableDonationCard(donation: doc.data() as Map<String, dynamic>, donationId: doc.id, vLat: vLat, vLon: vLon, volunteerUid: widget.uid, vehicleType: vehicleType);
                    }, childCount: freshDocs.length),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }
}
