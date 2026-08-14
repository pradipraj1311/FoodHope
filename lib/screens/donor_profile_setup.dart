import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'donor_dashboard.dart';

class DonorProfileSetup extends StatefulWidget {
  const DonorProfileSetup({super.key});

  @override
  State<DonorProfileSetup> createState() => _DonorProfileSetupState();
}

class _DonorProfileSetupState extends State<DonorProfileSetup> {
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController contactNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController buildingController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  
  String selectedDonorType = 'Restaurant';
  final List<String> donorTypes = ['Restaurant', 'Hotel', 'Hostel Mess', 'Event / Wedding', 'Supermarket', 'Individual / Other'];

  String _base64Image = '';
  bool isLoading = false;
  String currentCity = "Fetching...";

  @override
  void initState() {
    super.initState();
    _autoFetchLocation();
  }

  @override
  void dispose() {
    businessNameController.dispose();
    contactNameController.dispose();
    phoneController.dispose();
    buildingController.dispose();
    streetController.dispose();
    super.dispose();
  }

  Future<void> _autoFetchLocation() async {
    setState(() => currentCity = "Locating...");
    try {
      Position? position = await _determinePosition();
      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          setState(() {
            currentCity = placemarks[0].locality ?? "Unknown City";
            if (streetController.text.isEmpty) streetController.text = placemarks[0].street ?? "";
          });
        }
      }
    } catch (e) {
      setState(() => currentCity = "Location Error");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      setState(() => _base64Image = base64Encode(imageBytes));
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> saveProfile() async {
    if (businessNameController.text.isEmpty || contactNameController.text.isEmpty || phoneController.text.isEmpty || buildingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all mandatory fields!")));
      return;
    }
    setState(() => isLoading = true);

    try {
      Position? position = await _determinePosition();
      String city = currentCity;
      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          city = placemarks[0].locality ?? currentCity;
        }
      }

      String uid = FirebaseAuth.instance.currentUser!.uid;

      // SENIOR DEV FIX: Always set rankScore and isAdmin to ensure leaderboard works
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': _base64Image,
        'businessName': businessNameController.text.trim(),
        'primaryContactName': contactNameController.text.trim(),
        'contact': phoneController.text.trim(),
        'exactAddress': buildingController.text.trim(),
        'streetName': streetController.text.trim(),
        'donorType': selectedDonorType,
        'latitude': position?.latitude ?? 0.0,
        'longitude': position?.longitude ?? 0.0,
        'city': city,
        'isProfileComplete': true,
        'rankScore': 0,
        'impactPoints': 0,
        'donationsMade': 0,
        'isAdmin': false,
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DonorDashboard()));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Donor Setup"), automaticallyImplyLeading: false, elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.orange.shade50,
                backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                child: _base64Image.isEmpty ? const Icon(Icons.add_a_photo, size: 40, color: Colors.orange) : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: businessNameController, decoration: const InputDecoration(labelText: "Business Name*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.business))),
            const SizedBox(height: 15),
            TextField(controller: contactNameController, decoration: const InputDecoration(labelText: "Contact Person*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 15),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
            const SizedBox(height: 15),
            
            DropdownButtonFormField<String>(
              value: selectedDonorType,
              decoration: const InputDecoration(labelText: "Business Category*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
              items: donorTypes.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedDonorType = val!),
            ),
            
            const SizedBox(height: 15),
            TextField(controller: buildingController, decoration: const InputDecoration(labelText: "Building/Hostel Name*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home))),
            const SizedBox(height: 15),
            TextField(controller: streetController, decoration: const InputDecoration(labelText: "Street / Road*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map))),
            
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 5),
                Text("City: $currentCity", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                const Spacer(),
                TextButton(onPressed: _autoFetchLocation, child: const Text("Refresh GPS"))
              ],
            ),
            
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("FINISH SETUP ✨", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
