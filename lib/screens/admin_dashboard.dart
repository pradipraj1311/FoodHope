import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _updateUserStatus(String uid, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'verificationStatus': status, // 'approved', 'rejected', 'pending'
      'isVerified': status == 'approved',
    });
  }

  Future<void> _toggleSuspension(String uid, bool isSuspended) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isSuspended': isSuspended,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: const Text("ADMIN CONTROL CENTER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("System Overview", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Stats Row
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                int totalUsers = snapshot.data!.docs.length;
                int volunteers = snapshot.data!.docs.where((d) => (d.data() as Map)['role'] == 'Volunteer').length;
                int ngos = snapshot.data!.docs.where((d) => (d.data() as Map)['role'] == 'NGO').length;
                int donors = snapshot.data!.docs.where((d) => (d.data() as Map)['role'] == 'Donor').length;

                return Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCard("Total Users", "$totalUsers", Icons.people, Colors.blue),
                        const SizedBox(width: 15),
                        _buildStatCard("Volunteers", "$volunteers", Icons.directions_bike, Colors.green),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        _buildStatCard("Donors", "$donors", Icons.restaurant, Colors.orange),
                        const SizedBox(width: 15),
                        _buildStatCard("NGO Hubs", "$ngos", Icons.corporate_fare, Colors.teal),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),
            const Text("Pending Verifications", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // Pending Verification List
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users')
                  .where('verificationStatus', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                var pendingUsers = snapshot.data!.docs;
                if (pendingUsers.isEmpty) return const Text("No pending verifications", style: TextStyle(color: Colors.white38));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: pendingUsers.length,
                  itemBuilder: (context, index) {
                    var user = pendingUsers[index].data() as Map<String, dynamic>;
                    String uid = pendingUsers[index].id;
                    String proof = user['verificationProofUrl'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(user['name'] ?? user['organizationName'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text("${user['role']} • ${user['city']}", style: const TextStyle(color: Colors.white38)),
                            trailing: proof.isNotEmpty ? 
                              GestureDetector(
                                onTap: () => _showImageDialog(context, proof),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(base64Decode(proof), width: 50, height: 50, fit: BoxFit.cover),
                                ),
                              ) : null,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => _updateUserStatus(uid, 'rejected'),
                                child: const Text("Reject", style: TextStyle(color: Colors.redAccent)),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () => _updateUserStatus(uid, 'approved'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
                                child: const Text("Approve"),
                              ),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 30),
            const Text("All Active Users", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // User List with Rank, Served Meals & Suspension
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').orderBy('rankScore', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                var users = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var user = users[index].data() as Map<String, dynamic>;
                    String uid = users[index].id;
                    String name = user['name'] ?? user['businessName'] ?? user['organizationName'] ?? 'Unknown';
                    bool isSuspended = user['isSuspended'] ?? false;
                    int meals = user['deliveriesMade'] ?? user['donationsMade'] ?? user['deliveriesReceived'] ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isSuspended ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.05), 
                        borderRadius: BorderRadius.circular(16)
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.white10,
                          child: Text("${index + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name, style: TextStyle(color: isSuspended ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("${user['role']} • ${user['rankScore'] ?? 0} pts", style: const TextStyle(color: Colors.white38)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("$meals", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                                const Text("MEALS", style: TextStyle(color: Colors.white24, fontSize: 9)),
                              ],
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: Icon(isSuspended ? Icons.play_arrow : Icons.block, color: isSuspended ? Colors.green : Colors.red),
                              onPressed: () => _toggleSuspension(uid, !isSuspended),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImageDialog(BuildContext context, String base64) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Image.memory(base64Decode(base64)),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
