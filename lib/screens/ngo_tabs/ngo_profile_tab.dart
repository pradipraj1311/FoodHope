import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../landing_screen.dart';
import '../gamification/impact_wrapped_screen.dart';
import 'dart:convert';

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
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to log out of the Hub?"),
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

  void _requestAccountDeletion() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("DELETE HUB ACCOUNT?"),
        content: const Text("Your hub data will be scheduled for deletion. It will be permanently removed after 30 days. If you log back in within this period, the request will be automatically cancelled."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SCHEDULE DELETION", style: TextStyle(color: Colors.red))),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'deletionRequestedAt': FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deletion scheduled. Logging out."), backgroundColor: Colors.orange));
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LandingScreen()), (route) => false);
      }
    }
  }

  void _showReportDialog() {
    final TextEditingController reportController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Report an Issue"),
        content: TextField(
          controller: reportController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: "Describe the issue or suspicious behavior...", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (reportController.text.trim().isNotEmpty) {
                await FirebaseFirestore.instance.collection('reports').add({
                  'reporterUid': widget.uid,
                  'reporterName': widget.userData['organizationName'],
                  'reporterRole': 'NGO',
                  'issue': reportController.text.trim(),
                  'timestamp': FieldValue.serverTimestamp(),
                  'status': 'Open',
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report submitted. Thank you for keeping FoodHope safe!"), backgroundColor: Colors.teal));
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
    TextEditingController nameController = TextEditingController(text: widget.userData['organizationName']);
    TextEditingController phoneController = TextEditingController(text: widget.userData['contact'] ?? '');
    
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Hub Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: nameController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Organization Name")),
            const SizedBox(height: 10),
            TextField(controller: phoneController, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Update Contact Number")),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                    'organizationName': nameController.text.trim(),
                    'contact': phoneController.text.trim(),
                  });
                  widget.onProfileUpdated();
                  if (mounted) Navigator.pop(context);
                },
                child: const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            ListTile(leading: const Icon(Icons.report_problem, color: Colors.orange), title: const Text("Report an Issue"), onTap: () { Navigator.pop(context); _showReportDialog(); }),
            TextButton(onPressed: _requestAccountDeletion, child: const Text("Delete Hub Account Permanently", style: TextStyle(color: Colors.red, fontSize: 12))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    int received = widget.userData['deliveriesReceived'] ?? 0;
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
                    radius: 40, backgroundColor: Colors.teal.shade50,
                    backgroundImage: img.isNotEmpty ? MemoryImage(base64Decode(img)) : null,
                    child: img.isEmpty ? const Icon(Icons.corporate_fare, size: 40, color: Colors.teal) : null,
                  ),
                ),
                const SizedBox(height: 15),
                Text(widget.userData['organizationName'] ?? 'NGO Hub', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(widget.userData['contact'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
                Text("${widget.userData['city'] ?? ''} Hub", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            IconButton(onPressed: _showSettings, icon: const Icon(Icons.settings, color: Colors.blueGrey))
          ],
        ),

        const SizedBox(height: 30),
        Row(
          children: [
            _buildMetricBox("Meals Received", "$received", Icons.inbox, Colors.teal.shade50, Colors.teal.shade700),
            const SizedBox(width: 15),
            _buildMetricBox("Hub Points", "$points", Icons.stars, Colors.amber.shade50, Colors.amber.shade800),
          ],
        ),

        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text("Sign Out of Hub", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade900, elevation: 0),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(String label, String value, IconData icon, Color bg, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 30),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            Text(label, style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
