import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../login_screen.dart';
import '../landing_screen.dart';
import '../gamification/impact_wrapped_screen.dart';
import 'dart:convert';

class VolunteerProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  final VoidCallback onProfileUpdated;

  const VolunteerProfileTab({super.key, required this.userData, required this.uid, required this.onProfileUpdated});

  @override
  State<VolunteerProfileTab> createState() => _VolunteerProfileTabState();
}

class _VolunteerProfileTabState extends State<VolunteerProfileTab> {
  bool isUploading = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandingScreen()), (route) => false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);

      if (pickedFile != null) {
        setState(() => isUploading = true);
        List<int> imageBytes = await pickedFile.readAsBytes();
        String base64Image = base64Encode(imageBytes);
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'profileImageUrl': base64Image});
        widget.onProfileUpdated();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Photo Updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
    } finally {
      setState(() => isUploading = false);
    }
  }

  Future<void> _removeProfileImage() async {
    setState(() => isUploading = true);
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'profileImageUrl': ''});
    widget.onProfileUpdated();
    setState(() => isUploading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Photo Removed")));
  }

  void _showEditProfileSheet() {
    TextEditingController nameController = TextEditingController(text: widget.userData['name'] ?? '');
    TextEditingController phoneController = TextEditingController(text: widget.userData['phone'] ?? widget.userData['contact'] ?? '');
    TextEditingController baseAreaController = TextEditingController(text: widget.userData['baseArea'] ?? '');

    List<String> vehicleOptions = ['Bicycle', 'Scooter / Motorcycle', 'Car', 'Walking'];
    String selectedVehicle = widget.userData['vehicleType'] ?? vehicleOptions[1];
    if (!vehicleOptions.contains(selectedVehicle)) selectedVehicle = vehicleOptions[1];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Edit Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: baseAreaController, decoration: const InputDecoration(labelText: "Base Area", border: OutlineInputBorder())),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(value: selectedVehicle, decoration: const InputDecoration(labelText: "Transport", border: OutlineInputBorder()), items: vehicleOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setModalState(() => selectedVehicle = v!)),
                    const SizedBox(height: 25),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () async {
                      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'baseArea': baseAreaController.text.trim(),
                        'vehicleType': selectedVehicle,
                      });
                      widget.onProfileUpdated();
                      if (mounted) Navigator.pop(context);
                    }, child: const Text("Save Changes"))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28), const SizedBox(height: 5),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String profileUrl = widget.userData['profileImageUrl'] ?? '';
    ImageProvider? profileImage;
    if (profileUrl.isNotEmpty) {
      try { profileImage = MemoryImage(base64Decode(profileUrl)); } catch (e) { debugPrint("Error decoding image"); }
    }

    int score = widget.userData['rankScore'] ?? 0;
    int totalDeliveries = widget.userData['deliveriesMade'] ?? 0;
    int trustScore = widget.userData['trustScore'] ?? 100;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: CircleAvatar(radius: 45, backgroundColor: Colors.green.shade100, backgroundImage: profileImage, child: profileImage == null ? const Icon(Icons.person, size: 40, color: Colors.green) : null),
                ),
                if (profileUrl.isNotEmpty)
                  Positioned(
                    top: 0, right: 0,
                    child: GestureDetector(
                      onTap: _removeProfileImage,
                      child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                if (isUploading) const CircularProgressIndicator(color: Colors.green),
              ],
            ),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0), onPressed: _showEditProfileSheet, icon: const Icon(Icons.settings, size: 18), label: const Text("Settings"))
          ],
        ),
        const SizedBox(height: 15),
        Text(widget.userData['name'] ?? 'Hunger Hero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(widget.userData['phone'] ?? widget.userData['contact'] ?? 'No Phone Number', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        
        const SizedBox(height: 20),

        GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ImpactWrappedScreen(userData: widget.userData)));
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1a2a6c), Color(0xFFb21f1f)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 30),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Impact Wrapped 2026", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      Text("See your rescue vibe check ✨", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 25),
        Row(
          children: [
            _buildMetricCard("Rescues", "$totalDeliveries", Icons.local_shipping, Colors.blue), const SizedBox(width: 10),
            _buildMetricCard("Points", "$score", Icons.stars, Colors.amber.shade600), const SizedBox(width: 10),
            _buildMetricCard("Trust Score", "$trustScore", Icons.security, Colors.green),
          ],
        ),

        const SizedBox(height: 30),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _logout, icon: const Icon(Icons.logout), label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
      ],
    );
  }
}
