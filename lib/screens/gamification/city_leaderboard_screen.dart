import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class CityLeaderboardScreen extends StatefulWidget {
  final String currentUserUid;
  final String userCity;

  const CityLeaderboardScreen({super.key, required this.currentUserUid, required this.userCity});

  @override
  State<CityLeaderboardScreen> createState() => _CityLeaderboardScreenState();
}

class _CityLeaderboardScreenState extends State<CityLeaderboardScreen> with SingleTickerProviderStateMixin {
  String _selectedRole = 'Volunteer';
  final List<String> _roles = ['Volunteer', 'NGO', 'Donor'];
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildTopThree(List<DocumentSnapshot> users) {
    if (users.isEmpty) return const SizedBox(height: 200);

    List<DocumentSnapshot?> topThree = [
      users.isNotEmpty ? users[0] : null,
      users.length > 1 ? users[1] : null,
      users.length > 2 ? users[2] : null,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          _buildPodiumSpot(topThree[1], 2, 120, const Color(0xFFC0C0C0), const Color(0xFFE8E8E8)),
          // 1st Place
          _buildPodiumSpot(topThree[0], 1, 170, const Color(0xFFFFD700), const Color(0xFFFFF3A0)),
          // 3rd Place
          _buildPodiumSpot(topThree[2], 3, 100, const Color(0xFFCD7F32), const Color(0xFFFFD1A4)),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(DocumentSnapshot? doc, int rank, double height, Color baseColor, Color accentColor) {
    if (doc == null || !doc.exists) return SizedBox(height: height, width: 90);

    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = data['name'] ?? data['organizationName'] ?? data['businessName'] ?? 'Hero';
    String score = (data['rankScore'] ?? 0).toString();
    String imageBase64 = data['profileImageUrl'] ?? '';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: Duration(milliseconds: 1000 + (rank * 200)),
      curve: Curves.elasticOut,
      builder: (context, val, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [baseColor, accentColor]),
                  ),
                  child: CircleAvatar(
                    radius: rank == 1 ? 40 : 30,
                    backgroundColor: Colors.white,
                    backgroundImage: imageBase64.isNotEmpty ? MemoryImage(base64Decode(imageBase64)) : null,
                    child: imageBase64.isEmpty ? Icon(Icons.person, color: baseColor, size: rank == 1 ? 40 : 30) : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle),
                    child: Text("$rank", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(name.split(' ')[0], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
            Text("$score pts", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              width: rank == 1 ? 100 : 85,
              height: val,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [baseColor, baseColor.withOpacity(0.4)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: baseColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
              ),
              child: const Icon(Icons.flash_on, color: Colors.white54, size: 30),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListTile(DocumentSnapshot doc, int rank) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isMe = doc.id == widget.currentUserUid;
    String name = data['name'] ?? data['organizationName'] ?? data['businessName'] ?? 'Hero';
    int points = data['rankScore'] ?? 0;
    String imageBase64 = data['profileImageUrl'] ?? '';

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMe ? Colors.white : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: isMe ? Border.all(color: Colors.greenAccent, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: isMe ? Colors.greenAccent.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Text("#$rank", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.grey.shade400)),
            const SizedBox(width: 15),
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade100,
              backgroundImage: imageBase64.isNotEmpty ? MemoryImage(base64Decode(imageBase64)) : null,
              child: imageBase64.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (isMe) Text("Keep up the good work!", style: TextStyle(color: Colors.green.shade700, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("$points", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black87)),
                const Text("PTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios, color: Colors.white)),
                  const Text("LEADERBOARD", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: _roles.map((role) {
                  bool isSelected = _selectedRole == role;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedRole = role;
                        _fadeController.reset();
                        _fadeController.forward();
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.greenAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: Text(
                            role,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users')
                    .where('role', isEqualTo: _selectedRole)
                    .orderBy('rankScore', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No users found in this category.", style: TextStyle(color: Colors.white70)));
                  }

                  List<DocumentSnapshot> allUsers = snapshot.data!.docs;
                  int myRank = -1;
                  for (int i = 0; i < allUsers.length; i++) {
                    if (allUsers[i].id == widget.currentUserUid) {
                      myRank = i + 1;
                      break;
                    }
                  }

                  List<DocumentSnapshot> topThree = allUsers.take(3).toList();
                  List<DocumentSnapshot> displayList = allUsers.length > 3 ? allUsers.skip(3).take(17).toList() : [];

                  return Column(
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildTopThree(topThree)),
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildListTile(displayList[index], index + 4),
                                childCount: displayList.length,
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 100)),
                          ],
                        ),
                      ),
                      if (myRank != -1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, -5))],
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                          ),
                          child: Row(
                            children: [
                              Text("#$myRank", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.w900)),
                              const SizedBox(width: 15),
                              const CircleAvatar(backgroundColor: Colors.white12, child: Icon(Icons.person, color: Colors.white70)),
                              const SizedBox(width: 15),
                              const Text("YOU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text("${allUsers[myRank - 1]['rankScore'] ?? 0} PTS", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
