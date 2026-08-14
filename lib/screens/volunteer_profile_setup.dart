import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'volunteer_dashboard.dart';

class VolunteerProfileSetup extends StatefulWidget {
  const VolunteerProfileSetup({super.key});

  @override
  State<VolunteerProfileSetup> createState() => _VolunteerProfileSetupState();
}

class _VolunteerProfileSetupState extends State<VolunteerProfileSetup> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController vehicleController = TextEditingController();
  
  String _base64Image = '';
  bool isLoading = false;
  String currentCity = "Fetching...";

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        setState(() => currentCity = placemarks[0].locality ?? "Unknown City");
      }
    } catch (e) {
      setState(() => currentCity = "Location Error");
    }
  }

  Future<void> saveProfile() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) return;
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': nameController.text.trim(),
        'contact': phoneController.text.trim(),
        'vehicleType': vehicleController.text.trim(),
        'profileImageUrl': _base64Image,
        'city': currentCity,
        'isProfileComplete': true,
        'rankScore': 0,
        'impactPoints': 0,
        'trustScore': 100,
        'isAdmin': false,
        'deliveriesMade': 0,
      });

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerDashboard()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Volunteer Setup")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
            TextField(controller: vehicleController, decoration: const InputDecoration(labelText: "Vehicle (Bike/Car)")),
            const SizedBox(height: 20),
            Text("Detected City: $currentCity"),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: isLoading ? null : saveProfile, child: const Text("Complete Setup"))
          ],
        ),
      ),
    );
  }
}
