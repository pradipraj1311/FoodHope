import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CityLeaderboardScreen extends StatefulWidget {
  final String currentUserUid;
  final String userCity; // To filter by city if needed later

  const CityLeaderboardScreen({super.key, required this.currentUserUid, required this.userCity});

  @override
  State<CityLeaderboardScreen> createState() => _CityLeaderboardScreenState();
}

class _CityLeaderboardScreenState extends State<CityLeaderboardScreen> {
  // Toggle between viewing Volunteers and NGOs
  String _selectedRole = 'Volunteer';

  Widget _buildTopThree(List<DocumentSnapshot> users) {
    if (users.isEmpty) return const SizedBox.shrink();

    // Pad the list to ensure we always have 3 spots for the UI
    List<DocumentSnapshot?> topThree = [
      users.isNotEmpty ? users[0] : null,
      users.length > 1 ? users[1] : null,
      users.length > 2 ? users[2] : null,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2ND PLACE
          _buildPodiumSpot(topThree[1], 2, 100, Colors.grey.shade400),
          // 1ST PLACE
          _buildPodiumSpot(topThree[0], 1, 140, Colors.amber.shade400),
          // 3RD PLACE
          _buildPodiumSpot(topThree[2], 3, 80, Colors.brown.shade400),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(DocumentSnapshot? doc, int rank, double height, Color color) {
    if (doc == null || !doc.exists) return SizedBox(height: height, width: 80);

    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = data['name'] ?? data['distributorName'] ?? data['businessName'] ?? 'Hero';
    String points = (data['rankScore'] ?? 0).toString();

    // Default icons if no photo
    IconData defaultIcon = _selectedRole == 'NGO' ? Icons.corporate_fare : Icons.person;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: rank == 1 ? 35 : 25,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(defaultIcon, color: color, size: rank == 1 ? 40 : 30),
        ),
        const SizedBox(height: 8),
        Text(name.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
        Text("$points pts", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          width: rank == 1 ? 90 : 75,
          height: height,
          decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]
          ),
          child: Center(
            child: Text("$rank", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white70)),
          ),
        ),
      ],
    );
  }

  Widget _buildListTile(DocumentSnapshot doc, int rank) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isMe = doc.id == widget.currentUserUid;
    String name = data['name'] ?? data['distributorName'] ?? data['businessName'] ?? 'Hero';
    int points = data['rankScore'] ?? 0;
    int deliveries = data['deliveriesMade'] ?? data['deliveriesReceived'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: isMe ? Colors.green.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isMe ? Colors.green.shade300 : Colors.grey.shade200, width: isMe ? 2 : 1),
          boxShadow: [if (isMe) BoxShadow(color: Colors.green.shade100, blurRadius: 8, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          SizedBox(
              width: 30,
              child: Text("#$rank", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isMe ? Colors.green.shade800 : Colors.grey.shade600))
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade100,
            child: Icon(_selectedRole == 'NGO' ? Icons.corporate_fare : Icons.person, color: Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (isMe) ...[
                      const SizedBox(width: 8),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)), child: const Text("YOU", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                    ]
                  ],
                ),
                Text("$deliveries Rescues", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text("$points", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.amber)),
          const Icon(Icons.star, color: Colors.amber, size: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("City Leaderboard", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text("Volunteers"),
                  selected: _selectedRole == 'Volunteer',
                  selectedColor: Colors.green.shade100,
                  onSelected: (val) => setState(() => _selectedRole = 'Volunteer'),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text("NGO Hubs"),
                  selected: _selectedRole == 'NGO',
                  selectedColor: Colors.teal.shade100,
                  onSelected: (val) => setState(() => _selectedRole = 'NGO'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Query users by role, sorted by their rankScore (highest first)
        stream: FirebaseFirestore.instance.collection('users')
            .where('role', isEqualTo: _selectedRole)
            .orderBy('rankScore', descending: true)
            .limit(20) // Only show top 20 to keep it fast
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.green));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No data yet. Go rescue some food!"));
          }

          List<DocumentSnapshot> allUsers = snapshot.data!.docs;

          // Separate top 3 from the rest
          List<DocumentSnapshot> topThree = allUsers.take(3).toList();
          List<DocumentSnapshot> theRest = allUsers.length > 3 ? allUsers.skip(3).toList() : [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  child: _buildTopThree(topThree),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    // Rank is index + 4 (because 1, 2, 3 are on the podium)
                    return _buildListTile(theRest[index], index + 4);
                  },
                  childCount: theRest.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}