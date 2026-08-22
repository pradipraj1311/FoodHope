import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Future<void> _updateStatus(String uid, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'verificationStatus': status,
      'isVerified': status == 'approved',
    });
  }

  Future<void> _deleteUser(String uid) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("TERMINATE ACCOUNT?"),
        content: const Text("WARNING: This will permanently wipe this user and all their records from the entire system. This action is irreversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("PURGE ALL DATA", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      )
    ) ?? false;
    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User account terminated.")));
    }
  }

  Future<void> _toggleSuspend(String uid, bool current) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'isSuspended': !current});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text("SYSTEM AUTHORITY", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData) return const Center(child: Text("No data found.", style: TextStyle(color: Colors.white24)));
          
          var users = snapshot.data!.docs;
          
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').snapshots(),
            builder: (context, donationSnap) {
              int totalMeals = 0;
              if (donationSnap.hasData) {
                for (var d in donationSnap.data!.docs) {
                  var data = d.data() as Map;
                  if (data['status'] == 'Delivered' || data['status'] == 'Picked Up' || data['status'] == 'Accepted') {
                    totalMeals += (data['quantity'] ?? 0) as int;
                  }
                }
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      _statCard("TOTAL USERS", "${users.length}", Icons.people, Colors.blue),
                      const SizedBox(width: 10),
                      _statCard("MEALS SAVED", "$totalMeals", Icons.fastfood, Colors.greenAccent),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text("VERIFICATION QUEUE", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ...users.where((u) => (u.data() as Map)['verificationStatus'] == 'pending').map((u) => _buildManageCard(u, true)),
                  const SizedBox(height: 30),
                  const Text("MANAGE COMMUNITY", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                  ...users.where((u) => (u.data() as Map)['verificationStatus'] != 'pending').map((u) => _buildManageCard(u, false)),
                ],
              );
            }
          );
        },
      ),
    );
  }

  Widget _buildManageCard(DocumentSnapshot doc, bool isPending) {
    var user = doc.data() as Map<String, dynamic>;
    bool suspended = user['isSuspended'] ?? false;
    String livePhoto = user['livePhotoUrl'] ?? '';
    String social = user['socialMediaLink'] ?? '';
    String proof = user['verificationProofUrl'] ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: suspended ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: suspended ? Colors.red.withOpacity(0.3) : Colors.white10)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['name'] ?? user['businessName'] ?? user['organizationName'] ?? 'Unknown', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  Text("${user['role']} • ${user['city']}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
              IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: () => _deleteUser(doc.id)),
            ],
          ),
          if (social.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: InkWell(onTap: () => launchUrl(Uri.parse(social)), child: Text("🔗 Social: $social", style: const TextStyle(color: Colors.blueAccent, fontSize: 10, decoration: TextDecoration.underline)))),
          const SizedBox(height: 10),
          Row(
            children: [
              if (livePhoto.isNotEmpty) Expanded(child: _imgPreview(livePhoto, "LIVE IDENTITY")),
              if (proof.isNotEmpty) const SizedBox(width: 8),
              if (proof.isNotEmpty) Expanded(child: _imgPreview(proof, "DOC PROOF")),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isPending) ...[
                TextButton(onPressed: () => _updateStatus(doc.id, 'rejected'), child: const Text("REJECT", style: TextStyle(color: Colors.redAccent))),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: () => _updateStatus(doc.id, 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent), child: const Text("APPROVE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
              ] else ...[
                ElevatedButton(onPressed: () => _toggleSuspend(doc.id, suspended), style: ElevatedButton.styleFrom(backgroundColor: suspended ? Colors.green : Colors.orange), child: Text(suspended ? "ACTIVATE USER" : "SUSPEND USER", style: const TextStyle(fontSize: 10, color: Colors.black, fontWeight: FontWeight.bold))),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _imgPreview(String b64, String label) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.white24, fontSize: 8)), const SizedBox(height: 4), GestureDetector(onTap: () => showDialog(context: context, builder: (ctx) => Dialog(backgroundColor: Colors.black, child: Column(mainAxisSize: MainAxisSize.min, children: [AppBar(title: Text(label), backgroundColor: Colors.transparent), Image.memory(base64Decode(b64)), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE", style: TextStyle(color: Colors.white)))]))), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(base64Decode(b64), height: 80, width: double.infinity, fit: BoxFit.cover)))]);
  }

  Widget _statCard(String t, String v, IconData i, Color c) {
    return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(i, color: c, size: 20), const SizedBox(height: 10), Text(v, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), Text(t, style: const TextStyle(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold))])));
  }
}
