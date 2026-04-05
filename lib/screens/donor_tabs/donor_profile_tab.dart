import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../login_screen.dart';
import 'dart:convert';

class DonorProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  final VoidCallback onProfileUpdated;

  const DonorProfileTab({super.key, required this.userData, required this.uid, required this.onProfileUpdated});

  @override
  State<DonorProfileTab> createState() => _DonorProfileTabState();
}

class _DonorProfileTabState extends State<DonorProfileTab> {
  bool isUploading = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen(role: 'Donor')), (route) => false);
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25); // Low quality for small string

      if (pickedFile != null) {
        setState(() => isUploading = true);

        // --- BASE64 FREE HACK ---
        List<int> imageBytes = await pickedFile.readAsBytes();
        String base64Image = base64Encode(imageBytes);

        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'profileImageUrl': base64Image});
        widget.onProfileUpdated();

        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logo Updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
    } finally {
      setState(() => isUploading = false);
    }
  }

  Widget _requiredLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text, style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
      ),
    );
  }

  void _showEditProfileSheet() {
    TextEditingController businessNameController = TextEditingController(text: widget.userData['businessName'] ?? '');
    TextEditingController contactNameController = TextEditingController(text: widget.userData['primaryContactName'] ?? '');
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact'] ?? '');
    TextEditingController exactAddressController = TextEditingController(text: widget.userData['exactAddress'] ?? '');
    TextEditingController streetController = TextEditingController(text: widget.userData['streetName'] ?? '');
    TextEditingController landmarkController = TextEditingController(text: widget.userData['landmark'] ?? '');

    String donorType = widget.userData['donorType'] ?? 'Restaurant';
    String surplusFrequency = widget.userData['surplusFrequency'] ?? 'Occasional / Unpredictable';
    String selectedPickup = widget.userData['pickupInstructions'] ?? 'Hand to front desk / reception';

    List<String> pickupOptions = ['Hand to front desk / reception', 'Call upon arrival, I will bring it out', 'Pick up from back door / kitchen', 'Self-pickup from designated counter', 'Other (Call me for details)'];
    if (!pickupOptions.contains(selectedPickup)) selectedPickup = pickupOptions[0];

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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Edit Business Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
                    TextField(controller: businessNameController, decoration: InputDecoration(label: _requiredLabel("Business/Entity Name"), border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: contactNameController, decoration: InputDecoration(label: _requiredLabel("Primary Contact Name"), border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(label: _requiredLabel("Phone Number (For Volunteers)"), border: const OutlineInputBorder())),
                    const Divider(height: 25, thickness: 2),
                    const Text("Exact Location Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(height: 15),
                    TextField(controller: exactAddressController, decoration: InputDecoration(label: _requiredLabel("Flat / Building / Hostel Name"), hintText: "e.g., LS Boys Hostel, L Complex", border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: streetController, decoration: InputDecoration(label: _requiredLabel("Street / Road / Area"), hintText: "e.g., Uttarsanda Road, Piplag", border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: landmarkController, decoration: const InputDecoration(labelText: "Nearby Landmark (Optional)", border: OutlineInputBorder())), const SizedBox(height: 10),
                    DropdownButtonFormField<String>(value: selectedPickup, decoration: InputDecoration(label: _requiredLabel("Default Pickup Instructions"), border: const OutlineInputBorder()), items: pickupOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) => setModalState(() => selectedPickup = val!)),
                    const Divider(height: 25, thickness: 2),
                    DropdownButtonFormField<String>(value: donorType, decoration: InputDecoration(label: _requiredLabel("Business Type"), border: const OutlineInputBorder()), items: ['Restaurant', 'Hotel', 'Event / Wedding', 'Hostel Mess', 'Supermarket', 'Trust / NGO', 'Individual'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (val) => setModalState(() => donorType = val!)), const SizedBox(height: 10),
                    DropdownButtonFormField<String>(value: surplusFrequency, decoration: InputDecoration(label: _requiredLabel("How often do you have extra food?"), border: const OutlineInputBorder()), items: ['Daily', 'Weekly', 'Occasional / Unpredictable', 'One-time Event'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (val) => setModalState(() => surplusFrequency = val!)), const SizedBox(height: 25),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white), onPressed: () async {
                      if (businessNameController.text.isEmpty || contactNameController.text.isEmpty || phoneController.text.isEmpty || exactAddressController.text.isEmpty || streetController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!"))); return; }
                      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'businessName': businessNameController.text.trim(), 'primaryContactName': contactNameController.text.trim(), 'contact': phoneController.text.trim(), 'exactAddress': exactAddressController.text.trim(), 'streetName': streetController.text.trim(), 'landmark': landmarkController.text.trim(), 'pickupInstructions': selectedPickup, 'donorType': donorType, 'surplusFrequency': surplusFrequency});
                      widget.onProfileUpdated();
                      if (mounted) Navigator.pop(context);
                    }, child: const Text("Save Changes", style: TextStyle(fontSize: 18)))), const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String profileUrl = widget.userData['profileImageUrl'] ?? '';

    // --- SAFE IMAGE DECODING ---
    ImageProvider? profileImage;
    if (profileUrl.isNotEmpty) {
      try {
        profileImage = MemoryImage(base64Decode(profileUrl));
      } catch (e) {
        debugPrint("Error decoding image");
      }
    }

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
                  CircleAvatar(radius: 45, backgroundColor: Colors.orange.shade100, backgroundImage: profileImage, child: profileImage == null ? const Icon(Icons.store, size: 40, color: Colors.orange) : null),
                  if (isUploading) const CircularProgressIndicator(color: Colors.orange),
                  if (!isUploading) CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 18, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0), onPressed: _showEditProfileSheet, icon: const Icon(Icons.edit, size: 18), label: const Text("Edit Profile"))
          ],
        ),
        const SizedBox(height: 20),
        Text(widget.userData['businessName'] ?? 'Donor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(widget.userData['contact'] ?? 'No Phone Number Saved', style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 30),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.category, color: Colors.blue), title: const Text("Type"), trailing: Text(widget.userData['donorType'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.home, color: Colors.orange), title: const Text("Location"), subtitle: Text("${widget.userData['exactAddress'] ?? 'Building'}\n${widget.userData['streetName'] ?? 'Street'}", style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _logout, icon: const Icon(Icons.logout), label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
      ],
    );
  }
}