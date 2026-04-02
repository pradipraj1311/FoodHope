import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NgoHistoryTab extends StatelessWidget {
  final String uid;
  const NgoHistoryTab({super.key, required this.uid});

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- TOP STATS DASHBOARD ---
        StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('selectedNgoId', isEqualTo: uid)
                .where('status', isEqualTo: 'Completed')
                .snapshots(),
            builder: (context, snapshot) {
              int totalMeals = 0;
              int totalReceipts = 0;
              int foodValue = 0;

              if (snapshot.hasData) {
                totalReceipts = snapshot.data!.docs.length;
                for (var doc in snapshot.data!.docs) {
                  totalMeals += (doc['quantity'] as num?)?.toInt() ?? 0;
                }
                foodValue = totalMeals * 50; // ₹50 per meal value
              }

              return Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    _buildStatCard("Meals\nDistributed", totalMeals.toString(), Icons.restaurant, Colors.orange.shade700),
                    _buildStatCard("Food Worth\nReceived", "₹$foodValue", Icons.currency_rupee, Colors.green.shade700),
                    _buildStatCard("Deliveries\nReceived", totalReceipts.toString(), Icons.inventory_2, Colors.blue.shade700),
                  ],
                ),
              );
            }
        ),

        const Divider(height: 1, thickness: 1),

        // --- HISTORY TIMELINE ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('selectedNgoId', isEqualTo: uid)
                .where('status', isEqualTo: 'Completed')
                .orderBy('dropoffTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text("Receiving history is empty.", style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  DateTime date = (data['dropoffTime'] as Timestamp?)?.toDate() ?? DateTime.now();
                  String formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formattedDate, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, size: 14, color: Colors.teal.shade700),
                                    const SizedBox(width: 4),
                                    Text("Received Successfully", style: TextStyle(color: Colors.teal.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const Divider(),
                          Text("📦 ${data['foodItem']}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Feeds approx ${data['quantity']} people", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                const Icon(Icons.delivery_dining, color: Colors.blue, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Delivered by Volunteer:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                      Text(data['volunteerName'] ?? 'Volunteer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
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