import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../login_screen.dart';
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
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen(role: 'Volunteer')), (route) => false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);

      if (pickedFile != null) {
        setState(() => isUploading = true);

        List<int> imageBytes = await pickedFile.readAsBytes();
        String base64Image = base64Encode(imageBytes);

        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
          'profileImageUrl': base64Image
        });

        widget.onProfileUpdated();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Photo Updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
    } finally {
      setState(() => isUploading = false);
    }
  }

  Widget _requiredLabel(String text) {
    return Text.rich(TextSpan(text: text, style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.bold), children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red))]));
  }

  void _showEditProfileSheet() {
    TextEditingController nameController = TextEditingController(text: widget.userData['name'] ?? '');
    TextEditingController phoneController = TextEditingController(text: widget.userData['phone'] ?? widget.userData['contact'] ?? '');
    TextEditingController baseAreaController = TextEditingController(text: widget.userData['baseArea'] ?? '');
    TextEditingController restrictionsController = TextEditingController(text: widget.userData['restrictions'] ?? '');

    List<String> vehicleOptions = ['Bicycle', 'Scooter / Motorcycle', 'Car', 'Walking', 'NGO Van / Auto'];
    String selectedVehicle = widget.userData['vehicleType'] ?? vehicleOptions[1];
    if (!vehicleOptions.contains(selectedVehicle)) selectedVehicle = vehicleOptions[1];

    List<String> distanceOptions = ['5 km', '10 km', '20 km', '50+ km'];
    String selectedDistance = widget.userData['maxDistance'] ?? distanceOptions[0];
    if (!distanceOptions.contains(selectedDistance)) selectedDistance = distanceOptions[0];

    List<String> capacityOptions = ['Small (1-10 meals)', 'Medium (10-50 meals)', 'Large (50+ meals)'];
    String selectedCapacity = widget.userData['capacity'] ?? capacityOptions[1];
    if (!capacityOptions.contains(selectedCapacity)) selectedCapacity = capacityOptions[1];

    List<String> prefOptions = ['Any Food', 'Veg Only'];
    String selectedPref = widget.userData['foodPreference'] ?? prefOptions[0];
    if (!prefOptions.contains(selectedPref)) selectedPref = prefOptions[0];

    List<String> availOptions = ['Anytime', 'Mornings', 'Evenings', 'Weekends'];
    String selectedAvail = widget.userData['availability'] ?? availOptions[0];
    if (!availOptions.contains(selectedAvail)) selectedAvail = availOptions[0];

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
                    const Text("Logistics Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    const Text("This data helps us auto-assign optimal rescues to you.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 15),

                    TextField(controller: nameController, decoration: InputDecoration(label: _requiredLabel("Full Name"), border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(label: _requiredLabel("Phone Number"), border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: baseAreaController, decoration: const InputDecoration(labelText: "Base Area / Neighborhood (e.g. Piplag)", border: OutlineInputBorder())),

                    const Divider(height: 25, thickness: 2),
                    const Text("Delivery Preferences", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(value: selectedVehicle, decoration: InputDecoration(label: _requiredLabel("Transport"), border: const OutlineInputBorder()), items: vehicleOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (val) => setModalState(() => selectedVehicle = val!))),
                        const SizedBox(width: 10),
                        Expanded(child: DropdownButtonFormField<String>(value: selectedDistance, decoration: InputDecoration(label: _requiredLabel("Max Distance"), border: const OutlineInputBorder()), items: distanceOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (val) => setModalState(() => selectedDistance = val!))),
                      ],
                    ), const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(value: selectedCapacity, decoration: InputDecoration(label: _requiredLabel("Max Capacity"), border: const OutlineInputBorder()), items: capacityOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 11)))).toList(), onChanged: (val) => setModalState(() => selectedCapacity = val!))),
                        const SizedBox(width: 10),
                        Expanded(child: DropdownButtonFormField<String>(value: selectedPref, decoration: InputDecoration(label: _requiredLabel("Dietary Pref"), border: const OutlineInputBorder()), items: prefOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (val) => setModalState(() => selectedPref = val!))),
                      ],
                    ), const SizedBox(height: 10),

                    DropdownButtonFormField<String>(value: selectedAvail, decoration: InputDecoration(label: _requiredLabel("Typical Availability"), border: const OutlineInputBorder()), items: availOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (val) => setModalState(() => selectedAvail = val!)), const SizedBox(height: 10),
                    TextField(controller: restrictionsController, decoration: const InputDecoration(labelText: "Restrictions (e.g., No night delivery)", border: OutlineInputBorder())),

                    const SizedBox(height: 25),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () async {
                      if (nameController.text.isEmpty || phoneController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!"))); return; }

                      // Save all "Decision-Making Data"
                      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'contact': phoneController.text.trim(),
                        'baseArea': baseAreaController.text.trim(),
                        'vehicleType': selectedVehicle,
                        'maxDistance': selectedDistance,
                        'capacity': selectedCapacity,
                        'foodPreference': selectedPref,
                        'availability': selectedAvail,
                        'restrictions': restrictionsController.text.trim(),
                        // Add initial trust metrics if they don't exist
                        'trustScore': widget.userData['trustScore'] ?? 100,
                        'successRate': widget.userData['successRate'] ?? 100,
                      });
                      widget.onProfileUpdated();
                      if (mounted) Navigator.pop(context);
                    }, child: const Text("Save Logistics Profile", style: TextStyle(fontSize: 18)))), const SizedBox(height: 20),
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

    // Default stats for new users
    int impactPoints = widget.userData['impactPoints'] ?? widget.userData['rankScore'] ?? 0;
    int totalDeliveries = widget.userData['deliveriesMade'] ?? 0;
    int trustScore = widget.userData['trustScore'] ?? 100;
    int successRate = widget.userData['successRate'] ?? 100;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _pickAndUploadImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(radius: 45, backgroundColor: Colors.green.shade100, backgroundImage: profileImage, child: profileImage == null ? const Icon(Icons.person, size: 40, color: Colors.green) : null),
                  if (isUploading) const CircularProgressIndicator(color: Colors.green),
                  if (!isUploading) CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 18, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0), onPressed: _showEditProfileSheet, icon: const Icon(Icons.settings, size: 18), label: const Text("Preferences"))
          ],
        ),
        const SizedBox(height: 15),

        Row(
          children: [
            Text(widget.userData['name'] ?? 'Hunger Hero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (widget.userData['isVerified'] == true || totalDeliveries > 5) ...[
              const SizedBox(width: 8), const Icon(Icons.verified, color: Colors.blue, size: 20)
            ]
          ],
        ),
        Text(widget.userData['phone'] ?? widget.userData['contact'] ?? 'No Phone Number', style: const TextStyle(color: Colors.grey, fontSize: 14)),
        if (widget.userData['baseArea'] != null && widget.userData['baseArea'].toString().isNotEmpty)
          Text("📍 Base: ${widget.userData['baseArea']}", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),

        const SizedBox(height: 25),
        const Text("Trust & Impact", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        Row(
          children: [
            _buildMetricCard("Rescues", "$totalDeliveries", Icons.local_shipping, Colors.blue), const SizedBox(width: 10),
            _buildMetricCard("Points", "$impactPoints", Icons.stars, Colors.amber.shade600), const SizedBox(width: 10),
            _buildMetricCard("Trust Score", "$trustScore", Icons.security, Colors.green),
          ],
        ),

        const SizedBox(height: 25),
        const Text("Logistics Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        Card(
          elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.directions_bike, color: Colors.teal), title: const Text("Transport"), trailing: Text(widget.userData['vehicleType'] ?? 'Not Set', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))), const Divider(height: 0),
              ListTile(leading: const Icon(Icons.map, color: Colors.blue), title: const Text("Max Distance"), trailing: Text(widget.userData['maxDistance'] ?? 'Not Set', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))), const Divider(height: 0),
              ListTile(leading: const Icon(Icons.inventory_2, color: Colors.orange), title: const Text("Capacity"), subtitle: Text(widget.userData['capacity'] ?? 'Not Set', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))), const Divider(height: 0),
              ListTile(leading: const Icon(Icons.access_time, color: Colors.purple), title: const Text("Availability"), trailing: Text(widget.userData['availability'] ?? 'Not Set', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        ),

        const SizedBox(height: 30),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _logout, icon: const Icon(Icons.logout), label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
      ],
    );
  }
}