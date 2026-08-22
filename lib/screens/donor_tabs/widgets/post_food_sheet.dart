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
  final TextEditingController notesController = TextEditingController();
  
  String foodType = 'Veg'; 
  String? _foodPhotoBase64;
  bool isProcessing = false;

  Future<void> _pickPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 30);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _foodPhotoBase64 = base64Encode(bytes);
      });
    }
  }

  // Senior Dev: Advanced Address Deduplication
  String _formatFullAddress() {
    String business = (widget.userData['businessName'] ?? '').trim();
    String addr = (widget.userData['exactAddress'] ?? '').trim();
    String street = (widget.userData['streetName'] ?? '').trim();
    String city = (widget.userData['city'] ?? '').trim();

    List<String> rawParts = [business, addr, street, city];
    List<String> cleanParts = [];
    
    for (var part in rawParts) {
      if (part.isEmpty) continue;
      
      bool isDuplicate = false;
      String lowerPart = part.toLowerCase();
      
      for (var existing in cleanParts) {
        String lowerExisting = existing.toLowerCase();
        // Check if the current part is inside an existing part OR vice versa
        if (lowerExisting.contains(lowerPart) || lowerPart.contains(lowerExisting)) {
          isDuplicate = true;
          // If the new part is longer/more detailed, replace the existing one
          if (lowerPart.contains(lowerExisting) && lowerPart.length > lowerExisting.length) {
            int index = cleanParts.indexOf(existing);
            cleanParts[index] = part;
          }
          break;
        }
      }
      
      if (!isDuplicate) {
        cleanParts.add(part);
      }
    }
    return cleanParts.join(', ');
  }

  Future<void> _publishDonation() async {
    if (foodItemController.text.isEmpty || quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill basic food details")));
      return;
    }
    setState(() => isProcessing = true);

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      DateTime now = DateTime.now(); 
      DateTime expiry = now.add(const Duration(hours: 4)); 

      double donorLat = (widget.userData['latitude'] ?? 0.0).toDouble();
      double donorLon = (widget.userData['longitude'] ?? 0.0).toDouble();
      
      String pin = (1000 + Random().nextInt(9000)).toString();
      String fullAddr = _formatFullAddress();

      await FirebaseFirestore.instance.collection('donations').add({
        'donorUid': widget.uid,
        'donorPhone': widget.userData['contact'] ?? '',
        'businessName': widget.userData['businessName'] ?? widget.userData['name'] ?? 'Donor',
        'fullAddress': fullAddr,
        'city': widget.userData['city'],
        'latitude': donorLat,
        'longitude': donorLon,
        'foodItem': foodItemController.text.trim(),
        'foodType': foodType,
        'foodPhoto': _foodPhotoBase64,
        'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
        'notes': notesController.text.trim(),
        'exactExpiryTime': Timestamp.fromDate(expiry),
        'status': 'Available',
        'postedAt': FieldValue.serverTimestamp(),
        'pickupOtp': pin,
      });

      if (mounted) {
        Navigator.pop(context); 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rescue is Live! 🚀 Thank you."), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text("Post Surplus Food", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange))),
            const SizedBox(height: 20),
            TextField(controller: foodItemController, decoration: const InputDecoration(labelText: "Food Items*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))))),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Est. People Fed*", border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))))),
                const SizedBox(width: 15),
                DropdownButton<String>(
                  value: foodType,
                  items: ['Veg', 'Non-Veg'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setState(() => foodType = v!),
                ),
              ],
            ),
            const SizedBox(height: 15),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 60, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
                child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt, color: Colors.orange), const SizedBox(width: 10), Text(_foodPhotoBase64 == null ? "Add Food Photo" : "Photo Captured ✅")])),
              ),
            ),
            const SizedBox(height: 25),
            SizedBox(width: double.infinity, height: 60, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: isProcessing ? null : _publishDonation, child: const Text("PUBLISH RESCUE", style: TextStyle(fontWeight: FontWeight.bold)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
