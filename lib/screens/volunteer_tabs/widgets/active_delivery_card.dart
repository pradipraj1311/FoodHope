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

  Future<void> _openMap(double lat, double lon) async {
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maps unavailable")));
    }
  }

  Future<void> _completePickup(String donationId, String correctOtp) async {
    if (_otpController.text.trim() == correctOtp) {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Picked Up',
        'pickedUpAt': FieldValue.serverTimestamp(),
      });
      _otpController.clear();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN"), backgroundColor: Colors.red));
    }
  }

  Future<void> _emergencyBypass(String donationId, bool userHasUsedBypass) async {
    if (userHasUsedBypass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emergency bypass limit reached (1 time per user).")));
      return;
    }

    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("One-Time Bypass"),
        content: const Text("Use this ONLY if the donor is unavailable. You can only use this ONCE in your lifetime. This is logged for audit."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("USE BYPASS")),
        ],
      )
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Picked Up',
        'pickedUpAt': FieldValue.serverTimestamp(),
        'otpBypassUsed': true,
      });
      // Lock the volunteer from ever using it again
      await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).update({
        'hasUsedEmergencyBypass': true,
      });
    }
  }

  Future<void> _requestNgo(String donationId, Map<String, dynamic> spot) async {
    setState(() => _isProcessing = true);
    bool isMockSpot = spot['ngoUid'] == null;
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': isMockSpot ? 'En Route' : 'NGO Requested',
      'selectedNgoId': spot['ngoUid'] ?? spot['name'], 
      'selectedNgoName': spot['name'],
      'selectedNgoPhone': spot['phone'] ?? '',
      'selectedNgoLat': spot['lat'],
      'selectedNgoLon': spot['lon'],
      'requestedAt': FieldValue.serverTimestamp(),
    });
    setState(() => _isProcessing = false);
  }

  Future<void> _markDelivered(String donationId, Map<String, dynamic> data) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);
    if (image == null) return;
    
    String base64Photo = base64Encode(await image.readAsBytes());
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Delivered',
      'deliveryProofPhoto': base64Photo,
      'deliveredAt': FieldValue.serverTimestamp(),
    });

    await GamificationEngine.processVolunteerDelivery(uid: widget.volunteerUid, mealQuantity: data['quantity']);
    await GamificationEngine.processDonorDonation(uid: data['donorUid'], quantity: data['quantity']);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).snapshots(),
      builder: (context, userSnapshot) {
        // SENIOR DEV FIX: Safe access to avoid Red Screen error for old users
        bool hasUsedBypass = false;
        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          final data = userSnapshot.data!.data() as Map<String, dynamic>?;
          hasUsedBypass = data?['hasUsedEmergencyBypass'] ?? false;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('donations').where('volunteerUid', isEqualTo: widget.volunteerUid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
            
            var active = snapshot.data!.docs.where((d) {
              final data = d.data() as Map<String, dynamic>?;
              String s = data?['status'] ?? '';
              // Senior Dev Expiry & Completion Filter
              if (['Delivered', 'Expired', 'Cancelled'].contains(s)) return false;
              if (data?['exactExpiryTime'] != null) {
                if ((data?['exactExpiryTime'] as Timestamp).toDate().isBefore(DateTime.now())) return false;
              }
              return ['Accepted', 'Picked Up', 'NGO Requested', 'En Route'].contains(s);
            }).toList();

            if (active.isEmpty) return const SizedBox.shrink();

            var donation = active.first;
            Map<String, dynamic> data = donation.data() as Map<String, dynamic>;
            String status = data['status'] ?? '';
            bool isNonVeg = data['foodType'] == 'Non-Veg';

            return Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isNonVeg ? Colors.red.shade100 : Colors.green.shade100, width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("MISSION: $status", style: TextStyle(fontWeight: FontWeight.bold, color: isNonVeg ? Colors.red : Colors.green, fontSize: 10)),
                      IconButton(icon: const Icon(Icons.map, size: 20, color: Colors.blue), onPressed: () => _openMap(data['latitude'] ?? 0.0, data['longitude'] ?? 0.0)),
                    ],
                  ),
                  Text(data['foodItem'] ?? 'Food', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => _openMap(data['latitude'] ?? 0.0, data['longitude'] ?? 0.0),
                    child: Text("📍 PICKUP: ${data['fullAddress'] ?? 'View on Map'}", style: const TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)),
                  ),
                  const Divider(height: 25),

                  if (status == 'Accepted') ...[
                    const Text("Enter PIN from Donor:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _otpController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "PIN", border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        ElevatedButton(onPressed: () => _completePickup(donation.id, data['pickupOtp'] ?? ''), child: const Text("VERIFY"))
                      ],
                    ),
                    if (!hasUsedBypass)
                      TextButton(onPressed: () => _emergencyBypass(donation.id, hasUsedBypass), child: const Text("Can't get PIN? (One-time usage)", style: TextStyle(fontSize: 10, color: Colors.grey))),
                  ] 
                  else if (status == 'Picked Up') ...[
                    const Text("SELECT DESTINATION:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    SizedBox(
                      height: 150,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'NGO').where('isVerified', isEqualTo: true).snapshots(),
                        builder: (context, ngoSnap) {
                          List<Map<String, dynamic>> spots = NeedySpotsService.getNearbySpots(data['latitude'] ?? 0.0, data['longitude'] ?? 0.0);
                          if (ngoSnap.hasData) {
                            for (var doc in ngoSnap.data!.docs) {
                              var ngo = doc.data() as Map<String, dynamic>;
                              if (doc.id == data['donorUid']) continue; 
                              if (isNonVeg && (ngo['isVegOnly'] ?? false) == true) continue;
                              spots.add({'name': ngo['organizationName'] ?? 'NGO', 'ngoUid': doc.id, 'phone': ngo['contact'] ?? '', 'type': 'Hub', 'lat': ngo['latitude'] ?? 0.0, 'lon': ngo['longitude'] ?? 0.0});
                            }
                          }
                          return ListView.builder(
                            itemCount: spots.length,
                            itemBuilder: (context, i) => ListTile(
                              title: Text(spots[i]['name'] ?? 'Spot', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text(spots[i]['type'] ?? 'Unknown', style: const TextStyle(fontSize: 10)),
                              trailing: ElevatedButton(onPressed: () => _requestNgo(donation.id, spots[i]), child: const Text("CHOOSE", style: TextStyle(fontSize: 10))),
                              onTap: () => _openMap(spots[i]['lat'] ?? 0.0, spots[i]['lon'] ?? 0.0),
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
                          const CircularProgressIndicator(strokeWidth: 2),
                          const SizedBox(height: 10),
                          Text("Waiting for ${data['selectedNgoName']}...", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => launchUrl(Uri.parse("tel:${data['selectedNgoPhone'] ?? ''}"))),
                              IconButton(icon: const Icon(Icons.map, color: Colors.blue), onPressed: () => _openMap(data['selectedNgoLat'] ?? 0.0, data['selectedNgoLon'] ?? 0.0)),
                            ],
                          )
                        ],
                      ),
                    )
                  ]
                  else if (status == 'En Route') ...[
                    Text("DELIVERING TO: ${data['selectedNgoName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _openMap(data['selectedNgoLat'] ?? 0.0, data['selectedNgoLon'] ?? 0.0),
                      child: const Text("📍 Open Destination in Maps", style: TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => _markDelivered(donation.id, data), icon: const Icon(Icons.camera_alt), label: const Text("ARRIVED & DELIVERED"), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)))
                  ]
                ],
              ),
            );
          },
        );
      }
    );
  }
}
