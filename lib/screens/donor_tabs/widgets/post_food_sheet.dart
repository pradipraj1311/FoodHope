import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // REQUIRED FOR BASE64
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

  List<String> availableTags = ['Spicy', 'Contains Dairy', 'Jain Food', 'No Onion/Garlic'];
  List<String> selectedTags = [];

  XFile? _foodImage;

  // --- STRICT LIVE CAMERA ONLY & LOW QUALITY TO KEEP TEXT SMALL ---
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera, // Blocks gallery uploads
      imageQuality: 25,           // Compresses image heavily
    );
    if (image != null) setState(() => _foodImage = image);
  }

  Future<void> _publishDonation() async {
    if (foodItemController.text.isEmpty || quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill title and quantity.")));
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orange)));

    DateTime now = DateTime.now(); DateTime exactExpiryTime = now;
    if (selectedExpiry.contains('1 Hour')) exactExpiryTime = now.add(const Duration(hours: 1));
    else if (selectedExpiry.contains('2 Hours')) exactExpiryTime = now.add(const Duration(hours: 2));
    else if (selectedExpiry.contains('4 Hours')) exactExpiryTime = now.add(const Duration(hours: 4));
    else exactExpiryTime = DateTime(now.year, now.month, now.day, 23, 59, 59);

    double donorLat = widget.userData['latitude'] ?? 0.0;
    double donorLon = widget.userData['longitude'] ?? 0.0;
    QuerySnapshot ngoSnapshot = await FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'NGO').get();

    String? bestNgoId; String bestNgoName = "Direct Distribution (No Hubs)"; double closestDistance = 9999.0;

    for (var doc in ngoSnapshot.docs) {
      Map<String, dynamic> ngo = doc.data() as Map<String, dynamic>;
      if ((ngo['foodPreference'] ?? 'Any') == 'Veg Only' && (foodCategory == 'Non-Veg' || foodCategory == 'Both (Mixed)')) continue;
      double distKm = Geolocator.distanceBetween(donorLat, donorLon, ngo['latitude'] ?? 0.0, ngo['longitude'] ?? 0.0) / 1000;
      if (distKm < 20.0 && distKm < closestDistance) { closestDistance = distKm; bestNgoId = doc.id; bestNgoName = ngo['distributorName'] ?? ngo['ngoName'] ?? 'NGO Hub'; }
    }

    if (mounted) Navigator.pop(context);

    if (bestNgoId == null && mounted) {
      bool? proceed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text("No Hubs Nearby ⚠️"), content: const Text("Volunteers will distribute this directly. Proceed?"), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("Publish"))]));
      if (proceed != true) return;
    }

    String generatedOtp = (1000 + Random().nextInt(9000)).toString();

    // --- THE BASE64 HACK CONVERSION ---
    String base64ImageString = '';
    if (_foodImage != null) {
      List<int> imageBytes = await _foodImage!.readAsBytes();
      base64ImageString = base64Encode(imageBytes);
    }

    await FirebaseFirestore.instance.collection('donations').add({
      'donorUid': widget.uid, 'businessName': widget.userData['businessName'] ?? 'Local Donor', 'donorContact': widget.userData['contact'] ?? '',
      'fullAddress': widget.userData['fullAddress'] ?? '', 'latitude': donorLat, 'longitude': donorLon, 'city': widget.userData['city'] ?? 'Unknown',

      'foodItem': foodItemController.text.trim(),
      'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
      'category': foodCategory,
      'mealType': mealType,
      'sourceType': sourceType,
      'pickupInstruction': pickupInstruction,
      'specialTags': selectedTags,
      'hasPhoto': _foodImage != null,

      'photoUrl': base64ImageString, // SAVING THE TEXT STRING

      'exactExpiryTime': Timestamp.fromDate(exactExpiryTime), 'status': 'Available', 'postedAt': Timestamp.now(),
      'pickupOtp': generatedOtp, 'suggestedNgoId': bestNgoId, 'suggestedNgoName': bestNgoName,
    });

    if (mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food Rescue Published!"))); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Post Food Rescue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 15),

            Row(children: [Expanded(flex: 2, child: TextField(controller: foodItemController, decoration: const InputDecoration(labelText: "Title (e.g. 50 Rotis)", border: OutlineInputBorder()))), const SizedBox(width: 10), Expanded(flex: 1, child: TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Feeds?", border: OutlineInputBorder())))]), const SizedBox(height: 10),
            Row(children: [Expanded(child: DropdownButtonFormField<String>(value: mealType, decoration: const InputDecoration(labelText: "Meal Type", border: OutlineInputBorder()), items: ['Cooked Meal', 'Packaged', 'Raw'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => mealType = v!))), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<String>(value: foodCategory, decoration: const InputDecoration(labelText: "Dietary", border: OutlineInputBorder()), items: ['Veg Only', 'Non-Veg', 'Both (Mixed)'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => foodCategory = v!)))]), const SizedBox(height: 15),

            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 80, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                child: _foodImage == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt, color: Colors.orange), Text("Tap to take Live Photo", style: TextStyle(color: Colors.grey, fontSize: 12))])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 8), Text("Photo Attached", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold))]),
              ),
            ), const SizedBox(height: 15),

            const Text("Special Tags:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            Wrap(
              spacing: 8,
              children: availableTags.map((tag) => FilterChip(
                label: Text(tag, style: const TextStyle(fontSize: 11)),
                selected: selectedTags.contains(tag),
                selectedColor: Colors.orange.shade200,
                onSelected: (bool selected) { setState(() { selected ? selectedTags.add(tag) : selectedTags.remove(tag); }); },
              )).toList(),
            ), const SizedBox(height: 15),

            Row(children: [Expanded(child: DropdownButtonFormField<String>(value: sourceType, decoration: const InputDecoration(labelText: "Source", border: OutlineInputBorder()), items: ['Home', 'Restaurant', 'Hostel', 'Event'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => sourceType = v!))), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<String>(value: pickupInstruction, decoration: const InputDecoration(labelText: "Pickup At", border: OutlineInputBorder()), items: ['Front Desk', 'Gate', 'Security', 'Call Me'].map((v) => DropdownMenuItem(value: v, child: Text(v, style: const TextStyle(fontSize: 12)))).toList(), onChanged: (v) => setState(() => pickupInstruction = v!)))]), const SizedBox(height: 10),
            DropdownButtonFormField<String>(value: selectedExpiry, decoration: const InputDecoration(labelText: "Pickup Deadline", border: OutlineInputBorder()), items: ['Within 1 Hour', 'Within 2 Hours', 'Within 4 Hours'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (val) => setState(() => selectedExpiry = val!)), const SizedBox(height: 25),

            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white), onPressed: _publishDonation, child: const Text("Publish Donation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))))
          ],
        ),
      ),
    );
  }
}