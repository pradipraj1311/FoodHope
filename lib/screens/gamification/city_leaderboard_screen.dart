import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class CityLeaderboardScreen extends StatelessWidget {
  final String currentUserUid;
  final String userCity;

  const CityLeaderboardScreen({super.key, required this.currentUserUid, required this.userCity});

  // --- PODIUM WIDGET HELPER ---
  Widget _buildPodium(Map<String, dynamic> userData, int rank, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 35 : 28,
              backgroundColor: color.withOpacity(0.2),
              backgroundImage: userData['profileImageUrl'] != null ? NetworkImage(userData['profileImageUrl']) : null,
              child: userData['profileImageUrl'] == null ? Icon(Icons.person, color: color, size: 30) : null,
            ),
            CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: Text(rank.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(userData['name']?.split(' ')[0] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
        Text("${userData['impactPoints'] ?? 0} pts", style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: rank == 1 ? 80 : 70,
          height: height,
          decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, -5))]
          ),
          child: Center(child: Text(userData['level'] ?? 'Bronze', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Leaderboard 🏆", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              Text("📍 $userCity • This Week", style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
            tabs: [
              Tab(icon: Icon(Icons.motorcycle), text: "Volunteers"),
              Tab(icon: Icon(Icons.restaurant), text: "Donors"),
              Tab(icon: Icon(Icons.corporate_fare), text: "NGOs"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLeaderboardList('Volunteer'),
            _buildLeaderboardList('Donor'),
            _buildLeaderboardList('NGO'),
          ],
        ),
      ),
    );
  }

  // --- MAIN LIST BUILDER FOR EACH TAB ---
  Widget _buildLeaderboardList(String role) {
    return StreamBuilder<QuerySnapshot>(
      // Queries the Gamification Engine's Pre-Calculated Ranks
        stream: FirebaseFirestore.instance.collection('users')
            .where('city', isEqualTo: userCity)
            .where('role', isEqualTo: role)
            .orderBy('rankScore', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 60, color: Colors.grey.shade400),
                    const SizedBox(height: 10),
                    Text("No $role rankings yet in $userCity.", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                    const Text("Be the first to get on the board!", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                )
            );
          }

          var topUsers = snapshot.data!.docs;

          // Find current user's rank and calculate the points needed to rank up
          int myRank = -1;
          int pointsToNext = 0;
          Map<String, dynamic>? myData;

          for (int i = 0; i < topUsers.length; i++) {
            if (topUsers[i].id == currentUserUid) {
              myRank = i + 1;
              myData = topUsers[i].data() as Map<String, dynamic>;
              if (i > 0) {
                var rankAboveMe = topUsers[i - 1].data() as Map<String, dynamic>;
                pointsToNext = ((rankAboveMe['rankScore'] ?? 0) - (myData['rankScore'] ?? 0)) + 1;
              }
              break;
            }
          }

          return Column(
            children: [
              // --- THE TOP 3 PODIUM ---
              if (topUsers.isNotEmpty)
                Container(
                  padding: const EdgeInsets.only(top: 30, bottom: 0, left: 16, right: 16),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (topUsers.length > 1) _buildPodium(topUsers[1].data() as Map<String, dynamic>, 2, 80, Colors.blueGrey),
                      const SizedBox(width: 15),
                      if (topUsers.isNotEmpty) _buildPodium(topUsers[0].data() as Map<String, dynamic>, 1, 110, Colors.amber.shade600),
                      const SizedBox(width: 15),
                      if (topUsers.length > 2) _buildPodium(topUsers[2].data() as Map<String, dynamic>, 3, 60, Colors.brown.shade400),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // --- RANK 4 TO 50 LIST ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: topUsers.length > 3 ? topUsers.length - 3 : 0,
                  itemBuilder: (context, index) {
                    int rank = index + 4;
                    var user = topUsers[rank - 1].data() as Map<String, dynamic>;
                    bool isMe = topUsers[rank - 1].id == currentUserUid;

                    return Card(
                      elevation: isMe ? 4 : 1,
                      shadowColor: isMe ? Colors.green.withOpacity(0.4) : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: isMe ? BorderSide(color: Colors.green.shade400, width: 2) : BorderSide.none
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.grey.shade200, child: Text("#$rank", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                        title: Text(user['name'] ?? 'User', style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text("Level: ${user['level'] ?? 'Starter'}"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${user['impactPoints'] ?? 0} pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                            if (role == 'Donor') Text("${user['totalDonationsMade'] ?? 0} donations", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // --- MOTIVATIONAL 'YOUR RANK' BOTTOM BAR (ONLY SHOWS ON YOUR ROLE'S TAB) ---
              if (myRank != -1 && myData != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                      color: Colors.green.shade800,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))]
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Your Rank: #$myRank", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              if (myRank > 1)
                                Text("Only $pointsToNext points to reach #${myRank - 1} 🔥", style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              if (myRank == 1)
                                const Text("You are the City Champion! 👑", style: TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),

                        // --- THE VIRALITY SHARE BUTTON ---
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green.shade800,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                          ),
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text("Share", style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () {
                            // Dynamic Text Based on Role
                            String roleText = "Food Rescuer";
                            if (role == 'Donor') roleText = "Food Donor";
                            if (role == 'NGO') roleText = "Distribution Hub";

                            String shareText = "🏆 I am officially the #$myRank $roleText in $userCity on Food Hope! I have earned ${myData!['impactPoints']} points fighting hunger.\n\nDownload the app and join me in saving food!";

                            Share.share(shareText);
                          },
                        )
                      ],
                    ),
                  ),
                ),
            ],
          );
        }
    );
  }
}