import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/squad_service.dart';
import 'squad_leaderboard_screen.dart';

class SquadsHubScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const SquadsHubScreen({super.key, required this.userData, required this.uid});

  @override
  State<SquadsHubScreen> createState() => _SquadsHubScreenState();
}

class _SquadsHubScreenState extends State<SquadsHubScreen> {
  final TextEditingController _squadNameController = TextEditingController();
  final TextEditingController _squadDescController = TextEditingController();

  void _showCreateSquadDialog() {
    String role = widget.userData['role'] ?? 'Volunteer';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Form a Community Team 🛡️"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _squadNameController, decoration: const InputDecoration(labelText: "Team Name (e.g. Piplag Warriors)")),
            const SizedBox(height: 10),
            TextField(controller: _squadDescController, decoration: const InputDecoration(labelText: "Our Motto")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_squadNameController.text.isNotEmpty) {
                await SquadService.createSquad(
                  name: _squadNameController.text.trim(),
                  description: _squadDescController.text.trim(),
                  creatorUid: widget.uid,
                  city: widget.userData['city'] ?? 'Global',
                  role: role,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create Team"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? mySquadId = widget.userData['squadId'];
    String myRole = widget.userData['role'] ?? 'Volunteer';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("COMMUNITY TEAMS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadLeaderboardScreen(currentUserUid: widget.uid))),
          )
        ],
      ),
      body: Column(
        children: [
          if (mySquadId != null) 
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('squads').doc(mySquadId).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                var squadData = snapshot.data!.data() as Map<String, dynamic>;
                List<String> memberUids = List<String>.from(squadData['members'] ?? []);

                return Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2DD4BF)]),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Text("OUR ACTIVE TEAM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
                      const SizedBox(height: 10),
                      Text(squadData['name'], style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                      Text(squadData['description'] ?? '', style: const TextStyle(color: Colors.white70)),
                      const Divider(color: Colors.white24, height: 30),
                      
                      const Text("Team Members:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: memberUids.take(10).toList()).get(),
                        builder: (context, mSnap) {
                          if (!mSnap.hasData) return const SizedBox.shrink();
                          String names = mSnap.data!.docs.map((d) => (d.data() as Map)['name'] ?? 'User').join(', ');
                          return Text(names, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12));
                        },
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSquadStat("${memberUids.length}", "Members"),
                          _buildSquadStat("${squadData['totalRankScore']}", "Points"),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () => SquadService.leaveSquad(mySquadId, widget.uid),
                        child: const Text("Leave Team", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
                      )
                    ],
                  ),
                );
              }
            )
          else 
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
              child: Column(
                children: [
                  const Icon(Icons.groups_rounded, size: 60, color: Colors.blueAccent),
                  const SizedBox(height: 20),
                  Text("Join a $myRole Team!", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text("Saving food is better with friends. Join a team or create your own to climb the ranks.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: _showCreateSquadDialog,
                      child: const Text("Form a New Team", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Align(alignment: Alignment.centerLeft, child: Text("AVAILABLE TEAMS", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1))),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('squads')
                  .where('role', isEqualTo: myRole)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    if (doc.id == mySquadId) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(data['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${(data['members'] as List).length} members • ${data['city']}", style: const TextStyle(color: Colors.white38)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                          onPressed: () => SquadService.joinSquad(doc.id, widget.uid),
                          child: const Text("Join"),
                        ),
                      ),
                    );
                  },
                );
              }
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSquadStat(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
