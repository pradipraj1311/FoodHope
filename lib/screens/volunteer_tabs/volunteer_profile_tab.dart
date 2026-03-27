import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../login_screen.dart';

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
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen(role: 'Volunteer')), (route) => false);
    }
  }

  // --- IMPROVED IMAGE PICKER ---
  Future<void> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      // Using gallery. If it fails on emulator, we catch the error gracefully.
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

      if (pickedFile != null) {
        setState(() => isUploading = true);
        File imageFile = File(pickedFile.path);

        // Upload to Firebase
        final storageRef = FirebaseStorage.instance.ref().child('profile_images').child('${widget.uid}.jpg');
        await storageRef.putFile(imageFile);

        String downloadUrl = await storageRef.getDownloadURL();
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'profileImageUrl': downloadUrl});

        widget.onProfileUpdated();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Picture Updated!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed (Check Permissions/Storage Rules): $e")));
    } finally {
      setState(() => isUploading = false);
    }
  }

  // Helper widget to add the Red Star (*)
  Widget _requiredLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
      ),
    );
  }

  void _showEditProfileSheet() {
    TextEditingController nameController = TextEditingController(text: widget.userData['name']);
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact']);

    // AGE LOGIC: Generate list from 13 to 80!
    List<String> ageOptions = List.generate(68, (index) => (13 + index).toString());
    String currentAgeStr = widget.userData['age']?.toString() ?? '18'; // Default to 18
    String selectedAge = ageOptions.contains(currentAgeStr) && currentAgeStr != '0' ? currentAgeStr : '18';

    String selectedGender = widget.userData['gender'] ?? 'Male';

    String selectedFood = widget.userData['foodPreference'] ?? 'Any Food (Veg & Non-Veg)';
    String selectedStorage = widget.userData['storageCapacity'] ?? 'Backpack / Small Bag';
    String selectedRange = widget.userData['travelRange'] ?? 'Up to 5 km';
    String selectedTime = widget.userData['bestTime'] ?? 'Anytime';

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
                    const Text("Edit Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), // Changed Title
                    const SizedBox(height: 15),

                    TextField(
                        controller: nameController,
                        decoration: InputDecoration(label: _requiredLabel("Full Name"), border: const OutlineInputBorder())
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedAge,
                            decoration: InputDecoration(label: _requiredLabel("Age"), border: const OutlineInputBorder()),
                            items: ageOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (val) => setModalState(() => selectedAge = val!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedGender,
                            decoration: InputDecoration(label: _requiredLabel("Gender"), border: const OutlineInputBorder()),
                            items: ['Male', 'Female', 'Other'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (val) => setModalState(() => selectedGender = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: phoneController,
                        decoration: InputDecoration(label: _requiredLabel("Phone/Contact"), border: const OutlineInputBorder())
                    ),

                    const Divider(height: 30, thickness: 2),
                    const Text("Delivery Capabilities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedFood,
                      decoration: InputDecoration(label: _requiredLabel("Food Accepted"), border: const OutlineInputBorder()),
                      items: ['Any Food (Veg & Non-Veg)', 'Veg Only', 'Non-Veg Only'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedFood = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedStorage,
                      decoration: InputDecoration(label: _requiredLabel("Storage / Transport"), border: const OutlineInputBorder()),
                      items: ['Backpack / Small Bag', 'Bike Box / Large Bag', 'Car Trunk', 'Large Van'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedStorage = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedRange,
                      decoration: InputDecoration(label: _requiredLabel("Travel Range"), border: const OutlineInputBorder()),
                      items: ['Up to 3 km', 'Up to 5 km', 'Up to 10 km', 'Up to 20 km', 'Up to 30 km', 'Anywhere in City'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedRange = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedTime,
                      decoration: InputDecoration(label: _requiredLabel("Best Time to Deliver"), border: const OutlineInputBorder()),
                      items: ['Anytime', 'Mornings (8AM - 12PM)', 'Afternoons (12PM - 4PM)', 'Evenings (4PM - 8PM)', 'Night (After 8PM)'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedTime = val!),
                    ),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (nameController.text.isEmpty || phoneController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
                            return;
                          }

                          await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                            'name': nameController.text.trim(),
                            'age': int.parse(selectedAge),
                            'gender': selectedGender,
                            'contact': phoneController.text.trim(),
                            'foodPreference': selectedFood,
                            'storageCapacity': selectedStorage,
                            'travelRange': selectedRange,
                            'bestTime': selectedTime,
                          });
                          widget.onProfileUpdated();
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully!")));
                          }
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
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null,
                    child: profileUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.green) : null,
                  ),
                  if (isUploading) const CircularProgressIndicator(color: Colors.green),
                  if (!isUploading) CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 18, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0),
              onPressed: _showEditProfileSheet,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Edit Profile"),
            )
          ],
        ),
        const SizedBox(height: 20),
        Text(widget.userData['name'] ?? 'Volunteer Hero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(widget.userData['contact'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 16)),

        if (widget.userData.containsKey('age') && widget.userData.containsKey('gender'))
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text("${widget.userData['gender']}, ${widget.userData['age']} yrs", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ),

        const SizedBox(height: 30),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(
                  leading: const Icon(Icons.local_dining, color: Colors.orange),
                  title: const Text("Food Type"),
                  trailing: Text(widget.userData['foodPreference'] ?? 'Any Food', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
              ),
              const Divider(height: 0),
              ListTile(
                  leading: const Icon(Icons.inventory_2, color: Colors.blue),
                  title: const Text("Capacity"),
                  trailing: Text(widget.userData['storageCapacity'] ?? 'Backpack', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
              ),
              const Divider(height: 0),
              ListTile(
                  leading: const Icon(Icons.map, color: Colors.green),
                  title: const Text("Range"),
                  trailing: Text(widget.userData['travelRange'] ?? 'Up to 5 km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
              ),
              const Divider(height: 0),
              ListTile(
                  leading: const Icon(Icons.schedule, color: Colors.purple),
                  title: const Text("Available"),
                  trailing: Text(widget.userData['bestTime'] ?? 'Anytime', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }
}