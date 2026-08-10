import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'ngo_dashboard.dart';

class NgoProfileSetup extends StatefulWidget {
  const NgoProfileSetup({super.key});

  @override
  State<NgoProfileSetup> createState() => _NgoProfileSetupState();
}

class _NgoProfileSetupState extends State<NgoProfileSetup> {
  final TextEditingController orgNameController = TextEditingController();
  final TextEditingController buildingController = TextEditingController();
  final TextEditingController streetController = TextEditingController();
  
  String _base64Image = '';
  String _verificationProof = ''; // NEW: Base64 for Doc/ID Proof
  bool isLoading = false;
  String currentCity = "Fetching...";

  String selectedOrgType = 'NGO'; // Default

  @override
  void initState() {
    super.initState();
    _autoFetchLocation();
  }

  @override
  void dispose() {
    orgNameController.dispose();
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

  Future<void> _pickImage(bool isProof) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: isProof ? ImageSource.camera : ImageSource.gallery, 
      imageQuality: 25
    );
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      setState(() {
        if (isProof) {
          _verificationProof = base64Encode(imageBytes);
        } else {
          _base64Image = base64Encode(imageBytes);
        }
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
    if (orgNameController.text.isEmpty || buildingController.text.isEmpty || streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all mandatory fields!")));
      return;
    }

    if (_verificationProof.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please upload verification proof (Cert/ID)")));
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

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': _base64Image,
        'verificationProofUrl': _verificationProof,
        'organizationName': orgNameController.text.trim(),
        'distributorName': orgNameController.text.trim(),
        'organizationType': selectedOrgType,
        'exactAddress': buildingController.text.trim(),
        'streetName': streetController.text.trim(),
        'latitude': position?.latitude ?? 0.0,
        'longitude': position?.longitude ?? 0.0,
        'city': city,
        'fullAddress': "${buildingController.text.trim()}, ${streetController.text.trim()}, $city",
        'isProfileComplete': true,
        'verificationStatus': 'pending', // Waiting for Admin
        'isVerified': false,
        'rankScore': 0,
        'deliveriesReceived': 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Setup complete! Admin will verify your hub soon.")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NgoDashboard()));
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
      appBar: AppBar(title: const Text("NGO / Hub Setup"), automaticallyImplyLeading: false, elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _pickImage(false),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.teal.shade50,
                      backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                      child: _base64Image.isEmpty ? const Icon(Icons.add_a_photo, size: 40, color: Colors.teal) : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            DropdownButtonFormField<String>(
              value: selectedOrgType,
              decoration: const InputDecoration(labelText: "Organization Type*", border: OutlineInputBorder()),
              items: ['NGO', 'Volunteer Group', 'Religious Trust'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => selectedOrgType = v!),
            ),
            const SizedBox(height: 15),
            TextField(controller: orgNameController, decoration: const InputDecoration(labelText: "Organization Name*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.corporate_fare))),
            const SizedBox(height: 15),
            TextField(controller: buildingController, decoration: const InputDecoration(labelText: "Building / Complex Name*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home))),
            const SizedBox(height: 15),
            TextField(controller: streetController, decoration: const InputDecoration(labelText: "Street / Area*", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map))),
            const SizedBox(height: 25),
            
            // VERIFICATION PROOF BOX
            const Text("Verification Proof Required*", style: TextStyle(fontWeight: FontWeight.bold)),
            const Text("Upload FSSAI, 80G, or Volunteer Group ID card.", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                child: _verificationProof.isEmpty 
                  ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.upload_file, color: Colors.teal), Text("Click to Capture Photo of Certificate / ID", style: TextStyle(fontSize: 12))])
                  : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(_verificationProof), fit: BoxFit.cover)),
              ),
            ),

            const SizedBox(height: 15),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 5),
                Text("City: $currentCity", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
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
