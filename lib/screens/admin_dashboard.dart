import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> _updateUserStatus(String uid, String status) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'verificationStatus': status,
        'isVerified': status == 'approved',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User status updated to $status")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error updating user: $e")));
    }
  }

  Future<void> _toggleSuspension(String uid, bool isSuspended) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isSuspended': isSuspended,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isSuspended ? "User blocked" : "User unblocked")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error toggling suspension: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("CONTROL CENTER", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text("Access Denied: Please update Firestore Rules in Firebase Console.\nError: ${snapshot.error}", 
                style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found in system.", style: TextStyle(color: Colors.white38)));
          }

          var allUsers = snapshot.data!.docs;
          int volunteers = allUsers.where((d) => (d.data() as Map)['role'] == 'Volunteer').length;
          int ngos = allUsers.where((d) => (d.data() as Map)['role'] == 'NGO').length;
          int donors = allUsers.where((d) => (d.data() as Map)['role'] == 'Donor').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("LIVE SYSTEM METRICS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 20),
                
                Row(
                  children: [
                    _buildStatCard("Total Users", "${allUsers.length}", Icons.people, Colors.blue),
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

                const SizedBox(height: 40),
                const Text("VERIFICATION QUEUE", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 15),

                // Pending List
                ...allUsers.where((d) => (d.data() as Map)['verificationStatus'] == 'pending').map((doc) {
                  var user = doc.data() as Map<String, dynamic>;
                  String proof = user['verificationProofUrl'] ?? '';
                  return _buildUserActionCard(doc.id, user, proof, true);
                }).toList(),

                if (allUsers.where((d) => (d.data() as Map)['verificationStatus'] == 'pending').isEmpty)
                  const Text("No pending requests.", style: TextStyle(color: Colors.white24, fontSize: 12)),

                const SizedBox(height: 40),
                const Text("COMMUNITY MANAGEMENT", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 15),

                // Active List
                ...allUsers.where((d) => (d.data() as Map)['verificationStatus'] != 'pending').map((doc) {
                  var user = doc.data() as Map<String, dynamic>;
                  return _buildUserActionCard(doc.id, user, '', false);
                }).toList(),
                
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserActionCard(String uid, Map<String, dynamic> user, String proof, bool isPending) {
    bool isSuspended = user['isSuspended'] ?? false;
    int meals = user['deliveriesMade'] ?? user['donationsMade'] ?? user['deliveriesReceived'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSuspended ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(
                user['role'] == 'Volunteer' ? Icons.person : 
                user['role'] == 'NGO' ? Icons.corporate_fare : Icons.store,
                color: Colors.white70, size: 20,
              ),
            ),
            title: Text(user['name'] ?? user['organizationName'] ?? user['businessName'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text("${user['role']} • ${user['rankScore'] ?? 0} pts • $meals Meals", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: proof.isNotEmpty ? 
              GestureDetector(
                onTap: () => _showImageDialog(proof),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(base64Decode(proof), width: 50, height: 50, fit: BoxFit.cover),
                ),
              ) : null,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                TextButton(onPressed: () => _updateUserStatus(uid, 'rejected'), child: const Text("REJECT", style: TextStyle(color: Colors.redAccent))),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: () => _updateUserStatus(uid, 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), child: const Text("APPROVE")),
              ] else ...[
                TextButton(
                  onPressed: () => _toggleSuspension(uid, !isSuspended), 
                  child: Text(isSuspended ? "ACTIVATE USER" : "BLOCK USER", style: TextStyle(color: isSuspended ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold))
                ),
              ]
            ],
          )
        ],
      ),
    );
  }

  void _showImageDialog(String base64) {
    showDialog(context: context, builder: (context) => Dialog(backgroundColor: Colors.black, child: Column(mainAxisSize: MainAxisSize.min, children: [Image.memory(base64Decode(base64)), TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE", style: TextStyle(color: Colors.white)))])));
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
