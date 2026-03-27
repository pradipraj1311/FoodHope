import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../login_screen.dart';

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
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

      if (pickedFile != null) {
        setState(() => isUploading = true);
        File imageFile = File(pickedFile.path);
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${widget.uid}.jpg');
        await storageRef.putFile(imageFile);
        String downloadUrl = await storageRef.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'profileImageUrl': downloadUrl});
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
    TextEditingController businessNameController = TextEditingController(text: widget.userData['businessName']);
    TextEditingController contactNameController = TextEditingController(text: widget.userData['primaryContactName']);

    String donorType = widget.userData['donorType'] ?? 'Restaurant';
    bool hasCert = widget.userData['hasFoodSafetyCert'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                    const Text("Edit Business Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    TextField(controller: businessNameController, decoration: InputDecoration(label: _requiredLabel("Business/Restaurant Name"), border: const OutlineInputBorder())),
                    const SizedBox(height: 15),

                    TextField(controller: contactNameController, decoration: InputDecoration(label: _requiredLabel("Primary Contact Name"), border: const OutlineInputBorder())),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: donorType,
                      decoration: InputDecoration(label: _requiredLabel("Business Type"), border: const OutlineInputBorder()),
                      items: ['Restaurant', 'Caterer', 'Hotel', 'Supermarket', 'Individual'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => donorType = val!),
                    ),
                    const SizedBox(height: 15),

                    SwitchListTile(
                      title: const Text("FSSAI / Food Safety Certified?"),
                      value: hasCert,
                      onChanged: (val) => setModalState(() => hasCert = val),
                    ),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (businessNameController.text.isEmpty || contactNameController.text.isEmpty) return;
                          await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                            'businessName': businessNameController.text.trim(),
                            'primaryContactName': contactNameController.text.trim(),
                            'donorType': donorType,
                            'hasFoodSafetyCert': hasCert,
                          });
                          widget.onProfileUpdated();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text("Save Changes", style: TextStyle(fontSize: 18)),
                      ),
                    ),
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

  @override
  Widget build(BuildContext context) {
    String profileUrl = widget.userData['profileImageUrl'] ?? '';

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
                  CircleAvatar(radius: 45, backgroundColor: Colors.orange.shade100, backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null, child: profileUrl.isEmpty ? const Icon(Icons.store, size: 40, color: Colors.orange) : null),
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
        Text(widget.userData['primaryContactName'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 30),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.category, color: Colors.blue), title: const Text("Type"), trailing: Text(widget.userData['donorType'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.verified, color: Colors.green), title: const Text("Safety Certified"), trailing: Text((widget.userData['hasFoodSafetyCert'] == true) ? "Yes" : "No", style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _logout, icon: const Icon(Icons.logout), label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}