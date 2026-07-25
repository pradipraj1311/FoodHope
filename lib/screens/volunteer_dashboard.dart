import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'volunteer_tabs/volunteer_home_tab.dart';
import 'volunteer_tabs/volunteer_history_tab.dart';
import 'volunteer_tabs/volunteer_profile_tab.dart';
import 'gamification/city_leaderboard_screen.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

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

        String building = userData['exactAddress'] ?? '';
        String street = userData['streetName'] ?? '';
        String displayTopLine = building.isNotEmpty ? building : (userData['city'] ?? 'Set Location');
        String displayBottomLine = street.isNotEmpty ? "$street, ${userData['city'] ?? ''}" : (userData['fullAddress'] ?? 'Tap to set location');

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
            automaticallyImplyLeading: false, // REMOVED BACK ARROW
            title: GestureDetector(
              onTap: () => _showCitySearchSheet(userData),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 22, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(displayTopLine, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold)),
                      const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black87),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 26.0),
                    child: Text(displayBottomLine, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CityLeaderboardScreen(currentUserUid: currentUser!.uid, userCity: userData['city'] ?? 'All'))),
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

  void _showCitySearchSheet(Map<String, dynamic> userData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => VolunteerCitySearchSheet(
        currentUserUid: currentUser!.uid,
        userLat: (userData['latitude'] ?? 0.0).toDouble(),
        userLon: (userData['longitude'] ?? 0.0).toDouble(),
      ),
    );
  }
}

class VolunteerCitySearchSheet extends StatefulWidget {
  final String currentUserUid;
  final double? userLat;
  final double? userLon;

  const VolunteerCitySearchSheet({super.key, required this.currentUserUid, this.userLat, this.userLon});

  @override
  State<VolunteerCitySearchSheet> createState() => _VolunteerCitySearchSheetState();
}

class _VolunteerCitySearchSheetState extends State<VolunteerCitySearchSheet> {
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
      } catch (e) {
        print(e);
      } finally {
        if (mounted) setState(() => isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Search Region", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          TextField(
            decoration: const InputDecoration(hintText: "Enter Road or Society Name...", prefixIcon: Icon(Icons.search, color: Colors.green)),
            onChanged: _onSearchChanged,
          ),
          if (isSearching) const LinearProgressIndicator(color: Colors.green),
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                var place = searchResults[index];
                return ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(place['display_name'], style: const TextStyle(fontSize: 13)),
                  onTap: () async {
                    await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update({
                      'fullAddress': place['display_name'],
                      'city': place['address']['city'] ?? place['address']['town'] ?? 'City',
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
