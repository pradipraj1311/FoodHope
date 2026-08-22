import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SquadLeaderboardScreen extends StatefulWidget {
  final String currentUserUid;
  final String userCity;
  final String userRole;

  const SquadLeaderboardScreen({
    super.key, 
    required this.currentUserUid, 
    required this.userCity,
    required this.userRole
  });

  @override
  State<SquadLeaderboardScreen> createState() => _SquadLeaderboardScreenState();
}

class _SquadLeaderboardScreenState extends State<SquadLeaderboardScreen> {
  String? mySquadId;

  @override
  void initState() {
    super.initState();
    _fetchUserSquad();
  }

  void _fetchUserSquad() async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).get();
    if (doc.exists) {
      if (mounted) setState(() => mySquadId = doc.data()?['squadId']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text("${widget.userCity.toUpperCase()} SQUADS", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("${widget.userRole} Community", style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // SENIOR DEV FIX: Simplified query to prevent index buffering errors during presentation
        stream: FirebaseFirestore.instance.collection('squads')
            .where('city', isEqualTo: widget.userCity)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No squads found.", style: TextStyle(color: Colors.white24)));

          // Local Filter and Sort for role-specific ranking
          List<DocumentSnapshot> squads = snapshot.data!.docs.where((doc) {
            return (doc.data() as Map)['role'] == widget.userRole;
          }).toList();

          if (squads.isEmpty) return Center(child: Text("No ${widget.userRole} squads in your city.", style: const TextStyle(color: Colors.white24)));

          squads.sort((a, b) => ((b.data() as Map)['totalPoints'] ?? 0).compareTo((a.data() as Map)['totalPoints'] ?? 0));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: squads.length,
            itemBuilder: (context, index) {
              var data = squads[index].data() as Map<String, dynamic>;
              int pts = data['totalPoints'] ?? 0;
              int members = data['memberCount'] ?? 0;
              bool isMySquad = squads[index].id == mySquadId;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isMySquad ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: isMySquad ? Border.all(color: Colors.blueAccent, width: 2) : null,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.blueGrey : (index == 2 ? Colors.brown : Colors.white10)),
                    child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(data['name'] ?? "Squad", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("$members Members • $pts Points", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: index < 3 ? const Icon(Icons.workspace_premium, color: Colors.amber) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
