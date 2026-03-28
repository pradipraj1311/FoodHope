import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import 'ngo_tabs/ngo_home_tab.dart';
import 'ngo_tabs/ngo_history_tab.dart';
import 'ngo_tabs/ngo_profile_tab.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
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
      builder: (context) => NgoCitySearchSheet(
        currentUserUid: currentUser!.uid,
        userLat: userData?['latitude'],
        userLon: userData?['longitude'],
        // INSTANT LOCATION UPDATE: Pass a map containing new location data
        onCitySelected: (Map<String, dynamic> newLocationData) {
          if (mounted) {
            setState(() {
              // Immediately update the local userData so the UI refreshes instantly
              if (userData != null) {
                userData!['city'] = newLocationData['city'];
                userData!['shortAddress'] = newLocationData['shortAddress'];
                userData!['fullAddress'] = newLocationData['fullAddress'];
                // We leave Building Name/StreetName to be set in profile edit
              }
            });
          }
          // Also fetch full user details in background just to be sure
          _fetchUserDetails();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.teal)));

    // STRICT LOCATION FOR DISTRIBUTORS
    String building = userData?['exactAddress'] ?? '';
    String street = userData?['streetName'] ?? '';
    String displayTopLine = building.isNotEmpty ? building : (userData?['city'] ?? 'Set Exact Location');
    String displayBottomLine = street.isNotEmpty ? "$street, ${userData?['city'] ?? ''}" : (userData?['fullAddress'] ?? 'Tap to set your exact location');

    final List<Widget> pages = [
      NgoHomeTab(userData: userData!, uid: currentUser!.uid),
      NgoHistoryTab(uid: currentUser!.uid),
      NgoProfileTab(userData: userData!, uid: currentUser!.uid, onProfileUpdated: _fetchUserDetails),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        title: GestureDetector(
          onTap: _showCitySearchSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(displayTopLine, style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 24.0),
                child: Text(displayBottomLine, style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.teal.shade700,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.move_to_inbox), label: "Receiving"),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: "Impact"),
          BottomNavigationBarItem(icon: Icon(Icons.corporate_fare), label: "NGO Profile"),
        ],
      ),
    );
  }
}

class NgoCitySearchSheet extends StatefulWidget {
  final String currentUserUid;
  final double? userLat;
  final double? userLon;
  final Function(Map<String, dynamic>) onCitySelected;
  const NgoCitySearchSheet({super.key, required this.currentUserUid, this.userLat, this.userLon, required this.onCitySelected});
  @override State<NgoCitySearchSheet> createState() => _NgoCitySearchSheetState();
}

class _NgoCitySearchSheetState extends State<NgoCitySearchSheet> {
  List<dynamic> searchResults = [];
  bool isSearching = false;
  final List<String> hintCities = ['Nadiad', 'Ahmedabad', 'Surat'];
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

      Map<String, dynamic> updateData = {
        'latitude': position.latitude, 'longitude': position.longitude, 'city': exactCity,
        'shortAddress': shortAddress, 'fullAddress': fullAddress,
      };

      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update(updateData);

      widget.onCitySelected(updateData); // Call with update data
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
            const Text("Select Hub Location", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search '${hintCities[currentHintIndex]}'...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
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
            if (isSearching) const Center(child: CircularProgressIndicator(color: Colors.teal)),
            Expanded(
              child: ListView.builder(
                itemCount: searchResults.length,
                itemBuilder: (context, index) {
                  var place = searchResults[index];
                  String displayName = place['display_name'] ?? '';
                  String exactCity = place['address']?['city'] ?? place['address']?['town'] ?? place['address']?['county'] ?? 'Unknown City';
                  List<String> addressParts = displayName.split(', ');
                  String primaryText = addressParts.isNotEmpty ? addressParts[0] : exactCity;
                  String secondaryText = addressParts.length > 1 ? addressParts.sublist(1).join(', ') : displayName;

                  return ListTile(
                    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                    title: Text(primaryText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(secondaryText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    onTap: () async {
                      Map<String, dynamic> updateData = {
                        'city': exactCity, 'shortAddress': "$primaryText, $exactCity", 'fullAddress': displayName,
                        'latitude': double.parse(place['lat']), 'longitude': double.parse(place['lon']),
                      };

                      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update(updateData);
                      widget.onCitySelected(updateData); // Call with update data
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