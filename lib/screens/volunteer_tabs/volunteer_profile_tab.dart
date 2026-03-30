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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Picture Updated!")));
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
        text: text,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
      ),
    );
  }

  void _showEditProfileSheet() {
    TextEditingController nameController = TextEditingController(text: widget.userData['name']);
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact']);

    // EXACT LOCATION CONTROLLERS
    TextEditingController exactAddressController = TextEditingController(text: widget.userData['exactAddress'] ?? '');
    TextEditingController streetController = TextEditingController(text: widget.userData['streetName'] ?? '');
    TextEditingController landmarkController = TextEditingController(text: widget.userData['landmark'] ?? '');

    List<String> ageOptions = List.generate(68, (index) => (13 + index).toString());
    String currentAgeStr = widget.userData['age']?.toString() ?? '18';
    String selectedAge = ageOptions.contains(currentAgeStr) && currentAgeStr != '0' ? currentAgeStr : '18';

    List<String> genderOptions = ['Male', 'Female', 'Other'];
    String selectedGender = widget.userData['gender'] ?? genderOptions[0];
    if (!genderOptions.contains(selectedGender)) selectedGender = genderOptions[0];

    List<String> foodOptions = ['Any Food (Veg & Non-Veg)', 'Veg Only', 'Non-Veg Only'];
    String selectedFood = widget.userData['foodPreference'] ?? foodOptions[0];
    if (!foodOptions.contains(selectedFood)) selectedFood = foodOptions[0];

    List<String> storageOptions = ['Backpack / Small Bag', 'Bike Box / Large Bag', 'Car Trunk', 'Large Van'];
    String selectedStorage = widget.userData['storageCapacity'] ?? storageOptions[0];
    if (!storageOptions.contains(selectedStorage)) selectedStorage = storageOptions[0];

    List<String> rangeOptions = ['Up to 3 km', 'Up to 5 km', 'Up to 10 km', 'Up to 20 km', 'Up to 30 km', 'Anywhere in City'];
    String selectedRange = widget.userData['travelRange'] ?? rangeOptions[1];
    if (!rangeOptions.contains(selectedRange)) selectedRange = rangeOptions[1];

    List<String> timeOptions = ['Anytime', 'Mornings (8AM - 12PM)', 'Afternoons (12PM - 4PM)', 'Evenings (4PM - 8PM)', 'Night (After 8PM)'];
    String selectedTime = widget.userData['bestTime'] ?? timeOptions[0];
    if (!timeOptions.contains(selectedTime)) selectedTime = timeOptions[0];

    bool isAffiliated = false;
    if (widget.userData['isAffiliatedWithNgo'] is bool) {
      isAffiliated = widget.userData['isAffiliatedWithNgo'];
    }

    String initialNgo = widget.userData['affiliatedNgoName'] ?? '';
    if (initialNgo == 'Independent') initialNgo = '';
    TextEditingController ngoController = TextEditingController(text: initialNgo);

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
                  children: [
                    const Text("Edit Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),

                    TextField(controller: nameController, decoration: InputDecoration(label: _requiredLabel("Full Name"), border: const OutlineInputBorder())),
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
                            items: genderOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                            onChanged: (val) => setModalState(() => selectedGender = val!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(label: _requiredLabel("Phone/Contact"), border: const OutlineInputBorder())),

                    const Divider(height: 25, thickness: 2),
                    const Text("Exact Location Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),

                    TextField(
                        controller: exactAddressController,
                        decoration: InputDecoration(
                            label: _requiredLabel("Flat / Building / Hostel Name"),
                            hintText: "e.g., L.S. Boys Hostel",
                            border: const OutlineInputBorder()
                        )
                    ),
                    const SizedBox(height: 10),

                    TextField(
                        controller: streetController,
                        decoration: InputDecoration(
                            label: _requiredLabel("Street / Road / Area"),
                            hintText: "e.g., Uttarsanda Road",
                            border: const OutlineInputBorder()
                        )
                    ),
                    const SizedBox(height: 10),

                    TextField(controller: landmarkController, decoration: const InputDecoration(labelText: "Nearby Landmark (Optional)", border: OutlineInputBorder())),

                    const Divider(height: 25, thickness: 2),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Are you delivering for an NGO?", style: TextStyle(fontWeight: FontWeight.bold)),
                      value: isAffiliated,
                      onChanged: (val) => setModalState(() => isAffiliated = val),
                      activeColor: Colors.green,
                    ),
                    if (isAffiliated) ...[
                      TextField(controller: ngoController, decoration: InputDecoration(label: _requiredLabel("Enter NGO Name"), border: const OutlineInputBorder())),
                    ],

                    const Divider(height: 25, thickness: 2),
                    const Text("Delivery Capabilities", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 15),

                    DropdownButtonFormField<String>(
                      value: selectedFood,
                      decoration: InputDecoration(label: _requiredLabel("Food Accepted"), border: const OutlineInputBorder()),
                      items: foodOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedFood = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedStorage,
                      decoration: InputDecoration(label: _requiredLabel("Storage / Transport"), border: const OutlineInputBorder()),
                      items: storageOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedStorage = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedRange,
                      decoration: InputDecoration(label: _requiredLabel("Travel Range"), border: const OutlineInputBorder()),
                      items: rangeOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedRange = val!),
                    ),
                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedTime,
                      decoration: InputDecoration(label: _requiredLabel("Best Time to Deliver"), border: const OutlineInputBorder()),
                      items: timeOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                      onChanged: (val) => setModalState(() => selectedTime = val!),
                    ),

                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                        onPressed: () async {
                          if (nameController.text.isEmpty || phoneController.text.isEmpty || exactAddressController.text.isEmpty || streetController.text.isEmpty || (isAffiliated && ngoController.text.isEmpty)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
                            return;
                          }

                          await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                            'name': nameController.text.trim(),
                            'age': int.parse(selectedAge),
                            'gender': selectedGender,
                            'contact': phoneController.text.trim(),
                            'exactAddress': exactAddressController.text.trim(),
                            'streetName': streetController.text.trim(),
                            'landmark': landmarkController.text.trim(),
                            'foodPreference': selectedFood,
                            'storageCapacity': selectedStorage,
                            'travelRange': selectedRange,
                            'bestTime': selectedTime,
                            'isAffiliatedWithNgo': isAffiliated,
                            'affiliatedNgoName': isAffiliated ? ngoController.text.trim() : "Independent",
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
                  CircleAvatar(radius: 45, backgroundColor: Colors.green.shade100, backgroundImage: profileUrl.isNotEmpty ? NetworkImage(profileUrl) : null, child: profileUrl.isEmpty ? const Icon(Icons.person, size: 50, color: Colors.green) : null),
                  if (isUploading) const CircularProgressIndicator(color: Colors.green),
                  if (!isUploading) CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.camera_alt, size: 18, color: Colors.grey.shade800)),
                ],
              ),
            ),
            ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black87, elevation: 0), onPressed: _showEditProfileSheet, icon: const Icon(Icons.edit, size: 18), label: const Text("Edit Profile"))
          ],
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Text(widget.userData['name'] ?? 'Volunteer Hero', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            // THE VERIFIED VOLUNTEER BADGE
            if (widget.userData['isVerifiedVolunteer'] == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade300), borderRadius: BorderRadius.circular(4)),
                child: Row(children: [Icon(Icons.verified_user, size: 12, color: Colors.green.shade700), const SizedBox(width: 3), Text("Verified", style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold))]),
              ),
          ],
        ),

        Text(widget.userData['contact'] ?? 'No Phone Number', style: const TextStyle(color: Colors.grey, fontSize: 16)),

        if (widget.userData.containsKey('age') && widget.userData.containsKey('gender'))
          Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("${widget.userData['gender']}, ${widget.userData['age']} yrs", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),

        const SizedBox(height: 30),

        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(
                  leading: const Icon(Icons.home, color: Colors.blue),
                  title: const Text("Location Node"),
                  subtitle: Text(displayLocation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))
              ),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.group, color: Colors.orange), title: const Text("Affiliation"), trailing: Text((widget.userData['isAffiliatedWithNgo'] == true) ? widget.userData['affiliatedNgoName'] : "Independent", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.map, color: Colors.green), title: const Text("Range"), trailing: Text(widget.userData['travelRange'] ?? 'Up to 5 km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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