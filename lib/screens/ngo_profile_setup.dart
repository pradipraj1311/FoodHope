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
  final TextEditingController socialMediaController = TextEditingController();
  
  String _base64Image = '';
  String _verificationProof = ''; 
  String _livePhoto = ''; 
  bool isLoading = false;
  String currentCity = "Fetching...";

  Future<void> _pickImage(String type) async {
    final ImagePicker picker = ImagePicker();
    XFile? image;
    if (type == 'live' || type == 'proof') {
      image = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);
    } else {
      image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);
    }

    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      setState(() {
        if (type == 'proof') _verificationProof = base64Encode(imageBytes);
        else if (type == 'live') _livePhoto = base64Encode(imageBytes);
        else _base64Image = base64Encode(imageBytes);
      });
    }
  }

  Future<void> saveProfile() async {
    // SENIOR DEV FIX: Mandatory Social Link or Doc Proof
    if (orgNameController.text.isEmpty || _livePhoto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Live Selfie are mandatory!")));
      return;
    }

    if (socialMediaController.text.isEmpty && _verificationProof.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide either Social Media Link or Document Proof!")));
      return;
    }

    setState(() => isLoading = true);

    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String city = placemarks.isNotEmpty ? (placemarks[0].locality ?? currentCity) : currentCity;

      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profileImageUrl': _base64Image,
        'verificationProofUrl': _verificationProof,
        'livePhotoUrl': _livePhoto,
        'socialMediaLink': socialMediaController.text.trim(),
        'organizationName': orgNameController.text.trim(),
        'distributorName': orgNameController.text.trim(),
        'exactAddress': buildingController.text.trim(),
        'streetName': streetController.text.trim(),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': city,
        'fullAddress': "${buildingController.text.trim()}, ${streetController.text.trim()}, $city",
        'isProfileComplete': true,
        'verificationStatus': 'pending', 
        'isVerified': false,
        'rankScore': 0,
        'deliveriesReceived': 0,
        'isAdmin': false,
        'isSuspended': false,
      });

      if (mounted) Navigator.pushReplacementNamed(context, '/');
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
      appBar: AppBar(title: const Text("NGO Hub Setup"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: () => _pickImage('profile'),
                child: CircleAvatar(
                  radius: 50, backgroundColor: Colors.teal.shade50,
                  backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                  child: _base64Image.isEmpty ? const Icon(Icons.add_a_photo, size: 40, color: Colors.teal) : null,
                ),
              ),
            ),
            const SizedBox(height: 25),
            TextField(controller: orgNameController, decoration: const InputDecoration(labelText: "Organization Name*", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: socialMediaController, decoration: const InputDecoration(labelText: "Social Media (Instagram/FB Link)*", hintText: "Compulsory if no document", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: buildingController, decoration: const InputDecoration(labelText: "Area / Building*", border: OutlineInputBorder())),
            
            const SizedBox(height: 25),
            const Text("1. Live Hub Identity (Compulsory Selfie)*", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImage('live'),
              child: Container(
                height: 120, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
                child: _livePhoto.isEmpty 
                  ? const Icon(Icons.camera_front, color: Colors.teal, size: 40)
                  : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(_livePhoto), fit: BoxFit.cover)),
              ),
            ),

            const SizedBox(height: 25),
            const Text("2. Upload Certificate (Optional if social link provided)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _pickImage('proof'),
              child: Container(
                height: 100, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                child: _verificationProof.isEmpty 
                  ? const Icon(Icons.upload_file, color: Colors.grey)
                  : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(_verificationProof), fit: BoxFit.cover)),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT FOR APPROVAL", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
