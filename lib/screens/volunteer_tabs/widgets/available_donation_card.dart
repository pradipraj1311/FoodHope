import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../../widgets/countdown_timer_widget.dart';

class AvailableDonationCard extends StatefulWidget {
  final Map<String, dynamic> donation;
  final String donationId;
  final double vLat;
  final double vLon;
  final String volunteerUid;
  final String vehicleType;

  const AvailableDonationCard({
    super.key, 
    required this.donation, 
    required this.donationId, 
    required this.vLat, 
    required this.vLon,
    required this.volunteerUid,
    this.vehicleType = 'Scooter / Motorcycle'
  });

  @override
  State<AvailableDonationCard> createState() => _AvailableDonationCardState();
}

class _AvailableDonationCardState extends State<AvailableDonationCard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    if (widget.donation['isFlashRescue'] == true) _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateTimeAndDistance() {
    double dLat = (widget.donation['latitude'] ?? 0.0).toDouble();
    double dLon = (widget.donation['longitude'] ?? 0.0).toDouble();
    if (widget.vLat.abs() < 0.001 || dLat.abs() < 0.001) return {'dist': 'Locating...', 'eta': '?', 'isError': true};
    double distKm = Geolocator.distanceBetween(widget.vLat, widget.vLon, dLat, dLon) / 1000;
    int eta = ((distKm / 25) * 60).ceil() + 5;
    return {'dist': "${distKm.toStringAsFixed(1)} km away", 'eta': "$eta min", 'isError': false};
  }

  Future<void> _acceptDonation(String vStatus) async {
    if (_isProcessing || vStatus != 'approved') return;
    setState(() => _isProcessing = true);
    try {
      DocumentSnapshot vDoc = await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).get();
      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'Accepted', 
        'volunteerUid': widget.volunteerUid, 
        'volunteerName': vDoc['name'] ?? 'Hero',
        'acceptedAt': FieldValue.serverTimestamp()
      });
    } catch (e) { debugPrint("Error: $e"); }
    finally { if (mounted) setState(() => _isProcessing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final info = _calculateTimeAndDistance();
    final bool isFlash = widget.donation['isFlashRescue'] == true;
    
    // SENIOR DEV FIX: Show Detailed Address
    final String detailedAddress = "${widget.donation['exactAddress'] ?? ''}, ${widget.donation['streetName'] ?? ''}, ${widget.donation['fullAddress'] ?? ''}";

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).snapshots(),
      builder: (context, userSnap) {
        String vStatus = userSnap.hasData ? (userSnap.data!['verificationStatus'] ?? 'none') : 'none';

        return Card(
          elevation: 4, margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isFlash ? Colors.red.shade900 : Colors.green.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${info['dist']} • ${info['eta']}", style: TextStyle(fontWeight: FontWeight.bold, color: isFlash ? Colors.white : Colors.green.shade800)),
                    if (vStatus == 'pending') const Text("PENDING APPROVAL", style: TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.donation['foodItem'] ?? 'Food Rescue', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("FROM: ${widget.donation['businessName'] ?? 'Donor'}", style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(detailedAddress, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87))),
                      ],
                    ),
                    const Divider(height: 30),
                    CountdownTimerWidget(expiryTimestamp: widget.donation['exactExpiryTime'] as Timestamp?),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: isFlash ? Colors.red : Colors.green.shade700, foregroundColor: Colors.white),
                        onPressed: vStatus == 'approved' ? () => _acceptDonation(vStatus) : null,
                        child: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : Text(vStatus == 'approved' ? "ACCEPT RESCUE" : "AWAITING ADMIN APPROVAL"),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
