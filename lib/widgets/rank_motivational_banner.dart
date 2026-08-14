import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankMotivationalBanner extends StatelessWidget {
  final String uid;
  final String city;
  final String role;

  const RankMotivationalBanner({super.key, required this.uid, required this.city, required this.role});

  @override
  Widget build(BuildContext context) {
    if (city.isEmpty || city == 'Fetching...' || city == 'Locating...') return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      // SIMPLE QUERY: Prevents "Buffering" and index errors
      stream: FirebaseFirestore.instance.collection('users')
          .where('city', isEqualTo: city)
          .where('role', isEqualTo: role)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        // SENIOR DEV FIX: Local Sorting ensures Champions show up instantly
        var users = snapshot.data!.docs.toList();
        users.sort((a, b) {
          int scoreA = (a.data() as Map<String, dynamic>)['rankScore'] ?? 0;
          int scoreB = (b.data() as Map<String, dynamic>)['rankScore'] ?? 0;
          return scoreB.compareTo(scoreA);
        });

        int myRank = -1;
        int myPoints = 0;
        int pointsToNext = 0;

        for (int i = 0; i < users.length; i++) {
          if (users[i].id == uid) {
            myRank = i + 1;
            myPoints = (users[i].data() as Map<String, dynamic>)['rankScore'] ?? 0;
            if (i > 0) {
              var userAboveMe = users[i - 1].data() as Map<String, dynamic>;
              pointsToNext = ((userAboveMe['rankScore'] ?? 0) - myPoints) + 1;
            }
            break;
          }
        }

        if (myRank == -1) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: myRank == 1 
                ? [const Color(0xFFFFD700), const Color(0xFFFFA500)] 
                : [const Color(0xFF1B5E20), const Color(0xFF4CAF50)]
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))]
          ),
          child: Row(
            children: [
              Icon(myRank == 1 ? Icons.workspace_premium : Icons.emoji_events, color: Colors.white, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      myRank == 1 ? "CITY CHAMPION 👑" : "City Rank: #$myRank",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.1)
                    ),
                    Text(
                      myRank == 1 ? "You are the #1 hero in $city! 🏆" : "Only $pointsToNext pts to reach #${myRank - 1}! 🔥",
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                child: Text("$myPoints pts", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      },
    );
  }
}
