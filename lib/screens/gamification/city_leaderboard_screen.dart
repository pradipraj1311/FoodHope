import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CityLeaderboardScreen extends StatelessWidget {
  final String currentUserUid;
  final String userCity;

  const CityLeaderboardScreen({super.key, required this.currentUserUid, required this.userCity});

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
          title: Text("Nadiad Rankings 🏆"),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white, // FIX: Forces selected text to be solid white
            unselectedLabelColor: Colors.white70, // FIX: Forces unselected text to be slightly faded white
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildLeaderboardList(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('city', isEqualTo: userCity)
          .where('role', isEqualTo: role)
          .orderBy('rankScore', descending: true)
          .limit(10) // STRICT TOP 10 FILTER
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No $role rankings yet in $userCity."));
        }

        var users = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            var data = users[index].data() as Map<String, dynamic>;
            bool isMe = users[index].id == currentUserUid;
            int rank = index + 1;

            return Card(
              elevation: isMe ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: isMe ? BorderSide(color: Colors.green, width: 2) : BorderSide.none,
              ),
              child: ListTile(
                leading: _buildRankBadge(rank),
                title: Text(data['name'] ?? 'User', style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text("Level: ${data['level'] ?? 'Bronze'}"),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${data['impactPoints'] ?? 0} pts", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    if (role == 'Donor') Text("${data['totalMealsSaved'] ?? 0} meals saved", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRankBadge(int rank) {
    if (rank == 1) return const Icon(Icons.emoji_events, color: Colors.amber);
    if (rank == 2) return const Icon(Icons.emoji_events, color: Colors.grey);
    if (rank == 3) return const Icon(Icons.emoji_events, color: Colors.brown);
    return CircleAvatar(radius: 12, backgroundColor: Colors.grey.shade200, child: Text(rank.toString(), style: const TextStyle(fontSize: 10, color: Colors.black54)));
  }
}