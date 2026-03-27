import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'donor_dashboard.dart';

class NgoProfileSetup extends StatefulWidget {
  const NgoProfileSetup({super.key});

  @override
  State<NgoProfileSetup> createState() => _NgoProfileSetupState();
}

class _NgoProfileSetupState extends State<NgoProfileSetup> {
  final TextEditingController orgNameController = TextEditingController();

  // Dropdown States
  String selectedFoodCategory = 'Both Veg & Non-Veg';
  final List<String> foodCategories = ['Veg Only', 'Non-Veg Only', 'Both Veg & Non-Veg'];

  String selectedStorage = 'Dry Storage Only';
  final List<String> storageOptions = ['Dry Storage Only', 'Has Refrigerators', 'Has Freezers', 'Full Kitchen Setup'];

  String selectedCapacity = '50 - 200 people';
  final List<String> capacityOptions = ['10 - 50 people', '50 - 200 people', '200+ people'];

  String selectedReceiveTime = 'Anytime';
  final List<String> receiveTimes = ['Morning (8 AM - 12 PM)', 'Afternoon (12 PM - 4 PM)', 'Evening (4 PM - 8 PM)', 'Anytime'];

  bool isLoading = false;

  @override
  void dispose() {
    orgNameController.dispose();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
  Future<void> saveProfile() async {
    if (orgNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Organization Name.")));
      return;
    }
    setState(() => isLoading = true);

    try {
      Position? position = await _determinePosition();
      if (position == null) {
        setState(() => isLoading = false);
        return;
      }

      // NEW: Convert GPS to readable text
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      String city = place.locality ?? "Unknown City";
      String state = place.administrativeArea ?? "Unknown State";
      String country = place.country ?? "Unknown Country";

      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'organizationName': orgNameController.text.trim(),
        'foodCategory': selectedFoodCategory,
        'storageCapacity': selectedStorage,
        'feedingCapacity': selectedCapacity,
        'preferredReceiveTime': selectedReceiveTime,
        // NEW: Location details
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': city,
        'state': state,
        'country': country,
        'address': "${place.street}, $city",
        'isProfileComplete': true,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("NGO Profile Complete!")));
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("NGO Hub Setup"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(controller: orgNameController, decoration: const InputDecoration(labelText: "Organization Name*", border: OutlineInputBorder())),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedFoodCategory,
              decoration: const InputDecoration(labelText: "Accepted Food Category", border: OutlineInputBorder()),
              items: foodCategories.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedFoodCategory = val!),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedStorage,
              decoration: const InputDecoration(labelText: "Storage Capabilities", border: OutlineInputBorder()),
              items: storageOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedStorage = val!),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedCapacity,
              decoration: const InputDecoration(labelText: "Feeding Capacity", border: OutlineInputBorder()),
              items: capacityOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedCapacity = val!),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedReceiveTime,
              decoration: const InputDecoration(labelText: "Best Drop-off Time", border: OutlineInputBorder()),
              items: receiveTimes.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedReceiveTime = val!),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Location & Complete", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}