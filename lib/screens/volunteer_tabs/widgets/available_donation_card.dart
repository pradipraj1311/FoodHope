import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // --- HELPER: GET REALISTIC TRAVEL TIME ---
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
      'distRaw': distKm
    };
  }

  Future<void> _acceptDonation(BuildContext context) async {
    if (_isProcessing) return;
    
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.volunteerUid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!volunteerDoc.exists) throw "User data not found";
      Map<String, dynamic> vData = volunteerDoc.data() as Map<String, dynamic>;

      // Verification check
      String vStatus = vData['verificationStatus'] ?? 'pending';
      if (vStatus == 'pending') {
        _showVerificationRequiredDialog();
        setState(() => _isProcessing = false);
        return;
      }

      QuerySnapshot activeCheck = await FirebaseFirestore.instance.collection('donations')
          .where('volunteerUid', isEqualTo: widget.volunteerUid)
          .where('status', whereIn: ['Accepted', 'Picked Up', 'NGO Requested', 'En Route'])
          .get()
          .timeout(const Duration(seconds: 8));

      if (activeCheck.docs.isNotEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text("⚠️ You already have an active rescue!"), backgroundColor: Colors.red));
        setState(() => _isProcessing = false);
        return;
      }

      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'Accepted', 
        'volunteerUid': widget.volunteerUid, 
        'volunteerName': vData['name'] ?? 'Hero',
        'volunteerContact': vData['contact'] ?? '',
        'acceptedAt': FieldValue.serverTimestamp()
      }).timeout(const Duration(seconds: 8));

      messenger.showSnackBar(const SnackBar(content: Text("Rescue Accepted! Heading to Pickup."), backgroundColor: Colors.green));
      
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showVerificationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Action Required 📸"),
        content: const Text("Before your first rescue, we need a live selfie for safety verification. Admin will approve you shortly after."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadVerificationSelfie();
            }, 
            child: const Text("Capture Selfie")
          ),
        ],
      )
    );
  }

  Future<void> _uploadVerificationSelfie() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);

    if (photo != null) {
      setState(() => _isProcessing = true);
      try {
        List<int> imageBytes = await photo.readAsBytes();
        String base64 = base64Encode(imageBytes);
        
        await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).update({
          'verificationProofUrl': base64,
          'verificationStatus': 'pending',
        });
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Sent! ✅"),
              content: const Text("Selfie sent to Admin. You will be able to accept rescues as soon as you are approved."),
              actions: [ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Understood"))],
            )
          );
        }
      } catch (e) {
        debugPrint(e.toString());
      } finally {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = _calculateTimeAndDistance();
    final bool isFlash = widget.donation['isFlashRescue'] == true;
    final donorPlace = widget.donation['businessName'] ?? "Local Donor";
    final donorPhone = widget.donation['donorContact'] ?? "Not Provided";
    final donorAddress = widget.donation['fullAddress'] ?? 'No Address';

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isFlash ? [
              BoxShadow(
                color: Colors.red.withOpacity(0.3 * _pulseController.value),
                blurRadius: 10 * _pulseController.value,
                spreadRadius: 2 * _pulseController.value,
              )
            ] : null,
          ),
          child: child,
        );
      },
      child: Card(
        elevation: 4, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isFlash ? Colors.red.shade900 : Colors.green.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(isFlash ? Icons.bolt : Icons.timer_outlined, size: 16, color: isFlash ? Colors.yellowAccent : Colors.green.shade800),
                    const SizedBox(width: 6),
                    Text(
                      isFlash ? "FLASH RESCUE: Arriving in ${info['etaDisplay']}" : "Travel Time: ${info['etaDisplay']} (${info['dist']})",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isFlash ? Colors.white : (isError ? Colors.grey : (isRisky ? Colors.red.shade800 : Colors.green.shade800)))
                    )
                  ]),
                  if (isFlash) 
                    const Text("URGENT 🔥", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10))
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.donation['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("Place: $donorPlace", style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey)),
                  const SizedBox(height: 8),
                  
                  // DONOR CONTACT & ADDRESS
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(donorPhone, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(donorAddress, style: const TextStyle(fontSize: 13, color: Colors.black87))),
                    ],
                  ),
                  
                  const Divider(height: 24),
                  CountdownTimerWidget(expiryTimestamp: widget.donation['exactExpiryTime'] as Timestamp?),
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFlash ? Colors.red : Colors.green.shade700, 
                        foregroundColor: Colors.white,
                        elevation: isFlash ? 8 : 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing ? null : () => _acceptDonation(context),
                      child: _isProcessing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isFlash ? "RESPOND NOW 🔥" : "ACCEPT RESCUE", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
