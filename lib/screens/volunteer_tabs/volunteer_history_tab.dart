import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerHistoryTab extends StatelessWidget {
  final String uid;

  const VolunteerHistoryTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Your Impact 🏆", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('volunteerUid', isEqualTo: uid)
                .where('status', isEqualTo: 'Completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("You haven't completed any deliveries yet.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index];
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.check, color: Colors.green.shade800)),
                      title: Text(postData['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("From: ${postData['businessName']}"),
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