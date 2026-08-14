import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class CityLeaderboardScreen extends StatefulWidget {
  final String currentUserUid;
  final String userCity;
  final String userRole;

  const CityLeaderboardScreen({
    super.key, 
    required this.currentUserUid, 
    required this.userCity,
    required this.userRole
  });

  @override
  State<CityLeaderboardScreen> createState() => _CityLeaderboardScreenState();
}

class _CityLeaderboardScreenState extends State<CityLeaderboardScreen> with SingleTickerProviderStateMixin {
  late String _selectedRole;
  final List<String> _roles = ['Volunteer', 'NGO', 'Donor'];
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.userRole; 
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color _getRoleColor(String role) {
    if (role == 'Volunteer') return Colors.greenAccent;
    if (role == 'NGO') return Colors.tealAccent;
    return Colors.orangeAccent;
  }

  Widget _buildTopThree(List<DocumentSnapshot> users) {
    if (users.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Finding heroes...", style: TextStyle(color: Colors.white24))));

    List<DocumentSnapshot?> topThree = [
      users.isNotEmpty ? users[0] : null,
      users.length > 1 ? users[1] : null,
      users.length > 2 ? users[2] : null,
    ];

    Color roleColor = _getRoleColor(_selectedRole);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumSpot(topThree[1], 2, 120, const Color(0xFFC0C0C0), roleColor),
          _buildPodiumSpot(topThree[0], 1, 170, const Color(0xFFFFD700), roleColor),
          _buildPodiumSpot(topThree[2], 3, 100, const Color(0xFFCD7F32), roleColor),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(DocumentSnapshot? doc, int rank, double height, Color baseColor, Color roleColor) {
    if (doc == null || !doc.exists) return SizedBox(height: height, width: 90);
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = (data['name'] ?? data['organizationName'] ?? data['businessName'] ?? 'Hero').split(' ')[0];
    String score = (data['rankScore'] ?? 0).toString();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(radius: rank == 1 ? 42 : 32, backgroundColor: baseColor, child: CircleAvatar(radius: rank == 1 ? 38 : 28, backgroundColor: Colors.black)),
            if (rank == 1) const Positioned(top: -15, child: Icon(Icons.workspace_premium, color: Colors.amber, size: 30)),
          ],
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        Text("$score pts", style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 12),
        Container(width: rank == 1 ? 90 : 75, height: height, decoration: BoxDecoration(color: baseColor.withOpacity(0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(20)))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Text(widget.userCity.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 20),
          // Role Toggles
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: _roles.map((role) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedRole = role),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: _selectedRole == role ? _getRoleColor(role) : Colors.transparent, borderRadius: BorderRadius.circular(15)),
                    child: Center(child: Text(role, style: TextStyle(color: _selectedRole == role ? Colors.black : Colors.white60, fontWeight: FontWeight.bold))),
                  ),
                ),
              )).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // SENIOR DEV FIX: Fetch by role & city, but SORT LOCALLY to prevent buffering/index errors
              stream: FirebaseFirestore.instance.collection('users')
                  .where('role', isEqualTo: _selectedRole)
                  .where('city', isEqualTo: widget.userCity)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No data for this city.", style: TextStyle(color: Colors.white24)));

                // Local Sort Logic
                List<DocumentSnapshot> users = snapshot.data!.docs.toList();
                users.sort((a, b) => ((b.data() as Map)['rankScore'] ?? 0).compareTo((a.data() as Map)['rankScore'] ?? 0));

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildTopThree(users.take(3).toList())),
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        var data = users[index + 3].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: Text("#${index + 4}", style: const TextStyle(color: Colors.white38)),
                          title: Text(data['name'] ?? data['businessName'] ?? "Hero", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          trailing: Text("${data['rankScore'] ?? 0} pts", style: TextStyle(color: _getRoleColor(_selectedRole), fontWeight: FontWeight.bold)),
                        );
                      }, childCount: users.length > 3 ? users.length - 3 : 0),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
