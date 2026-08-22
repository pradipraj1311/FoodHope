import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
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
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out of your business account?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("LOGOUT", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandingScreen()), (route) => false);
    }
  }

  void _shareImpact() {
    int donations = widget.userData['donationsMade'] ?? 0;
    int worth = donations * 50;
    Share.share("Our business saved food worth ₹$worth through $donations donations on FoodHope! 💓 Join us. https://foodhope.app");
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 25);
      if (pickedFile != null) {
        setState(() => isUploading = true);
        String base64 = base64Encode(await pickedFile.readAsBytes());
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'profileImageUrl': base64});
        widget.onProfileUpdated();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _showSettings() {
    TextEditingController nameController = TextEditingController(text: widget.userData['businessName']);
    TextEditingController contactNameController = TextEditingController(text: widget.userData['primaryContactName'] ?? '');
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact'] ?? '');
    TextEditingController buildingController = TextEditingController(text: widget.userData['exactAddress'] ?? '');
    TextEditingController streetController = TextEditingController(text: widget.userData['streetName'] ?? '');
    TextEditingController socialController = TextEditingController(text: widget.userData['socialMediaLink'] ?? '');
    
    final List<String> donorTypes = ['Restaurant', 'Hotel', 'Hostel Mess', 'Event / Wedding', 'Supermarket', 'Individual / Other'];
    String selectedType = widget.userData['donorType'] ?? donorTypes[0];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: nameController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Business Name")),
                const SizedBox(height: 10),
                TextField(controller: contactNameController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Contact Person")),
                const SizedBox(height: 10),
                TextField(controller: phoneController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Phone Number")),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: donorTypes.contains(selectedType) ? selectedType : donorTypes[0],
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Business Category"),
                  items: donorTypes.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setModalState(() => selectedType = v!),
                ),
                const SizedBox(height: 10),
                TextField(controller: buildingController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Building/Hostel Name")),
                const SizedBox(height: 10),
                TextField(controller: streetController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Street / Area")),
                const SizedBox(height: 10),
                TextField(controller: socialController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Social Page Link")),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                        'businessName': nameController.text.trim(),
                        'primaryContactName': contactNameController.text.trim(),
                        'contact': phoneController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'exactAddress': buildingController.text.trim(),
                        'streetName': streetController.text.trim(),
                        'donorType': selectedType,
                        'socialMediaLink': socialController.text.trim(),
                      });
                      widget.onProfileUpdated();
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(leading: const Icon(Icons.share, color: Colors.blue), title: const Text("Share Impact Certificate"), onTap: () { Navigator.pop(context); _shareImpact(); }),
                TextButton(onPressed: _deleteAccount, child: const Text("Delete Account Permanently", style: TextStyle(color: Colors.red, fontSize: 12))),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(context: context, builder: (context) => AlertDialog(title: const Text("Delete Account?"), content: const Text("This will permanently remove your business data. This cannot be undone."), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Yes", style: TextStyle(color: Colors.red)))])) ?? false;
    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).delete();
      await FirebaseAuth.instance.currentUser?.delete();
      if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandingScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int donations = widget.userData['donationsMade'] ?? 0;
    int points = widget.userData['rankScore'] ?? 0;
    int worth = donations * 50;
    String img = widget.userData['profileImageUrl'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header matching your screenshot perfectly
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 40, backgroundColor: Colors.orange.shade50,
                    backgroundImage: img.isNotEmpty ? MemoryImage(base64Decode(img)) : null,
                    child: img.isEmpty ? const Icon(Icons.business, size: 40, color: Colors.orange) : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(widget.userData['businessName'] ?? 'Donor', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(widget.userData['contact'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Text(widget.userData['city'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showSettings,
              icon: const Icon(Icons.settings, size: 16),
              label: const Text("Settings"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100, 
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
              ),
            )
          ],
        ),

        const SizedBox(height: 25),

        // Impact Wrapped
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImpactWrappedScreen(userData: widget.userData))),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFEA580C), Color(0xFFFB923C)]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Impact Wrapped 2026", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("See your donation vibe check ✨", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Metrics Row: 3 Pastel Boxes
        Row(
          children: [
            _buildMetricBox("Donations", "$donations", Icons.volunteer_activism, Colors.blue.shade50, Colors.blue.shade700),
            const SizedBox(width: 10),
            _buildMetricBox("Points", "$points", Icons.stars, Colors.amber.shade50, Colors.amber.shade800),
            const SizedBox(width: 10),
            _buildMetricBox("Saved Worth", "₹$worth", Icons.currency_rupee, Colors.green.shade50, Colors.green.shade700),
          ],
        ),

        const SizedBox(height: 30),

        // Logout Button (matching screenshot perfectly)
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20),
            label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEBEE),
              foregroundColor: Colors.red.shade900,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 26),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            Text(label, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
