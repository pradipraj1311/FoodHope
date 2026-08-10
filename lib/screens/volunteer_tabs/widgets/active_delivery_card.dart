import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) await launchUrl(launchUri);
  }

  Future<void> _openGoogleMaps(double lat, double lon) async {
    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon";
    if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
      await launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
    }
  }

  // --- STEP 1: PICKUP VERIFICATION (Donor gets points here) ---
  Future<void> _verifyOtpAndPickup(String donationId, String correctOtp, String donorUid) async {
    if (_otpController.text.trim() != correctOtp) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid PIN! Ask the donor for the 4-digit code."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);
    
    try {
      // 1. Update Donation Status
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Picked Up',
        'pickedUpAt': FieldValue.serverTimestamp(),
      });

      // 2. Award Points to Donor Instantly
      await FirebaseFirestore.instance.collection('users').doc(donorUid).update({
        'rankScore': FieldValue.increment(20),
        'donationsMade': FieldValue.increment(1),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Pickup Confirmed! Donor rewarded with 20 pts."), backgroundColor: Colors.green));
      }
    } catch (e) {
       debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
      _otpController.clear();
    }
  }

  // --- STEP 2A: REQUEST NGO DROP-OFF ---
  Future<void> _requestNgoDropoff(String donationId, String ngoId, String ngoName) async {
    setState(() => _isProcessing = true);
    
    try {
      DocumentSnapshot vDoc = await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).get();
      Map<String, dynamic> vData = vDoc.data() as Map<String, dynamic>;

      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'NGO Requested',
        'selectedNgoId': ngoId,
        'selectedNgoName': ngoName,
        'volunteerName': vData['name'] ?? 'Hero',
        'volunteerContact': vData['contact'] ?? '',
        'volunteerLatitude': (vData['latitude'] ?? 0.0).toDouble(),
        'volunteerLongitude': (vData['longitude'] ?? 0.0).toDouble(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request sent! Hub will notify you when ready."), backgroundColor: Colors.blue));
      }
    } catch (e) {
       debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- STEP 2B: COMPLETE DROP-OFF (Photo Required) ---
  Future<void> _completeWithPhoto(String donationId, String type, String destinationName, String? ngoId) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);

    if (photo != null) {
      setState(() => _isProcessing = true);
      try {
        List<int> imageBytes = await photo.readAsBytes();
        String base64Proof = base64Encode(imageBytes);

        await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
          'status': 'Completed',
          'dropoffTime': FieldValue.serverTimestamp(),
          'photoProofUrl': base64Proof,
          'actualDestination': destinationName,
          'destinationType': type,
        });

        // Reward logic
        int points = (type == 'NGO') ? 30 : (type == 'Labor Colony' ? 50 : 60);

        await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).update({
          'rankScore': FieldValue.increment(points),
          'deliveriesMade': FieldValue.increment(1),
        });

        if (ngoId != null && type == 'NGO') {
          await FirebaseFirestore.instance.collection('users').doc(ngoId).update({
            'rankScore': FieldValue.increment(10),
            'deliveriesReceived': FieldValue.increment(1),
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Successful Delivery to $destinationName! You earned $points PTS! 🛡️"),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        debugPrint("Error: $e");
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  void _showDestinationPicker(BuildContext context, String donationId, double vLat, double vLon, String? suggestedNgoId, String? suggestedNgoName) {
    List<Map<String, dynamic>> nearbyNeedy = NeedySpotsService.getNearbySpots(vLat, vLon);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Drop-off Location", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Direct help to people in need gives maximum rewards! 🛡️", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text("Please call the number below to confirm food requirement before traveling.", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: ListView(
                  children: [
                    const Text("LABOR, ORPHANAGES & SHELTERS", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...nearbyNeedy.map((spot) {
                      IconData icon = Icons.engineering;
                      Color color = Colors.orange;
                      if (spot['type'] == 'Orphanage') { icon = Icons.child_care; color = Colors.pink; }
                      if (spot['type'] == 'Old Age Home') { icon = Icons.elderly; color = Colors.blue; }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
                        title: Text(spot['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${spot['distKm'].toStringAsFixed(1)} km away • ${spot['type']}"),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => _makePhoneCall(spot['phone'] ?? ''),
                              child: Row(
                                children: [
                                  const Icon(Icons.phone, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(spot['phone'] ?? 'No Number', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                ],
                              ),
                            )
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _completeWithPhoto(donationId, spot['type'], spot['name'], null);
                          },
                          child: const Text("Deliver"),
                        ),
                      );
                    }).toList(),
                    
                    const Divider(height: 40),
                    
                    const Text("NGO HUB", style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.teal.withOpacity(0.1), child: const Icon(Icons.corporate_fare, color: Colors.teal)),
                      title: Text(suggestedNgoName ?? "Nearest Impact Hub"),
                      subtitle: const Text("Requires Hub Accept Confirmation"),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                        onPressed: () {
                          Navigator.pop(context);
                          if (suggestedNgoId != null) {
                            _requestNgoDropoff(donationId, suggestedNgoId, suggestedNgoName!);
                          }
                        },
                        child: const Text("Request"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('donations')
            .where('volunteerUid', isEqualTo: widget.volunteerUid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();

          List<DocumentSnapshot> active = snapshot.data?.docs.where((doc) {
            String status = doc['status'] ?? '';
            return ['Accepted', 'Picked Up', 'NGO Requested', 'En Route'].contains(status);
          }).toList() ?? [];

          if (active.isEmpty) return const SizedBox.shrink();

          var data = active.first.data() as Map<String, dynamic>;
          String status = data['status'] ?? '';
          String donationId = active.first.id;

          bool isPickedUp = status == 'Picked Up';
          bool isRequested = status == 'NGO Requested';
          bool isEnRoute = status == 'En Route';

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              border: Border.all(color: (isRequested || isEnRoute) ? Colors.blue.shade100 : Colors.orange.shade100),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (isRequested || isEnRoute) ? Colors.blue.shade50 : Colors.orange.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Icon(isEnRoute ? Icons.local_shipping : (isRequested ? Icons.hourglass_top : Icons.shopping_bag), color: (isRequested || isEnRoute) ? Colors.blue : Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEnRoute ? "NGO HUB IS READY!" : (isRequested ? "WAITING FOR HUB..." : (isPickedUp ? "CHOOSE DROP-OFF" : "COLLECT FROM DONOR")),
                          style: TextStyle(fontWeight: FontWeight.w900, color: (isRequested || isEnRoute) ? Colors.blue.shade900 : Colors.orange.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['foodItem'] ?? 'Food Rescue', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      
                      if (status == 'Accepted') ...[
                        const Text("Give donor your name then enter their PIN:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _otpController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(hintText: "Enter PIN", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: () => _verifyOtpAndPickup(donationId, data['pickupOtp'] ?? '', data['donorUid'] ?? ''),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
                              child: const Text("VERIFY"),
                            )
                          ],
                        ),
                      ] else if (isPickedUp) ...[
                        const Text("FOOD PICKED UP! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share_location),
                            label: const Text("SELECT DROP-OFF TARGET"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: const EdgeInsets.all(16)),
                            onPressed: () => _showDestinationPicker(
                              context, 
                              donationId, 
                              (data['latitude'] ?? 0.0).toDouble(), 
                              (data['longitude'] ?? 0.0).toDouble(),
                              data['suggestedNgoId'],
                              data['suggestedNgoName']
                            ),
                          ),
                        )
                      ] else if (isRequested) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue),
                              const SizedBox(width: 10),
                              Expanded(child: Text("Hub: ${data['selectedNgoName']}\nhas been notified. Please wait for acceptance.", style: const TextStyle(fontSize: 12, color: Colors.blue))),
                            ],
                          ),
                        ),
                      ] else if (isEnRoute) ...[
                        const Text("NGO HUB IS READY! 🚀", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text("Head to ${data['selectedNgoName']}", style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("I HAVE ARRIVED - TAKE PHOTO"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: const EdgeInsets.all(16)),
                            onPressed: () => _completeWithPhoto(donationId, 'NGO', data['selectedNgoName'], data['selectedNgoId']),
                          ),
                        )
                      ],
                    ],
                  ),
                )
              ],
            ),
          );
        }
    );
  }
}
