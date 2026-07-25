import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../login_screen.dart';
import '../landing_screen.dart';
import '../gamification/impact_wrapped_screen.dart';
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Logo Updated!")));
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
    
    String selectedDonorType = widget.userData['donorType'] ?? 'Restaurant';
    final List<String> donorTypes = ['Restaurant', 'Hotel', 'Hostel Mess', 'Event / Wedding', 'Supermarket', 'Individual / Other'];

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
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(label: _requiredLabel("Phone Number"), border: const OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedDonorType,
                      decoration: const InputDecoration(labelText: "Business Category*", border: OutlineInputBorder()),
                      items: donorTypes.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedDonorType = val!),
                    ),
                    const Divider(height: 25, thickness: 2),
                    TextField(controller: exactAddressController, decoration: InputDecoration(label: _requiredLabel("Building Name"), border: const OutlineInputBorder())), const SizedBox(height: 10),
                    TextField(controller: streetController, decoration: InputDecoration(label: _requiredLabel("Street / Road"), border: const OutlineInputBorder())), const SizedBox(height: 25),
                    SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white), onPressed: () async {
                      if (businessNameController.text.isEmpty || contactNameController.text.isEmpty || phoneController.text.isEmpty || exactAddressController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields")));
                        return;
                      }
                      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                        'businessName': businessNameController.text.trim(), 
                        'primaryContactName': contactNameController.text.trim(), 
                        'contact': phoneController.text.trim(), 
                        'exactAddress': exactAddressController.text.trim(), 
                        'streetName': streetController.text.trim(), 
                        'donorType': selectedDonorType
                      });
                      widget.onProfileUpdated();
                      if (mounted) Navigator.pop(context);
                    }, child: const Text("Save Changes"))), const SizedBox(height: 20),
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

    ImageProvider? profileImage;
    if (profileUrl.isNotEmpty) {
      try { profileImage = MemoryImage(base64Decode(profileUrl)); } catch (e) { debugPrint("Error decoding image"); }
    }

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
                  child: CircleAvatar(radius: 45, backgroundColor: Colors.orange.shade100, backgroundImage: profileImage, child: profileImage == null ? const Icon(Icons.store, size: 40, color: Colors.orange) : null),
                ),
                if (profileUrl.isNotEmpty)
                  Positioned(
                    top: 0, right: 0,
                    child: GestureDetector(
                      onTap: _removeProfileImage,
                      child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)),
                    ),
                  ),
                if (isUploading) const CircularProgressIndicator(color: Colors.orange),
              ],
            ),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0), onPressed: _showEditProfileSheet, icon: const Icon(Icons.edit, size: 18), label: const Text("Edit Profile"))
          ],
        ),
        const SizedBox(height: 20),
        Text(widget.userData['businessName'] ?? 'Donor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(widget.userData['contact'] ?? 'No Phone Number Saved', style: const TextStyle(color: Colors.grey, fontSize: 16)),
        
        const SizedBox(height: 20),
        
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ImpactWrappedScreen(userData: widget.userData))),
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
                      Text("See your donation vibe check ✨", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.category, color: Colors.blue), title: const Text("Category"), trailing: Text(widget.userData['donorType'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
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
