import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonorHistoryTab extends StatelessWidget {
  final String uid;

  const DonorHistoryTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Text("Impact Analytics 📊", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),

        // --- REAL TIME ML & ANALYTICS HEADER ---
        StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
              var userData = userSnapshot.data!.data() as Map<String, dynamic>;

              int totalPosts = userData['totalDonationsMade'] ?? 0;
              int cancellations = userData['cancellationCount'] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green.shade50,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.green.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            children: [
                              const Text("Total Posted", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text("$totalPosts", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Card(
                        color: Colors.red.shade50,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(15.0),
                          child: Column(
                            children: [
                              const Text("Cancellations", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text("$cancellations", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
        ),

        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 20, bottom: 8),
          child: Text("Past Deliveries", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),

        // --- HISTORICAL FEED ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('donorUid', isEqualTo: uid)
                .where('status', isEqualTo: 'Completed')
                .orderBy('postedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No completed donations yet. Post your first rescue!", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.check, color: Colors.green.shade800)),
                      title: Text(post['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("Type: ${post['foodState'] ?? 'N/A'} • ${post['category'] ?? 'N/A'}"),
                          Text("Fed approx ${post['quantity']} people", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      trailing: const Text("Delivered", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}