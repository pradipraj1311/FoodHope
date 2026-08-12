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

  Future<void> _acceptDonation(String vStatus) async {
    if (_isProcessing) return;

    if (vStatus == 'pending') {
      _showInfoDialog("Pending Review", "Verification is in progress. Admin is reviewing your selfie. Please wait for approval.");
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isProcessing = true);

    try {
      // 1. Fetch data
      DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).get().timeout(const Duration(seconds: 8));
      Map<String, dynamic> vData = volunteerDoc.data() as Map<String, dynamic>;

      if (vData['verificationStatus'] == null || vData['verificationStatus'] == 'none') {
        _showVerificationRequiredDialog();
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

      messenger.showSnackBar(const SnackBar(content: Text("Rescue Accepted!"), backgroundColor: Colors.green));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showVerificationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Safety Verification"),
        content: const Text("Before your first rescue, we need a live selfie for verification. You can track your status after uploading."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () { Navigator.pop(context); _uploadSelfie(); }, child: const Text("Take Selfie"))
        ],
      )
    );
  }

  Future<void> _uploadSelfie() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 20);
    if (photo != null) {
      if (mounted) setState(() => _isProcessing = true);
      String base64 = base64Encode(await photo.readAsBytes());
      await FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).update({
        'verificationProofUrl': base64,
        'verificationStatus': 'pending',
      });
      if (mounted) {
        _showInfoDialog("Selfie Sent", "Admin is reviewing your profile. Rescues will be available once approved.");
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showInfoDialog(String title, String msg) {
    if (!mounted) return;
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(title), content: Text(msg), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]));
  }

  @override
  Widget build(BuildContext context) {
    final info = _calculateTimeAndDistance();
    final bool isError = info['isError'] ?? false;
    final int etaMinutes = info['eta'] is int ? info['eta'] : 0;
    final bool isFlash = widget.donation['isFlashRescue'] == true;
    
    DateTime expiryTime = (widget.donation['exactExpiryTime'] as Timestamp).toDate();
    int minsToExpiry = expiryTime.difference(DateTime.now()).inMinutes;
    bool isRisky = !isError && (etaMinutes + 15) > minsToExpiry;

    final donorPlace = widget.donation['businessName'] ?? "Local Donor";
    final donorPhone = widget.donation['donorContact'] ?? "No Phone";
    final donorAddress = widget.donation['fullAddress'] ?? 'No Address';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.volunteerUid).snapshots(),
      builder: (context, userSnap) {
        String vStatus = 'none';
        if (userSnap.hasData && userSnap.data!.exists) {
          vStatus = userSnap.data!['verificationStatus'] ?? 'none';
        }

        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isFlash ? [BoxShadow(color: Colors.red.withOpacity(0.2 * _pulseController.value), blurRadius: 10)] : null,
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
                      Text("${info['dist']} • ${info['etaDisplay']}", style: TextStyle(fontWeight: FontWeight.bold, color: isFlash ? Colors.white : Colors.green.shade800)),
                      if (vStatus == 'pending') 
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(5)), 
                          child: const Text("VERIFICATION PENDING", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))
                        )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.donation['foodItem'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text("PLACE: $donorPlace", style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 12),
                      
                      Row(children: [const Icon(Icons.phone, size: 16, color: Colors.green), const SizedBox(width: 8), Text(donorPhone, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start, 
                        children: [
                          const Icon(Icons.location_on, size: 16, color: Colors.red), 
                          const SizedBox(width: 8), 
                          Expanded(child: Text(donorAddress, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87, fontWeight: FontWeight.w500)))
                        ]
                      ),
                      
                      const Divider(height: 30),
                      CountdownTimerWidget(expiryTimestamp: widget.donation['exactExpiryTime'] as Timestamp?),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: vStatus == 'pending' ? Colors.blueGrey.shade100 : (isFlash ? Colors.red : Colors.green.shade700), 
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14)
                          ),
                          onPressed: _isProcessing || vStatus == 'pending' ? null : () => _acceptDonation(vStatus),
                          child: _isProcessing 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : Text(vStatus == 'pending' ? "AWAITING APPROVAL" : "ACCEPT RESCUE"),
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
    );
  }
}
