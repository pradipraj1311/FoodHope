import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../login_screen.dart';

class NgoProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  final VoidCallback onProfileUpdated;

  const NgoProfileTab({super.key, required this.userData, required this.uid, required this.onProfileUpdated});

  @override
  State<NgoProfileTab> createState() => _NgoProfileTabState();
}

class _NgoProfileTabState extends State<NgoProfileTab> {
  bool isUploading = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen(role: 'NGO')), (route) => false);
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Photo Updated!")));
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

  Widget _buildDistributorBadge(String type) {
    if (type == 'NGO') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade300)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, size: 14, color: Colors.green.shade700), const SizedBox(width: 4), Text("Verified NGO", style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold))]),
      );
    } else if (type == 'Volunteer Group') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.blue.shade300)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star, size: 14, color: Colors.blue.shade700), const SizedBox(width: 4), Text("Community Verified Group", style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.bold))]),
      );
    } else if (type == 'Religious Trust') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.orange.shade300)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.temple_hindu, size: 14, color: Colors.orange.shade700), const SizedBox(width: 4), Text("Religious Trust Verified", style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold))]),
      );
    }
    return const SizedBox.shrink();
  }

  void _showEditProfileSheet() {
    TextEditingController nameController = TextEditingController(text: widget.userData['distributorName'] ?? widget.userData['ngoName'] ?? '');
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact'] ?? '');

    // ZOMATO STYLE EXACT ADDRESS CONTROLLERS
    TextEditingController exactAddressController = TextEditingController(text: widget.userData['exactAddress'] ?? '');
    TextEditingController streetController = TextEditingController(text: widget.userData['streetName'] ?? '');
    TextEditingController landmarkController = TextEditingController(text: widget.userData['landmark'] ?? '');

    TextEditingController cert80gController = TextEditingController(text: widget.userData['cert80g'] ?? '');
    TextEditingController websiteController = TextEditingController(text: widget.userData['website'] ?? '');
    TextEditingController socialMediaController = TextEditingController(text: widget.userData['socialMedia'] ?? '');
    TextEditingController gstController = TextEditingController(text: widget.userData['gstDetails'] ?? '');

    // ==========================================
    // CRITICAL BUG FIX: SAFE DROPDOWN FALLBACKS
    // ==========================================
    List<String> typeOptions = ['NGO', 'Volunteer Group', 'Religious Trust'];
    String distributorType = widget.userData['distributorType'] ?? typeOptions[0];
    if (!typeOptions.contains(distributorType)) distributorType = typeOptions[0];

    List<String> capacityOptions = ['Under 50 meals', '50 - 100 meals', '100 - 300 meals', '300 - 500 meals', '500+ meals'];
    String selectedCapacity = widget.userData['storageCapacity'] ?? capacityOptions[1];
    if (!capacityOptions.contains(selectedCapacity)) selectedCapacity = capacityOptions[1];

    List<String> foodPrefOptions = ['Any Food (Veg & Non-Veg)', 'Veg Only', 'Non-Veg Only'];
    String selectedFoodPref = widget.userData['foodPreference'] ?? foodPrefOptions[0];
    if (!foodPrefOptions.contains(selectedFoodPref)) selectedFoodPref = foodPrefOptions[0];

    List<String> volOptions = ['1-5 members', '5-20 members', '20-50 members', '50+ members'];
    String volunteerCount = widget.userData['volunteerCount'] ?? volOptions[0];
    if (!volOptions.contains(volunteerCount)) volunteerCount = volOptions[0];

    // Safely parse the boolean switch to avoid type crashes
    bool hasColdStorage = false;
    if (widget.userData['hasColdStorage'] is bool) {
      hasColdStorage = widget.userData['hasColdStorage'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Distributor Profile Setup", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: distributorType,
                      decoration: InputDecoration(label: _requiredLabel("Organization Type"), border: const OutlineInputBorder()),
                      items: typeOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (val) => setModalState(() => distributorType = val!),
                    ),
                    const SizedBox(height: 15),

                    TextField(controller: nameController, decoration: InputDecoration(label: _requiredLabel("Organization / Trust Name"), border: const OutlineInputBorder())),
                    const SizedBox(height: 10),

                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(label: _requiredLabel("Coordinator Phone Number"), border: const OutlineInputBorder())),
                    const SizedBox(height: 10),

                    if (distributorType == 'NGO') ...[
                      TextField(controller: cert80gController, decoration: const InputDecoration(labelText: "80G / 12A Details (Optional)", border: OutlineInputBorder())),
                      const SizedBox(height: 10),
                      TextField(controller: websiteController, decoration: const InputDecoration(labelText: "Website / Social Links", border: OutlineInputBorder())),
                    ] else if (distributorType == 'Volunteer Group') ...[
                      TextField(controller: socialMediaController, decoration: InputDecoration(label: _requiredLabel("Social Media / Group Page Link"), border: const OutlineInputBorder())),
                    ] else if (distributorType == 'Religious Trust') ...[
                      TextField(controller: gstController, decoration: const InputDecoration(labelText: "GST / Donation Receipt Book No. (Optional)", border: OutlineInputBorder())),
                    ],

                    const Divider(height: 25, thickness: 2),
                    const Text("Exact Location Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 15),

                    TextField(controller: exactAddressController, decoration: InputDecoration(label: _requiredLabel("Flat / Building / Trust Name"), hintText: "e.g., L.S. Boys Hostel", border: const OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: streetController, decoration: InputDecoration(label: _requiredLabel("Street / Road / Area"), hintText: "e.g., Uttarsanda Road", border: const OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: landmarkController, decoration: const InputDecoration(labelText: "Nearby Landmark (Optional)", border: OutlineInputBorder())),

                    const Divider(height: 25, thickness: 2),
                    const Text("Capacity & Logistics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: volunteerCount,
                      decoration: InputDecoration(label: _requiredLabel("Active Volunteers/Members"), border: const OutlineInputBorder()),
                      items: volOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => volunteerCount = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedCapacity,
                      decoration: InputDecoration(label: _requiredLabel("Storage / Feeding Capacity"), border: const OutlineInputBorder()),
                      items: capacityOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedCapacity = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedFoodPref,
                      decoration: InputDecoration(label: _requiredLabel("Food Type Accepted"), border: const OutlineInputBorder()),
                      items: foodPrefOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedFoodPref = val!),
                    ),
                    const SizedBox(height: 10),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Do you have Cold Storage (Fridges)?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      value: hasColdStorage,
                      onChanged: (val) => setModalState(() => hasColdStorage = val),
                      activeColor: Colors.teal,
                    ),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (nameController.text.isEmpty || phoneController.text.isEmpty || exactAddressController.text.isEmpty || streetController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
                            return;
                          }
                          if (distributorType == 'Volunteer Group' && socialMediaController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Social Media link required for Volunteer Groups!")));
                            return;
                          }

                          await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                            'distributorType': distributorType,
                            'distributorName': nameController.text.trim(),
                            'contact': phoneController.text.trim(),
                            'exactAddress': exactAddressController.text.trim(),
                            'streetName': streetController.text.trim(),
                            'landmark': landmarkController.text.trim(),

                            // Dynamic Fields Save
                            'cert80g': cert80gController.text.trim(),
                            'website': websiteController.text.trim(),
                            'socialMedia': socialMediaController.text.trim(),
                            'gstDetails': gstController.text.trim(),

                            'volunteerCount': volunteerCount,
                            'storageCapacity': selectedCapacity,
                            'foodPreference': selectedFoodPref,
                            'hasColdStorage': hasColdStorage,
                            'isVerified': true,
                          });
                          widget.onProfileUpdated();
                          if (mounted) Navigator.pop(context);
                        },
                        child: const Text("Save & Verify Profile", style: TextStyle(fontSize: 18)),
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
    String currentType = widget.userData['distributorType'] ?? 'NGO';

    // Stitched Address for UI
    String exactAddress = widget.userData['exactAddress'] ?? 'Building Not Set';
    String streetName = widget.userData['streetName'] ?? 'Street Not Set';
    String landmark = widget.userData['landmark'] ?? '';
    String displayLocation = "$exactAddress\n$streetName${landmark.isNotEmpty ? '\nLandmark: $landmark' : ''}";

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
                  CircleAvatar(radius: 45, backgroundColor: Colors.teal.shade100, backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null, child: profileUrl.isEmpty ? const Icon(Icons.corporate_fare, size: 40, color: Colors.teal) : null),
                  if (isUploading) const CircularProgressIndicator(color: Colors.teal),
                  if (!isUploading) CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 18, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0), onPressed: _showEditProfileSheet, icon: const Icon(Icons.edit, size: 18), label: const Text("Edit Profile"))
          ],
        ),
        const SizedBox(height: 20),

        if (widget.userData['isVerified'] == true)
          Align(alignment: Alignment.centerLeft, child: _buildDistributorBadge(currentType)),

        const SizedBox(height: 10),
        Text(widget.userData['distributorName'] ?? widget.userData['ngoName'] ?? 'Distributor Name', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(widget.userData['contact'] ?? 'No Phone Number Saved', style: const TextStyle(color: Colors.grey, fontSize: 16)),

        const SizedBox(height: 30),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(leading: const Icon(Icons.inventory_2, color: Colors.teal), title: const Text("Storage Capacity"), trailing: Text(widget.userData['storageCapacity'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.people, color: Colors.blue), title: const Text("Volunteers"), trailing: Text(widget.userData['volunteerCount'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              const Divider(height: 0),
              ListTile(
                  leading: const Icon(Icons.home, color: Colors.orange),
                  title: const Text("Location Hub"),
                  subtitle: Text(displayLocation, style: const TextStyle(fontWeight: FontWeight.bold))
              ),
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