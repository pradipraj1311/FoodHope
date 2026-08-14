import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'ngo_tabs/ngo_home_tab.dart';
import 'ngo_tabs/ngo_history_tab.dart';
import 'ngo_tabs/ngo_profile_tab.dart';
import 'gamification/city_leaderboard_screen.dart';
import 'admin_login_screen.dart';
import '../services/notification_service.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  StreamSubscription? _incomingSubscription;

  @override
  void initState() {
    super.initState();
    _startIncomingListener();
  }

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    super.dispose();
  }

  void _startIncomingListener() {
    // Notify NGO when a volunteer is assigned to them
    _incomingSubscription = FirebaseFirestore.instance
        .collection('donations')
        .where('selectedNgoId', isEqualTo: currentUser?.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added || (change.type == DocumentChangeType.modified && change.doc['status'] == 'NGO Requested')) {
           NotificationService.showRescueNotification(
            title: "💓 INCOMING RESCUE",
            body: "A volunteer is bringing food to your hub!",
          );
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
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("NGO data not found")));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;

        final List<Widget> pages = [
          NgoHomeTab(userData: userData, uid: currentUser!.uid),
          NgoHistoryTab(uid: currentUser!.uid),
          NgoProfileTab(userData: userData, uid: currentUser!.uid, onProfileUpdated: () {}),
        ];

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            foregroundColor: Colors.black87,
            automaticallyImplyLeading: false,
            title: const Text("NGO Hub", style: TextStyle(fontWeight: FontWeight.bold)),
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
                  userRole: 'NGO',
                ))),
              )
            ],
          ),
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.teal.shade700,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.move_to_inbox), label: "Receiving"),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Impact"),
              BottomNavigationBarItem(icon: Icon(Icons.corporate_fare), label: "Hub Profile"),
            ],
          ),
        );
      },
    );
  }
}
