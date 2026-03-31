import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'donor_tabs/donor_home_tab.dart';
import 'donor_tabs/donor_history_tab.dart';
import 'donor_tabs/donor_profile_tab.dart';
import 'gamification/city_leaderboard_screen.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    if (currentUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (mounted) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>?;
          isLoading = false;
        });
      }
    }
  }

  void _showCitySearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DonorCitySearchSheet(
        currentUserUid: currentUser!.uid,
        userLat: userData?['latitude'],
        userLon: userData?['longitude'],
        onCitySelected: (String newShortAddress) {
          _fetchUserDetails();
        },

      ),

    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // EXACT ZOMATO STITCHING
    String building = userData?['exactAddress'] ?? '';
    String street = userData?['streetName'] ?? '';

    // If they filled out the profile, show building on top. Otherwise fallback to GPS City.
    String displayTopLine = building.isNotEmpty ? building : (userData?['city'] ?? 'Unknown Location');

    // If they filled out the profile, show street on bottom. Otherwise fallback to GPS Full Address.
    String displayBottomLine = street.isNotEmpty ? "$street, ${userData?['city'] ?? ''}" : (userData?['fullAddress'] ?? 'Tap to set your exact location');

    final List<Widget> pages = [
      DonorHomeTab(userData: userData!, uid: currentUser!.uid),
      DonorHistoryTab(uid: currentUser!.uid),
      DonorProfileTab(userData: userData!, uid: currentUser!.uid, onProfileUpdated: _fetchUserDetails),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
    appBar: AppBar(
    backgroundColor: Colors.white,
      elevation: 0,
      title: Text("Dashboard", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), // (Keep whatever title you already have here)

      // --- ADD THIS GOLD TROPHY BUTTON ---
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: IconButton(
            icon: const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
            tooltip: "City Leaderboard",
            onPressed: () {
              if (userData != null && currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CityLeaderboardScreen(
                      currentUserUid: currentUser!.uid,
                      userCity: userData?['city'] ?? 'Nadiad',
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    ),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.orange.shade700,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.storefront), label: "Post Food"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "Impact"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

class DonorCitySearchSheet extends StatefulWidget {
  final String currentUserUid;
  final double? userLat;
  final double? userLon;
  final Function(String) onCitySelected;

  const DonorCitySearchSheet({super.key, required this.currentUserUid, this.userLat, this.userLon, required this.onCitySelected});

  @override
  State<DonorCitySearchSheet> createState() => _DonorCitySearchSheetState();
}

class _DonorCitySearchSheetState extends State<DonorCitySearchSheet> {
  List<dynamic> searchResults = [];
  bool isSearching = false;
  final List<String> hintCities = ['Vadodara', 'Nadiad', 'Ahmedabad', 'Surat', 'Rajkot'];
  int currentHintIndex = 0;
  Timer? _hintTimer;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) setState(() => currentHintIndex = (currentHintIndex + 1) % hintCities.length);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (query.length < 3) {
      setState(() { searchResults = []; isSearching = false; });
      return;
    }
    setState(() => isSearching = true);

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        String latLonQuery = (widget.userLat != null && widget.userLon != null) ? "&lat=${widget.userLat}&lon=${widget.userLon}" : "";
        final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=8&countrycodes=in$latLonQuery');
        final response = await http.get(url, headers: {'User-Agent': 'FoodHopeApp/1.0'});
        if (response.statusCode == 200) {
          if (mounted) setState(() => searchResults = json.decode(response.body));
        }
      } catch (e) {
        print("Search Error: $e");
      } finally {
        if (mounted) setState(() => isSearching = false);
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => isSearching = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];

      String exactCity = place.locality ?? place.subAdministrativeArea ?? "Unknown City";
      String shortAddress = "${place.street ?? place.subLocality ?? exactCity}, $exactCity";
      String fullAddress = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}";
      fullAddress = fullAddress.replaceAll(RegExp(r'null, | ,'), '').trim();

      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update({
        'latitude': position.latitude, 'longitude': position.longitude, 'city': exactCity,
        'shortAddress': shortAddress, 'fullAddress': fullAddress,
      });

      widget.onCitySelected(shortAddress);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not fetch Location.")));
    } finally {
      if (mounted) setState(() => isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 40),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Business Location", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search '${hintCities[currentHintIndex]}'...",
                prefixIcon: const Icon(Icons.search, color: Colors.orange),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 15),
            ListTile(
              contentPadding: EdgeInsets.zero, leading: const Icon(Icons.my_location, color: Colors.red),
              title: const Text("Use current location", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: _useCurrentLocation,
            ),
            const Divider(thickness: 1),
            if (isSearching) const Center(child: CircularProgressIndicator(color: Colors.orange)),
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  var place = searchResults[index];
                  String displayName = place['display_name'] ?? '';
                  String exactCity = place['address']?['city'] ?? place['address']?['town'] ?? place['address']?['county'] ?? 'Unknown';
                  List<String> addressParts = displayName.split(', ');
                  String primaryText = addressParts.isNotEmpty ? addressParts[0] : exactCity;
                  String secondaryText = addressParts.length > 1 ? addressParts.sublist(1).join(', ') : displayName;

                  return ListTile(
                    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                    title: Text(primaryText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(secondaryText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update({
                        'city': exactCity, 'shortAddress': "$primaryText, $exactCity", 'fullAddress': displayName,
                        'latitude': double.parse(place['lat']), 'longitude': double.parse(place['lon']),
                      });
                      widget.onCitySelected(primaryText);
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location saved!")));
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}