import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  void _showCreateSquadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Form a New Squad 🛡️"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Team Name")),
            const SizedBox(height: 10),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: "Motto")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                await SquadService.createSquad(
                  name: _nameController.text.trim(),
                  description: _descController.text.trim(),
                  creatorUid: widget.uid,
                  city: widget.userData['city'] ?? 'Unknown',
                  role: widget.userData['role'] ?? 'Volunteer',
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          )
        ],
      ),
    );
  }

  void _showJoinSquadDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Join via Code 🔑"),
        content: TextField(
          controller: _codeController,
          decoration: const InputDecoration(labelText: "Enter 6-digit Code"),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              String? error = await SquadService.joinSquadByCode(_codeController.text.trim(), widget.uid);
              if (error != null) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              } else {
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Join Team"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? mySquadId = widget.userData['squadId'];
    String myRole = widget.userData['role'] ?? 'Volunteer';
    String myCity = widget.userData['city'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("COMMUNITY HUB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard, color: Colors.amber),
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(
                builder: (_) => SquadLeaderboardScreen(
                  currentUserUid: widget.uid, 
                  userCity: myCity,
                  userRole: myRole, // FIXED: Separated by Role
                )
              )
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (mySquadId != null)
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('squads').doc(mySquadId).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  return _buildMySquadCard(data, mySquadId);
                },
              )
            else
              _buildNoSquadView(myRole),

            if (mySquadId != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Align(alignment: Alignment.centerLeft, child: Text("TEAM ACTIVITY", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.2))),
              ),
              _buildActivityFeed(mySquadId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMySquadCard(Map<String, dynamic> data, String squadId) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF1E1B4B)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(data['name'] ?? "Squad", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text("Role: ${data['role']} • City: ${data['city']}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statItem("${data['memberCount'] ?? 0}", "Heroes"),
              _statItem("${data['totalPoints'] ?? 0}", "Squad Pts"),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(15)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("INVITE CODE: ", style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(data['inviteCode'] ?? '------', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(width: 8),
                GestureDetector(onTap: () {
                  Clipboard.setData(ClipboardData(text: data['inviteCode'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
                }, child: const Icon(Icons.copy, color: Colors.white54, size: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(String squadId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('squads')
          .doc(squadId)
          .collection('activities')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Sync Error", style: TextStyle(color: Colors.white24)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No activity yet.", style: TextStyle(color: Colors.white24))));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var act = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            String user = act['userName'] ?? 'A Hero';
            String msg = act['message'] ?? 'completed a task';
            int pts = act['points'] ?? 0;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.amber, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        children: [
                          TextSpan(text: user, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          TextSpan(text: " $msg "),
                          TextSpan(text: "+$pts pts", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNoSquadView(String role) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          const Icon(Icons.groups_3_outlined, size: 60, color: Colors.blueAccent),
          const SizedBox(height: 20),
          Text("Join a $role Squad", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text("Join your friends to save more lives. Each category has its own leaderboard.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 30),
          Row(
            children: [
              Expanded(child: ElevatedButton(onPressed: _showCreateSquadDialog, child: const Text("Create"))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: _showJoinSquadDialog, child: const Text("Join", style: TextStyle(color: Colors.white)))),
            ],
          )
        ],
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }
}
