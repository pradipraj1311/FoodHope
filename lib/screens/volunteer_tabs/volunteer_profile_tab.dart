import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
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
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
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
    int rescues = widget.userData['deliveriesMade'] ?? 0;
    int worth = rescues * 50;
    Share.share("I saved food worth ₹$worth on FoodHope! 💓 Join me in fighting hunger. https://foodhope.app");
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
      debugPrint("Upload Failed: $e");
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  void _requestAccountDeletion() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("DELETE ACCOUNT?"),
        content: const Text("Your account will be scheduled for deletion. It will be permanently removed after 30 days. If you log back in within this period, the request will be automatically cancelled."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("DELETE", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account deletion requested. Logging out."), backgroundColor: Colors.orange));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandingScreen()), (route) => false);
      }
    }
  }

  void _showReportDialog() {
    final TextEditingController reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report an Issue / User"),
        content: TextField(
          controller: reportController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: "Describe the issue or user behavior...", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (reportController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reporterUid': widget.uid,
                  'reporterName': widget.userData['name'],
                  'reporterRole': 'Volunteer',
                  'issue': reportController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'Open',
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted successfully."), backgroundColor: Colors.teal));
                }
              }
            },
            child: const Text("SUBMIT"),
          )
        ],
      ),
    );
  }

  void _showSettings() {
    TextEditingController nameController = TextEditingController(text: widget.userData['name']);
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact'] ?? '');
    List<String> vehicleOptions = ['Bicycle', 'Scooter / Motorcycle', 'Car', 'Walking'];
    String selectedVehicle = widget.userData['vehicleType'] ?? vehicleOptions[1];

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Profile Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: nameController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Name")),
              const SizedBox(height: 10),
              TextField(controller: phoneController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Phone")),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: vehicleOptions.contains(selectedVehicle) ? selectedVehicle : vehicleOptions[1],
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Transport"),
                items: vehicleOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (v) => setModalState(() => selectedVehicle = v!),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                      'name': nameController.text.trim(),
                      'contact': phoneController.text.trim(),
                      'vehicleType': selectedVehicle,
                    });
                    widget.onProfileUpdated();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),
              ListTile(leading: const Icon(Icons.share, color: Colors.blue), title: const Text("Share Impact"), onTap: () { Navigator.pop(context); _shareImpact(); }),
              ListTile(leading: const Icon(Icons.report_problem, color: Colors.orange), title: const Text("Report User / Issue"), onTap: () { Navigator.pop(context); _showReportDialog(); }),
              TextButton(onPressed: _requestAccountDeletion, child: const Text("Delete Account Permanently", style: TextStyle(color: Colors.red, fontSize: 12))),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int rescues = widget.userData['deliveriesMade'] ?? 0;
    int points = widget.userData['rankScore'] ?? 0;
    String img = widget.userData['profileImageUrl'] ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
                    radius: 45, backgroundColor: Colors.grey.shade100,
                    backgroundImage: img.isNotEmpty ? MemoryImage(base64Decode(img)) : null,
                    child: img.isEmpty ? const Icon(Icons.person, size: 45, color: Colors.grey) : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(widget.userData['name'] ?? 'Volunteer', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(widget.userData['city'] ?? 'Nadiad', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings, color: Colors.blueGrey))
          ],
        ),

        const SizedBox(height: 25),
        
        // Honorary Badges Section
        const Text("HONORARY BADGES 🎖️", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (rescues >= 1) _badgeChip("Bronze Lifesaver", Colors.orange.shade700),
            if (rescues >= 10) _badgeChip("Silver Guardian", Colors.blueGrey),
            if (rescues >= 50) _badgeChip("Gold Champion", Colors.amber.shade700),
            if (points >= 2000) _badgeChip("Emerald Legend", Colors.teal),
            if (rescues == 0) const Text("Complete a rescue to earn your first badge!", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),

        const SizedBox(height: 30),

        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ImpactWrappedScreen(userData: widget.userData))),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF8B0000), Color(0xFFB22222)]),
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
                      Text("See your rescue vibe check ✨", style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          children: [
            _buildMetricBox("Rescues", "$rescues", Icons.local_shipping, Colors.blue.shade50, Colors.blue.shade700),
            const SizedBox(width: 10),
            _buildMetricBox("Rank Pts", "$points", Icons.stars, Colors.amber.shade50, Colors.amber.shade800),
          ],
        ),

        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade900, elevation: 0),
          ),
        ),
      ],
    );
  }

  Widget _badgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.5))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            Text(label, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
