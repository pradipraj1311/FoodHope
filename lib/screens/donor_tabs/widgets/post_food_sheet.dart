import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math';

class PostFoodSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const PostFoodSheet({super.key, required this.userData, required this.uid});

  @override
  State<PostFoodSheet> createState() => _PostFoodSheetState();
}

class _PostFoodSheetState extends State<PostFoodSheet> {
  final TextEditingController foodItemController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  String foodCategory = 'Veg Only';
  String mealType = 'Cooked Meal';
  String sourceType = 'Restaurant';
  String pickupInstruction = 'Front Desk';
  String selectedExpiry = 'Within 2 Hours';
  bool isFlashRescue = false; // NEW: Flash Rescue Flag

  List<String> availableTags = ['Spicy', 'Contains Dairy', 'Jain Food', 'No Onion/Garlic'];
  List<String> selectedTags = [];

  XFile? _foodImage;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);
    if (image != null) setState(() => _foodImage = image);
  }

  Future<void> _publishDonation() async {
    if (foodItemController.text.isEmpty || quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill title and quantity.")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)));

    DateTime now = DateTime.now(); 
    DateTime exactExpiryTime = now;
    if (selectedExpiry.contains('1 Hour')) exactExpiryTime = now.add(const Duration(hours: 1));
    else if (selectedExpiry.contains('2 Hours')) exactExpiryTime = now.add(const Duration(hours: 2));
    else if (selectedExpiry.contains('4 Hours')) exactExpiryTime = now.add(const Duration(hours: 4));
    else exactExpiryTime = DateTime(now.year, now.month, now.day, 23, 59, 59);

    double donorLat = widget.userData['latitude'] ?? 0.0;
    double donorLon = widget.userData['longitude'] ?? 0.0;
    
    // Auto-assign logic stays the same
    QuerySnapshot ngoSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'NGO').get();
    String? bestNgoId; 
    String bestNgoName = "Direct Distribution"; 
    double closestDistance = 9999.0;

    for (var doc in ngoSnapshot.docs) {
      Map<String, dynamic> ngo = doc.data() as Map<String, dynamic>;
      double distKm = Geolocator.distanceBetween(donorLat, donorLon, ngo['latitude'] ?? 0.0, ngo['longitude'] ?? 0.0) / 1000;
      if (distKm < 20.0 && distKm < closestDistance) { 
        closestDistance = distKm; 
        bestNgoId = doc.id; 
        bestNgoName = ngo['organizationName'] ?? 'NGO Hub'; 
      }
    }

    String base64ImageString = '';
    if (_foodImage != null) {
      List<int> imageBytes = await _foodImage!.readAsBytes();
      base64ImageString = base64Encode(imageBytes);
    }

    await FirebaseFirestore.instance.collection('donations').add({
      'donorUid': widget.uid,
      'businessName': widget.userData['businessName'] ?? 'Local Donor',
      'donorContact': widget.userData['contact'] ?? '',
      'fullAddress': widget.userData['fullAddress'] ?? '',
      'latitude': donorLat,
      'longitude': donorLon,
      'foodItem': foodItemController.text.trim(),
      'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
      'category': foodCategory,
      'isFlashRescue': isFlashRescue, // NEW: Mark as Flash Rescue
      'photoUrl': base64ImageString,
      'exactExpiryTime': Timestamp.fromDate(exactExpiryTime),
      'status': 'Available',
      'postedAt': Timestamp.now(),
      'suggestedNgoId': bestNgoId,
      'suggestedNgoName': bestNgoName,
    });

    if (mounted) {
      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Close sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFlashRescue ? "🔥 FLASH RESCUE ACTIVATED!" : "Food Rescue Published!"),
          backgroundColor: isFlashRescue ? Colors.red : Colors.green,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Post Food Rescue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Switch.adaptive(
                  value: isFlashRescue,
                  activeColor: Colors.red,
                  onChanged: (val) => setState(() => isFlashRescue = val),
                ),
              ],
            ),
            if (isFlashRescue)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text("🔥 Flash Rescue notifies nearby volunteers immediately!", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            
            const SizedBox(height: 15),
            TextField(controller: foodItemController, decoration: const InputDecoration(labelText: "What are you donating? (e.g. 20 Lunch Boxes)", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Feeds how many people?", border: OutlineInputBorder())),
            
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: DropdownButtonFormField<String>(value: foodCategory, decoration: const InputDecoration(labelText: "Dietary"), items: ['Veg Only', 'Non-Veg', 'Both'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => foodCategory = v!))),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(value: selectedExpiry, decoration: const InputDecoration(labelText: "Expiry"), items: ['Within 1 Hour', 'Within 2 Hours', 'Within 4 Hours'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => selectedExpiry = v!))),
              ],
            ),

            const SizedBox(height: 20),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 100, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                child: _foodImage == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: Colors.orange), Text("Take Food Photo")])
                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text("Photo Ready")]),
              ),
            ),

            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFlashRescue ? Colors.red.shade700 : Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _publishDonation,
                child: Text(isFlashRescue ? "TRIGGER FLASH RESCUE 🔥" : "Publish Rescue", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
