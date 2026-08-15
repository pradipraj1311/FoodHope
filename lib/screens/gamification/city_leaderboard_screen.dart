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
    String img = data['profileImageUrl'] ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: baseColor, width: 2)),
              child: CircleAvatar(
                radius: rank == 1 ? 40 : 30,
                backgroundColor: Colors.white10,
                backgroundImage: img.isNotEmpty ? MemoryImage(base64Decode(img)) : null,
                child: img.isEmpty ? Icon(Icons.person, color: Colors.white38, size: rank == 1 ? 40 : 30) : null,
              ),
            ),
            if (rank == 1) const Positioned(top: -15, child: Icon(Icons.workspace_premium, color: Colors.amber, size: 30)),
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
                child: Text("$rank", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
              ),
            )
          ],
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
        Text("$score pts", style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 12),
        Container(
          width: rank == 1 ? 90 : 75, 
          height: height, 
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [baseColor.withOpacity(0.3), baseColor.withOpacity(0.05)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
          )
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: _selectedRole);
    
    // Filter by city if not "All"
    if (widget.userCity != 'All' && widget.userCity != 'Set Location') {
      query = query.where('city', isEqualTo: widget.userCity);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white)),
                Text(widget.userCity.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No heroes found here.", style: TextStyle(color: Colors.white24)));

                List<DocumentSnapshot> users = snapshot.data!.docs.toList();
                users.sort((a, b) => ((b.data() as Map)['rankScore'] ?? 0).compareTo((a.data() as Map)['rankScore'] ?? 0));

                int myRank = -1;
                for (int i = 0; i < users.length; i++) {
                  if (users[i].id == widget.currentUserUid) { myRank = i + 1; break; }
                }

                return Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(child: _buildTopThree(users.take(3).toList())),
                          SliverList(
                            delegate: SliverChildBuilderDelegate((context, index) {
                              var data = users[index + 3].data() as Map<String, dynamic>;
                              String img = data['profileImageUrl'] ?? '';
                              return ListTile(
                                leading: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text("#${index + 4}", style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 10),
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundImage: img.isNotEmpty ? MemoryImage(base64Decode(img)) : null,
                                      child: img.isEmpty ? const Icon(Icons.person, size: 18) : null,
                                    ),
                                  ],
                                ),
                                title: Text(data['name'] ?? data['businessName'] ?? "Hero", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                trailing: Text("${data['rankScore'] ?? 0} pts", style: TextStyle(color: _getRoleColor(_selectedRole), fontWeight: FontWeight.bold)),
                              );
                            }, childCount: users.length > 3 ? users.length - 3 : 0),
                          ),
                        ],
                      ),
                    ),
                    if (myRank != -1)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                        child: Row(
                          children: [
                            Text("#$myRank", style: TextStyle(color: _getRoleColor(widget.userRole), fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 15),
                            const Text("YOUR CURRENT RANK", style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Text("${users[myRank - 1]['rankScore']} PTS", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
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
