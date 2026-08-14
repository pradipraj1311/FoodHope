import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

import 'volunteer_tabs/volunteer_home_tab.dart';
import 'volunteer_tabs/volunteer_history_tab.dart';
import 'volunteer_tabs/volunteer_profile_tab.dart';
import 'gamification/city_leaderboard_screen.dart';
import 'admin_login_screen.dart';
import '../services/notification_service.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  StreamSubscription? _donationSubscription;
  final DateTime _appStartTime = DateTime.now(); // Used to filter OLD rescues

  @override
  void initState() {
    super.initState();
    _startRescueListener();
  }

  @override
  void dispose() {
    _donationSubscription?.cancel();
    super.dispose();
  }

  void _startRescueListener() {
    _donationSubscription = FirebaseFirestore.instance
        .collection('donations')
        .where('status', isEqualTo: 'Available')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>;
          Timestamp? postedAt = data['postedAt'] as Timestamp?;
          
          // Only notify if it's truly NEW (posted after app opened)
          if (postedAt != null && postedAt.toDate().isAfter(_appStartTime)) {
            NotificationService.showRescueNotification(
              title: "💓 NEW RESCUE AVAILABLE!",
              body: "A new food donation has been posted in your city. Rescue it now!",
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("Volunteer data not found")));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        final List<Widget> pages = [
          VolunteerHomeTab(userData: userData, uid: currentUser!.uid),
          VolunteerHistoryTab(uid: currentUser!.uid),
          VolunteerProfileTab(userData: userData, uid: currentUser!.uid, onProfileUpdated: () {}),
        ];

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            automaticallyImplyLeading: false,
            title: const Text("FoodHope Volunteer", style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (userData['isAdmin'] == true)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.blueGrey),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen())),
                ),
              IconButton(
                icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityLeaderboardScreen(
                  currentUserUid: currentUser!.uid, 
                  userCity: userData['city'] ?? 'All',
                  userRole: 'Volunteer',
                ))),
              )
            ],
          ),
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.green.shade700,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.electric_moped), label: "Feed"),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        );
      },
    );
  }
}
