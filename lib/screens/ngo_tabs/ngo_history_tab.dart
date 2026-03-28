import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NgoHistoryTab extends StatelessWidget {
  final String uid;

  const NgoHistoryTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
          child: Text("Receiving Analytics 📊", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal)),
        ),

        // --- REAL TIME ANALYTICS HEADER ---
        StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.teal)));
              var userData = userSnapshot.data!.data() as Map<String, dynamic>;

              int totalReceived = userData['totalDeliveriesReceived'] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  color: Colors.teal.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Total Deliveries Received", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 5),
                            Text("$totalReceived Deliveries", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal.shade900)),
                          ],
                        ),
                        Icon(Icons.inventory_2, size: 40, color: Colors.teal.shade200),
                      ],
                    ),
                  ),
                ),
              );
            }
        ),

        const Padding(
          padding: EdgeInsets.only(left: 16.0, top: 20, bottom: 8),
          child: Text("Past Receipts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),

        // --- HISTORICAL FEED ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Listens for completed deliveries assigned to this NGO
            stream: FirebaseFirestore.instance.collection('donations')
                .where('selectedNgoId', isEqualTo: uid)
                .where('status', isEqualTo: 'Completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No deliveries received yet.", style: TextStyle(color: Colors.grey)));

              // Client-side sorting to prevent index flickering
              var docs = snapshot.data!.docs;
              docs.sort((a, b) {
                Timestamp timeA = (a.data() as Map<String, dynamic>)['dropoffTime'] as Timestamp? ?? Timestamp.now();
                Timestamp timeB = (b.data() as Map<String, dynamic>)['dropoffTime'] as Timestamp? ?? Timestamp.now();
                return timeB.compareTo(timeA);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var post = docs[index].data() as Map<String, dynamic>;

                  // Format the dropoff time beautifully
                  String formattedTime = "Unknown Time";
                  if (post['dropoffTime'] != null) {
                    DateTime dt = (post['dropoffTime'] as Timestamp).toDate();
                    formattedTime = DateFormat('MMM d, h:mm a').format(dt);
                  }

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(Icons.check_circle, color: Colors.teal.shade700)),
                      title: Text(post['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text("From: ${post['businessName'] ?? 'Donor'}"),
                          Text("Delivered by: ${post['volunteerName'] ?? 'Volunteer'}"),
                          const SizedBox(height: 4),
                          Text("Feeds ${post['quantity']} • $formattedTime", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
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