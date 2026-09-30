import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'donor_tabs/donor_home_tab.dart';
import 'donor_tabs/donor_history_tab.dart';
import 'donor_tabs/donor_profile_tab.dart';
import 'gamification/city_leaderboard_screen.dart';
import 'gamification/squads_hub_screen.dart';
import 'admin_dashboard.dart';
import '../services/notification_service.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _startStatusListener();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _startStatusListener() {
    _statusSubscription = FirebaseFirestore.instance
        .collection('donations')
        .where('donorUid', isEqualTo: currentUser?.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>;
          String status = data['status'];
          String food = data['foodItem'] ?? "Food";

          // Notify Donor on every important status change
          if (status == 'Accepted') {
            NotificationService.showRescueNotification(
              title: "💓 RESCUE ACCEPTED!",
              body: "A volunteer is on the way to pick up your $food!",
            );
          } else if (status == 'Picked Up') {
            NotificationService.showRescueNotification(
              title: "🚀 FOOD PICKED UP",
              body: "Your $food is now with the volunteer and heading to a hub!",
            );
          } else if (status == 'Delivered') {
            NotificationService.showRescueNotification(
              title: "🏆 RESCUE COMPLETED",
              body: "Your $food has been successfully delivered! You saved lives today.",
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
        if (!snapshot.hasData || !snapshot.data!.exists) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final city = userData['city'] ?? 'Location';

        final List<Widget> pages = [
          DonorHomeTab(userData: userData, uid: currentUser!.uid),
          DonorHistoryTab(uid: currentUser!.uid),
          DonorProfileTab(userData: userData, uid: currentUser!.uid, onProfileUpdated: () {}),
        ];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.white, elevation: 0,
            title: Text(city, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            actions: [
              IconButton(icon: const Icon(Icons.groups, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadsHubScreen(userData: userData, uid: currentUser!.uid)))),
              if (userData['isAdmin'] == true) IconButton(icon: const Icon(Icons.admin_panel_settings, color: Colors.red), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard()))),
              IconButton(icon: const Icon(Icons.emoji_events, color: Colors.amber), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityLeaderboardScreen(currentUserUid: currentUser!.uid, userCity: city, userRole: 'Donor')))),
            ],
          ),
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            selectedItemColor: Colors.orange.shade700,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.add_box), label: "Post"),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        );
      },
    );
  }
}
