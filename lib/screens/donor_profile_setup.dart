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

  Future<void> _autoFetchLocation() async {
    setState(() => currentCity = "Locating...");
    try {
      Position? position = await _determinePosition();
      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          setState(() {
            currentCity = placemarks[0].locality ?? "Unknown City";
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
      setState(() {
        _base64Image = base64Encode(imageBytes);
      });
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
    if (businessNameController.text.isEmpty || contactNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Contact are required!")));
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

      // Senior Developer Logic: Donors are auto-verified as a mark of respect for their contribution.
      // We do not ask for live photos or social documents from donors.
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': _base64Image,
        'businessName': businessNameController.text.trim(),
        'name': businessNameController.text.trim(), // Support generic name field
        'primaryContactName': contactNameController.text.trim(),
        'contact': phoneController.text.trim(),
        'exactAddress': buildingController.text.trim(),
        'streetName': streetController.text.trim(),
        'donorType': selectedDonorType,
        'latitude': position?.latitude ?? 0.0,
        'longitude': position?.longitude ?? 0.0,
        'city': city,
        'isProfileComplete': true,
        'verificationStatus': 'approved', 
        'isVerified': true,
        'rankScore': 0,
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
      appBar: AppBar(
        title: const Text("Donor Onboarding", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50, backgroundColor: Colors.orange.shade50,
                  backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                  child: _base64Image.isEmpty ? const Icon(Icons.add_a_photo, color: Colors.orange, size: 30) : null,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text("Basic Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: businessNameController, decoration: const InputDecoration(labelText: "Business/Hotel/Individual Name*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
            const SizedBox(height: 15),
            TextField(controller: contactNameController, decoration: const InputDecoration(labelText: "Contact Person Name*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
            const SizedBox(height: 15),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
            const SizedBox(height: 25),
            
            const Text("Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text("City: $currentCity", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700, 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("START SAVING FOOD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: Text("Thank you for joining our mission!", style: TextStyle(color: Colors.grey, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
