import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- FIXED IMPORTS BASED ON YOUR FOLDER STRUCTURE ---
import 'widgets/active_delivery_card.dart'; // <-- આ પાથ સુધારી દીધો છે!
import 'widgets/available_donation_card.dart';
import '../gamification/city_leaderboard_screen.dart';

class VolunteerHomeTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const VolunteerHomeTab({super.key, required this.userData, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Grab the volunteer's location (defaults to 0.0 if not yet set)
    double vLat = userData['latitude'] ?? 0.0;
    double vLon = userData['longitude'] ?? 0.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- WELCOME HEADER & LEADERBOARD BUTTON ---
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
                        // THE LEADERBOARD BUTTON
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
                        )
                      ],
                    ),
                    const SizedBox(height: 25),

                    // --- 1. THE ACTIVE DELIVERY TRACKER ---
                    ActiveDeliveryCard(volunteerUid: uid),

                    const SizedBox(height: 10),
                    const Text("Available Rescues Nearby", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),

            // --- 2. THE LIST OF AVAILABLE DONATIONS ---
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('status', isEqualTo: 'Available')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: Colors.green)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50),
                          Icon(Icons.volunteer_activism, size: 80, color: Colors.grey.shade200),
                          const SizedBox(height: 15),
                          Text("No active rescues nearby right now.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        var doc = snapshot.data!.docs[index];
                        return AvailableDonationCard(
                          donation: doc.data() as Map<String, dynamic>,
                          donationId: doc.id,
                          vLat: vLat,
                          vLon: vLon,
                          volunteerUid: uid,
                        );
                      },
                      childCount: snapshot.data!.docs.length,
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