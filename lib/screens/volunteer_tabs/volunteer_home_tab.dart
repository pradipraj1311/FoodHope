import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'widgets/active_delivery_card.dart';
import 'widgets/available_donation_card.dart';
import '../gamification/city_leaderboard_screen.dart';
import '../gamification/squads_hub_screen.dart';

class VolunteerHomeTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const VolunteerHomeTab({super.key, required this.userData, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Current Volunteer Location (Double cast to prevent 0.0 errors)
    double vLat = (userData['latitude'] ?? 0.0).toDouble();
    double vLon = (userData['longitude'] ?? 0.0).toDouble();
    String vehicleType = userData['vehicleType'] ?? 'Scooter / Motorcycle';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
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
                                "Welcome, ${userData['name']?.split(' ')[0] ?? 'Hero'}!",
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green)
                            ),
                            const Text("Ready to rescue some food today?", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.shield, color: Colors.blueAccent, size: 28),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SquadsHubScreen(userData: userData, uid: uid))
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => CityLeaderboardScreen(
                                        currentUserUid: uid,
                                        userCity: userData['city'] ?? 'All'
                                    ))
                                );
                              },
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 25),

                    ActiveDeliveryCard(volunteerUid: uid),

                    const SizedBox(height: 10),
                    const Text("Available Rescues Nearby", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              // FIXED: Single field query to bypass Firestore index requirement
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', isEqualTo: 'Available')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: Colors.green)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50),
                        child: Text("No active rescues nearby right now.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ),
                    ),
                  );
                }

                // Client-side filtering for Expiry and Ranking by Distance
                List<DocumentSnapshot> allDocs = snapshot.data!.docs;
                DateTime now = DateTime.now();

                // 1. Filter out expired food
                List<DocumentSnapshot> freshDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (data['exactExpiryTime'] == null) return false;
                  DateTime expiry = (data['exactExpiryTime'] as Timestamp).toDate();
                  return expiry.isAfter(now);
                }).toList();

                // 2. Rank by Distance (Closest first)
                freshDocs.sort((a, b) {
                  var dataA = a.data() as Map<String, dynamic>;
                  var dataB = b.data() as Map<String, dynamic>;
                  
                  double latA = (dataA['latitude'] ?? 0.0).toDouble();
                  double lonA = (dataA['longitude'] ?? 0.0).toDouble();
                  double latB = (dataB['latitude'] ?? 0.0).toDouble();
                  double lonB = (dataB['longitude'] ?? 0.0).toDouble();

                  double distA = (vLat != 0 && vLon != 0 && latA != 0 && lonA != 0) 
                      ? Geolocator.distanceBetween(vLat, vLon, latA, lonA) 
                      : 999999;
                  double distB = (vLat != 0 && vLon != 0 && latB != 0 && lonB != 0) 
                      ? Geolocator.distanceBetween(vLat, vLon, latB, lonB) 
                      : 999999;
                  
                  return distA.compareTo(distB);
                });

                if (freshDocs.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No fresh food available right now.", style: TextStyle(color: Colors.grey)))),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        var doc = freshDocs[index];
                        return AvailableDonationCard(
                          donation: doc.data() as Map<String, dynamic>,
                          donationId: doc.id,
                          vLat: vLat,
                          vLon: vLon,
                          volunteerUid: uid,
                          vehicleType: vehicleType,
                        );
                      },
                      childCount: freshDocs.length,
                    ),
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
