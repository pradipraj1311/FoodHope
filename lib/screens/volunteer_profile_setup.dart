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
  
  String _base64Image = '';
  String _livePhoto = ''; // NEW: For Admin Verification
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

  Future<void> _pickImage(bool isLive) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: isLive ? ImageSource.camera : ImageSource.gallery, 
      imageQuality: 25
    );
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      setState(() {
        if (isLive) _livePhoto = base64Encode(imageBytes);
        else _base64Image = base64Encode(imageBytes);
      });
    }
  }

  Future<void> saveProfile() async {
    if (nameController.text.isEmpty || _livePhoto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Live Selfie are required!")));
      return;
    }
    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': nameController.text.trim(),
        'contact': phoneController.text.trim(),
        'profileImageUrl': _base64Image,
        'livePhotoUrl': _livePhoto,
        'city': currentCity,
        'isProfileComplete': true,
        'verificationStatus': 'pending', // Send to Admin Queue
        'isVerified': false,
        'rankScore': 0,
        'impactPoints': 0,
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
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Volunteer Setup"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _pickImage(false),
              child: CircleAvatar(
                radius: 50, backgroundColor: Colors.green.shade50,
                backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                child: _base64Image.isEmpty ? const Icon(Icons.add_a_photo, color: Colors.green) : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name*", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())),
            const SizedBox(height: 25),
            
            const Text("Live Verification (Selfie)*", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade200)),
                child: _livePhoto.isEmpty 
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_front, size: 40, color: Colors.green), Text("Take a Live Selfie")])
                  : ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(base64Decode(_livePhoto), fit: BoxFit.cover)),
              ),
            ),
            
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: isLoading ? null : saveProfile, 
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("FINISH SETUP", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
