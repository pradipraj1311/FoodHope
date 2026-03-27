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

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
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
      builder: (context) => CitySearchSheet(
        currentUserUid: currentUser!.uid,
        userLat: userData?['latitude'], // Pass coordinates to bias the search!
        userLon: userData?['longitude'],
        onCitySelected: (String newShortAddress) {
          _fetchUserDetails(); // Refresh UI after saving
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // ZOMATO STYLE: City bold on top, full address subtle on bottom
    String displayCity = userData?['city'] ?? 'Unknown Location';
    String displayFullAddress = userData?['fullAddress'] ?? 'Tap to set your exact location';

    final List<Widget> pages = [
      VolunteerHomeTab(userData: userData!, uid: currentUser!.uid),
      VolunteerHistoryTab(uid: currentUser!.uid),
      VolunteerProfileTab(userData: userData!, uid: currentUser!.uid, onProfileUpdated: _fetchUserDetails),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: GestureDetector(
          onTap: _showCitySearchSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 22, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(displayCity, style: const TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.bold)),
                  const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.black87),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 26.0), // Aligns exactly under the text
                child: Text(displayFullAddress, style: TextStyle(color: Colors.grey.shade600, fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Feed"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// THE ZOMATO SEARCH WIDGET
// =========================================================================
class CitySearchSheet extends StatefulWidget {
  final String currentUserUid;
  final double? userLat;
  final double? userLon;
  final Function(String) onCitySelected;

  const CitySearchSheet({super.key, required this.currentUserUid, this.userLat, this.userLon, required this.onCitySelected});

  @override
  State<CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<CitySearchSheet> {
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
        // Appending lat and lon biases the OSM API to look for nearby places first!
        String latLonQuery = (widget.userLat != null && widget.userLon != null)
            ? "&lat=${widget.userLat}&lon=${widget.userLon}" : "";

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

      // Clean up string formatting
      fullAddress = fullAddress.replaceAll(RegExp(r'null, | ,'), '').trim();

      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': exactCity,
        'shortAddress': shortAddress,
        'fullAddress': fullAddress,
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
        height: MediaQuery.of(context).size.height * 0.85, // Makes it tall like Zomato
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select a location", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // Modern Search Field
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Search '${hintCities[currentHintIndex]}'...",
                prefixIcon: const Icon(Icons.search, color: Colors.green),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 15),

            // "Use Current Location" EXACTLY like the screenshot
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.my_location, color: Colors.red),
              title: const Text("Use current location", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: _useCurrentLocation,
            ),
            const Divider(thickness: 1),

            if (isSearching) const Center(child: CircularProgressIndicator(color: Colors.green)),

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
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                    title: Text(primaryText, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(secondaryText, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    onTap: () async {
                      await FirebaseFirestore.instance.collection('users').doc(widget.currentUserUid).update({
                        'city': exactCity,
                        'shortAddress': "$primaryText, $exactCity",
                        'fullAddress': displayName,
                        'latitude': double.parse(place['lat']),
                        'longitude': double.parse(place['lon']),
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