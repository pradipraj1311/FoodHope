import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../../services/gaminfication_engine.dart';
import '../../../services/needy_spots_service.dart';

class ActiveDeliveryCard extends StatefulWidget {
  final String volunteerUid;
  const ActiveDeliveryCard({super.key, required this.volunteerUid});

  @override
  State<ActiveDeliveryCard> createState() => _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends State<ActiveDeliveryCard> {
  final TextEditingController _otpController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _completePickup(String donationId, String correctOtp) async {
    if (_otpController.text.trim() == correctOtp) {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Picked Up',
        'pickedUpAt': FieldValue.serverTimestamp(),
      });
      _otpController.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verified! Choose where to deliver food.")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN!"), backgroundColor: Colors.red));
    }
  }

  Future<void> _emergencyBypass(String donationId, Map<String, dynamic> data) async {
    if (data['otpBypass'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bypass already used for this rescue.")));
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("OTP Bypass"),
        content: const Text("Use this ONLY if the donor is unavailable. This is logged for security."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("BYPASS")),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Picked Up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'otpBypass': true,
      });
    }
  }

  Future<void> _requestNgo(String donationId, Map<String, dynamic> spot) async {
    setState(() => _isProcessing = true);
    
    // Senior Dev Logic: Auto-transition for mock spots (Welfare homes/Labor camps)
    // since they don't have an app to "Accept" the rescue.
    bool isMockSpot = spot['ngoUid'] == null;
    
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': isMockSpot ? 'En Route' : 'NGO Requested',
      'selectedNgoId': spot['ngoUid'] ?? spot['name'], 
      'selectedNgoName': spot['name'],
      'selectedNgoPhone': spot['phone'] ?? '',
      'requestedAt': FieldValue.serverTimestamp(),
    });
    setState(() => _isProcessing = false);
  }

  Future<void> _markDelivered(String donationId, Map<String, dynamic> data) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);
    
    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery proof photo is mandatory!")));
      return;
    }

    String base64Photo = base64Encode(await image.readAsBytes());

    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Delivered',
      'deliveryProofPhoto': base64Photo,
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    await GamificationEngine.processVolunteerDelivery(uid: widget.volunteerUid, mealQuantity: data['quantity']);
    await GamificationEngine.processDonorDonation(uid: data['donorUid'], quantity: data['quantity']);
    
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("RESCUE COMPLETED! 🏆"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('donations').where('volunteerUid', isEqualTo: widget.volunteerUid).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
        var active = snapshot.data!.docs.where((d) => ['Accepted', 'Picked Up', 'NGO Requested', 'En Route'].contains(d['status'])).toList();
        if (active.isEmpty) return const SizedBox.shrink();

        var donation = active.first;
        Map<String, dynamic> data = donation.data() as Map<String, dynamic>;
        String status = data['status'];
        String donationId = donation.id;

        String displayAddress = data['fullAddress'] ?? "${data['exactAddress'] ?? ''}, ${data['city'] ?? ''}";

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.15), blurRadius: 20)],
            border: Border.all(color: Colors.green.shade100, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("MISSION: $status", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11)),
                  if (status == 'Accepted') 
                    IconButton(icon: const Icon(Icons.help_outline, size: 16), onPressed: () => _emergencyBypass(donationId, data))
                ],
              ),
              const SizedBox(height: 5),
              Text(data['foodItem'] ?? 'Food', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Text("PICKUP FROM:", style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(displayAddress, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              const Divider(height: 25),

              if (status == 'Accepted') ...[
                const Text("Ask Donor for 4-Digit PIN:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _otpController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "PIN", border: OutlineInputBorder()))),
                    const SizedBox(width: 10),
                    ElevatedButton(onPressed: () => _completePickup(donationId, data['pickupOtp']), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("VERIFY", style: TextStyle(color: Colors.white)))
                  ],
                )
              ] 
              else if (status == 'Picked Up') ...[
                const Text("SELECT DELIVERY HUB / SPOT Nearby:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'NGO').where('isVerified', isEqualTo: true).snapshots(),
                    builder: (context, ngoSnap) {
                      List<Map<String, dynamic>> spots = NeedySpotsService.getNearbySpots(data['latitude'], data['longitude']);
                      if (ngoSnap.hasData) {
                        for (var doc in ngoSnap.data!.docs) {
                          var ngo = doc.data() as Map<String, dynamic>;
                          if (doc.id == data['donorUid']) continue; // Can't deliver back to donor hub
                          spots.add({
                            'name': ngo['organizationName'] ?? 'NGO Hub',
                            'ngoUid': doc.id,
                            'phone': ngo['contact'] ?? '',
                            'type': 'Verified Hub',
                            'distKm': 0.0 
                          });
                        }
                      }
                      return ListView.builder(
                        itemCount: spots.length,
                        itemBuilder: (context, i) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(spots[i]['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text(spots[i]['type'], style: const TextStyle(fontSize: 10)),
                          trailing: ElevatedButton(
                            onPressed: _isProcessing ? null : () => _requestNgo(donationId, spots[i]),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(horizontal: 10)),
                            child: const Text("SELECT", style: TextStyle(fontSize: 10, color: Colors.white)),
                          ),
                        ),
                      );
                    }
                  ),
                )
              ]
              else if (status == 'NGO Requested') ...[
                Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                      const SizedBox(height: 15),
                      Text("Waiting for ${data['selectedNgoName']} to accept...", textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                      const SizedBox(height: 10),
                      if (data['selectedNgoPhone'] != null && data['selectedNgoPhone'] != '') 
                        ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse("tel:${data['selectedNgoPhone']}")),
                          icon: const Icon(Icons.call, size: 18),
                          label: const Text("CALL HUB"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        )
                    ],
                  ),
                )
              ]
              else if (status == 'En Route') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("NGO ACCEPTED - PROCEED TO DELIVERY 🚀", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 10)),
                      const SizedBox(height: 8),
                      Text("HUB: ${data['selectedNgoName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 10),
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _markDelivered(donationId, data), icon: const Icon(Icons.camera_alt), label: const Text("DELIVERED (UPLOAD PROOF)"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)))
                    ],
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }
}
