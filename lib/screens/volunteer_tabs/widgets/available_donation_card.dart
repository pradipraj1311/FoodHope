import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.donation['isFlashRescue'] == true) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculateTimeAndDistance() {
    double dLat = (widget.donation['latitude'] ?? 0.0).toDouble();
    double dLon = (widget.donation['longitude'] ?? 0.0).toDouble();

    if (widget.vLat.abs() < 0.001 || widget.vLon.abs() < 0.001 || dLat.abs() < 0.001 || dLon.abs() < 0.001) {
      return {'dist': 'Locating...', 'eta': 0, 'etaDisplay': '?', 'isError': true};
    }

    double distKm = Geolocator.distanceBetween(widget.vLat, widget.vLon, dLat, dLon) / 1000;
    double speedKmH = 25.0; 
    if (widget.vehicleType.contains('Bicycle')) speedKmH = 12.0;
    else if (widget.vehicleType.contains('Walking')) speedKmH = 4.0;
    else if (widget.vehicleType.contains('Car')) speedKmH = 30.0;

    int etaMinutes = ((distKm / speedKmH) * 60).ceil() + 5;

    return {
      'dist': "${distKm.toStringAsFixed(1)} km away",
      'eta': etaMinutes,
      'etaDisplay': "$etaMinutes min",
      'isError': false,
    };
  }

  Future<void> _acceptDonation(BuildContext context) async {
    if (_isProcessing) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).get();
      if (!volunteerDoc.exists) throw "Profile not found";
      Map<String, dynamic> vData = volunteerDoc.data() as Map<String, dynamic>;

      if ((vData['profileImageUrl'] ?? '').isEmpty) {
        _showErrorDialog("Photo Required", "Please upload a profile photo in your Settings before accepting rescues.");
        setState(() => _isProcessing = false);
        return;
      }

      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'Accepted', 
        'volunteerUid': widget.volunteerUid, 
        'volunteerName': vData['name'] ?? 'Hero',
        'volunteerContact': vData['contact'] ?? '',
        'acceptedAt': FieldValue.serverTimestamp()
      });

      messenger.showSnackBar(const SnackBar(content: Text("Rescue Accepted! Heading to Pickup."), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Failed to accept: $e"), backgroundColor: Colors.red));
      setState(() => _isProcessing = false);
    }
  }

  void _showErrorDialog(String title, String msg) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    final info = _calculateTimeAndDistance();
    final bool isFlash = widget.donation['isFlashRescue'] == true;
    final donorPlace = widget.donation['businessName'] ?? "Local Donor";
    final donorPhone = widget.donation['donorContact'] ?? "Not Provided";

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isFlash ? [BoxShadow(color: Colors.red.withOpacity(0.3 * _pulseController.value), blurRadius: 10 * _pulseController.value, spreadRadius: 2 * _pulseController.value)] : null,
        ),
        child: child,
      ),
      child: Card(
        elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isFlash ? Colors.red.shade900 : Colors.green.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Time: ${info['etaDisplay']} (${info['dist']})", style: TextStyle(fontWeight: FontWeight.bold, color: isFlash ? Colors.white : Colors.green.shade800)),
                  if (isFlash) const Text("FLASH 🔥", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.donation['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("From: $donorPlace", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // NEW: Prominent Contact Info
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(donorPhone, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.donation['fullAddress'] ?? 'No Address', style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                  
                  const Divider(),
                  CountdownTimerWidget(expiryTimestamp: widget.donation['exactExpiryTime'] as Timestamp?),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                      onPressed: _isProcessing ? null : () => _acceptDonation(context),
                      child: _isProcessing ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("ACCEPT RESCUE"),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
