import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'volunteer_dashboard.dart';

class VolunteerProfileSetup extends StatefulWidget {
  const VolunteerProfileSetup({super.key});

  @override
  State<VolunteerProfileSetup> createState() => _VolunteerProfileSetupState();
}

class _VolunteerProfileSetupState extends State<VolunteerProfileSetup> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedVehicle = 'Scooter / Motorcycle';
  String _base64Image = '';
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      setState(() => _base64Image = base64Encode(imageBytes));
    }
  }

  Future<void> _completeSetup() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _base64Image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name, Phone, and Photo are mandatory!"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    // બધી જ જરૂરી માહિતી ડેટાબેઝમાં અપડેટ કરો
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'contact': _phoneController.text.trim(),
      'vehicleType': _selectedVehicle,
      'profileImageUrl': _base64Image,
      'isVerified': false,
      'trustScore': 100,
      'successRate': 100,
      'deliveriesMade': 0,
      'rankScore': 0,
    });

    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerDashboard()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Complete Profile"), automaticallyImplyLeading: false, backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("One Last Step!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green)),
            const SizedBox(height: 10),
            const Text("To prevent fraud and assign rescues correctly, we need a bit more info.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 30),

            Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.green.shade50,
                  backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                  child: _base64Image.isEmpty ? const Icon(Icons.camera_alt, size: 40, color: Colors.green) : null,
                ),
              ),
            ),
            const Align(alignment: Alignment.center, child: Padding(padding: EdgeInsets.only(top: 8), child: Text("Live Photo Required *", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 30),

            TextField(controller: _nameController, decoration: InputDecoration(labelText: "Full Name *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 15),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone Number *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: _selectedVehicle,
              decoration: InputDecoration(labelText: "Primary Transport *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: ['Bicycle', 'Scooter / Motorcycle', 'Car', 'Walking'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedVehicle = val!),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isLoading ? null : _completeSetup,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Start Rescuing Food", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}