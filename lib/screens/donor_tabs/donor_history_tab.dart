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
          padding: EdgeInsets.all(16.0),
          child: Text("Total Impact 🌍", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
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
                      leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.check, color: Colors.green.shade800)),
                      title: Text(post['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Fed approx ${post['quantity']} people"),
                      trailing: const Text("Rescued", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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