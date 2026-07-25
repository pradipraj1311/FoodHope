import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SquadLeaderboardScreen extends StatefulWidget {
  final String currentUserUid;
  const SquadLeaderboardScreen({super.key, required this.currentUserUid});

  @override
  State<SquadLeaderboardScreen> createState() => _SquadLeaderboardScreenState();
}

class _SquadLeaderboardScreenState extends State<SquadLeaderboardScreen> with SingleTickerProviderStateMixin {
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

  Widget _buildTopThree(List<DocumentSnapshot> squads) {
    if (squads.isEmpty) return const SizedBox(height: 200);

    List<DocumentSnapshot?> topThree = [
      squads.isNotEmpty ? squads[0] : null,
      squads.length > 1 ? squads[1] : null,
      squads.length > 2 ? squads[2] : null,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumSpot(topThree[1], 2, 120, const Color(0xFFC0C0C0)),
          _buildPodiumSpot(topThree[0], 1, 170, const Color(0xFFFFD700)),
          _buildPodiumSpot(topThree[2], 3, 100, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _buildPodiumSpot(DocumentSnapshot? doc, int rank, double height, Color color) {
    if (doc == null || !doc.exists) return SizedBox(height: height, width: 90);

    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String name = data['name'] ?? 'Squad';
    String score = (data['totalRankScore'] ?? 0).toString();

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: height),
      duration: Duration(milliseconds: 1000 + (rank * 200)),
      curve: Curves.elasticOut,
      builder: (context, val, child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(Icons.groups, color: color, size: rank == 1 ? 40 : 30),
            ),
            const SizedBox(height: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white), overflow: TextOverflow.ellipsis),
            Text("$score pts", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 12),
            Container(
              width: rank == 1 ? 100 : 85,
              height: val,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withOpacity(0.4)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Center(child: Text("$rank", style: const TextStyle(color: Colors.white70, fontSize: 30, fontWeight: FontWeight.bold))),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListTile(DocumentSnapshot doc, int rank, String? mySquadId) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    bool isMySquad = doc.id == mySquadId;
    String name = data['name'] ?? 'Squad';
    int points = data['totalRankScore'] ?? 0;
    int memberCount = (data['members'] as List?)?.length ?? 0;

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMySquad ? Colors.white : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: isMySquad ? Border.all(color: Colors.blueAccent, width: 2) : null,
          boxShadow: [
            BoxShadow(
              color: isMySquad ? Colors.blueAccent.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Text("#$rank", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.grey.shade400)),
            const SizedBox(width: 15),
            const CircleAvatar(
              radius: 22,
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.groups, color: Colors.white),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("$memberCount Members", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("$points", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black87)),
                const Text("PTS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).get(),
      builder: (context, userSnap) {
        String? mySquadId;
        if (userSnap.hasData && userSnap.data!.exists) {
          mySquadId = (userSnap.data!.data() as Map<String, dynamic>)['squadId'];
        }

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
                      const Text("ECO-SQUADS", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      const Icon(Icons.workspace_premium, color: Colors.blueAccent, size: 30),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('squads')
                        .orderBy('totalRankScore', descending: true)
                        .limit(20)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text("No squads formed yet. Be the first! 🛡️", style: TextStyle(color: Colors.white70)));
                      }

                      List<DocumentSnapshot> allSquads = snapshot.data!.docs;
                      List<DocumentSnapshot> topThree = allSquads.take(3).toList();
                      List<DocumentSnapshot> theRest = allSquads.skip(3).toList();

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _buildTopThree(topThree)),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildListTile(theRest[index], index + 4, mySquadId),
                              childCount: theRest.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 50)),
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
    );
  }
}
