import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../landing_screen.dart';
import '../gamification/impact_wrapped_screen.dart';
import '../gamification/city_leaderboard_screen.dart';
import '../gamification/squads_hub_screen.dart';
import 'dart:convert';

class VolunteerProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  final VoidCallback onProfileUpdated;

  const VolunteerProfileTab({super.key, required this.userData, required this.uid, required this.onProfileUpdated});

  @override
  State<VolunteerProfileTab> createState() => _VolunteerProfileTabState();
}

class _VolunteerProfileTabState extends State<VolunteerProfileTab> {
  bool isUploading = false;

  void _showCertificate() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.shade700, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber.shade800, size: 80),
              const SizedBox(height: 20),
              const Text("CERTIFICATE OF HONOR", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const Text("This is to certify that", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
              const SizedBox(height: 15),
              Text(widget.userData['name']?.toUpperCase() ?? 'HERO', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              const Divider(indent: 40, endIndent: 40, height: 30, thickness: 2),
              Text(
                "Has successfully completed ${widget.userData['deliveriesMade'] ?? 0} rescues and earned ${widget.userData['rankScore'] ?? 0} impact points on FoodHope.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const TextStyle(fontWeight: FontWeight.bold)), const Text("Date", style: TextStyle(fontSize: 10))]),
                  Icon(Icons.verified, color: Colors.green.shade700, size: 40),
                ],
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      int rescues = widget.userData['deliveriesMade'] ?? 0;
                      Share.share("I am honored to receive the Hunger Hero Certificate from FoodHope for completing $rescues food rescues! 💓 Join our mission: https://foodhope.app");
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text("SHARE"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showEditProfile() {
    TextEditingController nameController = TextEditingController(text: widget.userData['name']);
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact'] ?? '');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Profile", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                    'name': nameController.text.trim(),
                    'contact': phoneController.text.trim(),
                  });
                  widget.onProfileUpdated();
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _logout() async {
    bool confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Logout"), content: const Text("Exit business account?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes", style: TextStyle(color: Colors.red)))])) ?? false;
    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LandingScreen()), (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int rescues = widget.userData['deliveriesMade'] ?? 0;
    int points = widget.userData['rankScore'] ?? 0;
    String city = widget.userData['city'] ?? 'Nadiad';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.userData['name'] ?? 'Hero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(city, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.green), onPressed: _showEditProfile),
                IconButton(icon: const Icon(Icons.groups, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadsHubScreen(userData: widget.userData, uid: widget.uid)))),
                IconButton(icon: const Icon(Icons.emoji_events, color: Colors.amber), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityLeaderboardScreen(currentUserUid: widget.uid, userCity: city, userRole: 'Volunteer')))),
              ],
            )
          ],
        ),

        const SizedBox(height: 25),
        
        ElevatedButton.icon(
          onPressed: _showCertificate,
          icon: const Icon(Icons.card_membership),
          label: const Text("VIEW HONORARY CERTIFICATE"),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
        ),

        const SizedBox(height: 30),
        const Text("HONORARY BADGES 🎖️", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: [
            if (rescues >= 1) _badge("Bronze"),
            if (rescues >= 10) _badge("Silver"),
            if (rescues >= 50) _badge("Gold"),
          ],
        ),
        
        const SizedBox(height: 40),
        SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout), label: const Text("LOGOUT")))
      ],
    );
  }

  Widget _badge(String type) => Chip(avatar: const Icon(Icons.workspace_premium, size: 16), label: Text("$type Hero"));
}
