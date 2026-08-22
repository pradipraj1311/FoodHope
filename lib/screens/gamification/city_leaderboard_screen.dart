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

class _CityLeaderboardScreenState extends State<CityLeaderboardScreen> {
  @override
  Widget build(BuildContext context) {
    // SENIOR DEV FIX: Strict Role Filtering (No Mixing)
    Query query = FirebaseFirestore.instance.collection('users')
        .where('role', isEqualTo: widget.userRole);
    
    if (widget.userCity != 'All' && widget.userCity != 'Set Location') {
      query = query.where('city', isEqualTo: widget.userCity);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          children: [
            Text("${widget.userCity.toUpperCase()} HEROES", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("${widget.userRole} Category", style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ],
        ),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No heroes in this city yet.", style: TextStyle(color: Colors.white24)));

          List<DocumentSnapshot> users = snapshot.data!.docs.toList();
          // Local Sort by points
          users.sort((a, b) => ((b.data() as Map)['rankScore'] ?? 0).compareTo((a.data() as Map)['rankScore'] ?? 0));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              var data = users[index].data() as Map<String, dynamic>;
              int pts = data['rankScore'] ?? 0;
              String img = data['profileImageUrl'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: users[index].id == widget.currentUserUid ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: users[index].id == widget.currentUserUid ? Border.all(color: Colors.amber, width: 1.5) : null,
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.blueGrey : (index == 2 ? Colors.brown : Colors.white10)),
                    backgroundImage: img.isNotEmpty ? MemoryImage(base64Decode(img)) : null,
                    child: img.isEmpty ? Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                  ),
                  title: Text(data['name'] ?? data['businessName'] ?? "Hero", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${data['city'] ?? ''}", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  trailing: Text("$pts Pts", style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
