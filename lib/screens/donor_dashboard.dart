import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
          if (data['status'] == 'Accepted') {
            NotificationService.showRescueNotification(
              title: "💓 RESCUE ACCEPTED!",
              body: "A volunteer is on the way to pick up your donation!",
            );
          }
        }
      }
    });
  }

  void _showCitySearchSheet(Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DonorCitySearchSheet(
        currentUserUid: currentUser!.uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.orange)));
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("User not found")));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String city = userData['city'] ?? 'Set Location';

        final List<Widget> pages = [
          DonorHomeTab(userData: userData, uid: currentUser!.uid),
          DonorHistoryTab(uid: currentUser!.uid),
          DonorProfileTab(userData: userData, uid: currentUser!.uid, onProfileUpdated: () {}),
        ];

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: GestureDetector(
              onTap: () => _showCitySearchSheet(userData),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      city, 
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black87),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.groups_outlined, color: Colors.blueAccent),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SquadsHubScreen(userData: userData, uid: currentUser!.uid))),
              ),
              if (userData['isAdmin'] == true)
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.blueGrey),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboard())),
                ),
              IconButton(
                icon: const Icon(Icons.emoji_events, color: Colors.amber),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityLeaderboardScreen(
                  currentUserUid: currentUser!.uid, 
                  userCity: city,
                  userRole: 'Donor',
                ))),
              )
            ],
          ),
          body: pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            selectedItemColor: Colors.orange.shade700,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.storefront), label: "Post Food"),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: "Impact"),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
            ],
          ),
        );
      },
    );
  }
}

class DonorCitySearchSheet extends StatefulWidget {
  final String currentUserUid;
  const DonorCitySearchSheet({super.key, required this.currentUserUid});
  @override State<DonorCitySearchSheet> createState() => _DonorCitySearchSheetState();
}

class _DonorCitySearchSheetState extends State<DonorCitySearchSheet> {
  List<dynamic> searchResults = [];
  bool isSearching = false;
  Timer? _debounceTimer;

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (query.length < 3) return;
    setState(() => isSearching = true);
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');
        final response = await http.get(url, headers: {'User-Agent': 'FoodHope/1.0'});
        if (response.statusCode == 200) {
          if (mounted) setState(() => searchResults = json.decode(response.body));
        }
      } catch (e) { debugPrint("$e"); } finally { if (mounted) setState(() => isSearching = false); }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(decoration: const InputDecoration(hintText: "Enter your city or area...", prefixIcon: Icon(Icons.search)), onChanged: _onSearchChanged),
          if (isSearching) const LinearProgressIndicator(),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                var place = searchResults[index];
                return ListTile(
                  title: Text(place['display_name'], style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update({
                      'city': place['address']['city'] ?? place['address']['town'] ?? place['address']['village'] ?? 'City',
                      'latitude': double.parse(place['lat']),
                      'longitude': double.parse(place['lon']),
                    });
                    if (mounted) Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
