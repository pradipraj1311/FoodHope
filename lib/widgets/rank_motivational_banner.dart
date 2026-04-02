import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankMotivationalBanner extends StatelessWidget {
  final String uid;
  final String city;
  final String role;

  const RankMotivationalBanner({super.key, required this.uid, required this.city, required this.role});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users')
          .where('city', isEqualTo: city)
          .where('role', isEqualTo: role)
          .orderBy('rankScore', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        var users = snapshot.data!.docs;
        int myRank = -1;
        int myPoints = 0;
        int pointsToNext = 0;

        for (int i = 0; i < users.length; i++) {
          if (users[i].id == uid) {
            myRank = i + 1;
            myPoints = (users[i].data() as Map<String, dynamic>)['impactPoints'] ?? 0;
            if (i > 0) {
              var userAboveMe = users[i - 1].data() as Map<String, dynamic>;
              pointsToNext = ((userAboveMe['rankScore'] ?? 0) - ((users[i].data() as Map<String, dynamic>)['rankScore'] ?? 0)) + 1;
            }
            break;
          }
        }

        if (myRank == -1) return const SizedBox.shrink(); // User not ranked yet

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.green.shade800, Colors.green.shade600]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
          ),
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Your $city Rank: #$myRank ($myPoints pts)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    if (myRank > 1)
                      Text("Earn $pointsToNext more points to reach #${myRank - 1}! 🔥", style: TextStyle(color: Colors.amber.shade100, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (myRank == 1)
                      Text("You are the #1 Champion! 👑", style: TextStyle(color: Colors.amber.shade100, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}