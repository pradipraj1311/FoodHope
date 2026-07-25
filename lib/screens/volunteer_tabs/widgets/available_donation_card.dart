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

  // --- HELPER: GET REALISTIC TRAVEL TIME ---
  Map<String, dynamic> _calculateTimeAndDistance() {
    double dLat = (widget.donation['latitude'] ?? 0.0).toDouble();
    double dLon = (widget.donation['longitude'] ?? 0.0).toDouble();

    // Safely check for missing coordinates
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

  Future<void> _acceptDonation() async {
    if (_isProcessing) return;
    
    // Capture Messenger to use after async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() => _isProcessing = true);

    try {
      // 1. Fetch fresh volunteer data with timeout
      DocumentSnapshot volunteerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.volunteerUid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!volunteerDoc.exists) throw "User data not found";
      Map<String, dynamic> vData = volunteerDoc.data() as Map<String, dynamic>;

      // 2. Profile Photo Check
      if ((vData['profileImageUrl'] ?? '').isEmpty) {
        if (mounted) {
          _showErrorDialog("Photo Required", "Please upload a profile photo in your Settings before accepting rescues.");
        }
        setState(() => _isProcessing = false);
        return;
      }

      // 3. Active Rescue Check
      QuerySnapshot activeCheck = await FirebaseFirestore.instance.collection('donations')
          .where('volunteerUid', isEqualTo: widget.volunteerUid)
          .where('status', whereIn: ['Accepted', 'Picked Up', 'En Route'])
          .get()
          .timeout(const Duration(seconds: 8));

      if (activeCheck.docs.isNotEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(const SnackBar(content: Text("⚠️ You already have an active rescue!"), backgroundColor: Colors.red));
        }
        setState(() => _isProcessing = false);
        return;
      }

      // 4. Update Donation Status
      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'Accepted', 
        'volunteerUid': widget.volunteerUid, 
        'volunteerName': vData['name'] ?? 'Hero',
        'volunteerContact': vData['contact'] ?? '',
        'acceptedAt': FieldValue.serverTimestamp()
      }).timeout(const Duration(seconds: 8));

      // Note: Snackbars should only be shown if we're still on a valid screen
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Rescue Accepted! Heading to Pickup."), backgroundColor: Colors.green));
      
    } catch (e) {
      debugPrint("Error accepting rescue: $e");
      if (mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text("Failed to accept: $e"), backgroundColor: Colors.red));
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
    final bool isError = info['isError'];
    final int eta = info['eta'] is int ? info['eta'] : 0;
    final bool isFlash = widget.donation['isFlashRescue'] == true;
    
    DateTime expiryTime = (widget.donation['exactExpiryTime'] as Timestamp).toDate();
    int minsToExpiry = expiryTime.difference(DateTime.now()).inMinutes;
    bool isRisky = !isError && (eta + 15) > minsToExpiry;

    String donorPlace = widget.donation['businessName'] ?? "Local Donor";

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
                color: isFlash ? Colors.red.shade900 : (isError ? Colors.grey.shade100 : (isRisky ? Colors.red.shade50 : Colors.green.shade50)),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(isFlash ? Icons.bolt : Icons.timer_outlined, size: 16, color: isFlash ? Colors.yellowAccent : (isError ? Colors.grey : (isRisky ? Colors.red : Colors.green))),
                    const SizedBox(width: 6),
                    Text(
                      isFlash ? "FLASH RESCUE: Arriving in ${info['etaDisplay']}" : "Travel Time: ${info['etaDisplay']} (${info['dist']})",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isFlash ? Colors.white : (isError ? Colors.grey : (isRisky ? Colors.red.shade800 : Colors.green.shade800)))
                    )
                  ]),
                  if (isFlash) 
                    const Text("URGENT 🔥", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10))
                  else if (isError) 
                    const Text("📍 Set location", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange))
                  else 
                    Row(children: [Icon(isRisky ? Icons.warning_amber : Icons.verified, size: 16, color: isRisky ? Colors.red : Colors.green), const SizedBox(width: 4), Text(isRisky ? "Risky" : "Safe", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isRisky ? Colors.red.shade800 : Colors.green.shade800))]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        height: 50, width: 50, 
                        decoration: BoxDecoration(
                          color: isFlash ? Colors.red.shade50 : Colors.grey.shade100, 
                          borderRadius: BorderRadius.circular(10),
                          border: isFlash ? Border.all(color: Colors.red.shade200) : null,
                        ),
                        child: Icon(Icons.fastfood, color: isFlash ? Colors.red : Colors.grey)
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.donation['foodItem'], style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isFlash ? Colors.red.shade900 : Colors.black87)),
                            Text("From: $donorPlace", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                            Text("Feeds ${widget.donation['quantity']} • ${widget.donation['category']}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CountdownTimerWidget(expiryTimestamp: widget.donation['exactExpiryTime'] as Timestamp?),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Colors.blue),
                    title: Text(widget.donation['fullAddress'] ?? 'No Address', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text("Tap to view on Map", style: TextStyle(fontSize: 11)),
                    onTap: () {
                      final double lat = (widget.donation['latitude'] ?? 0.0).toDouble();
                      final double lon = (widget.donation['longitude'] ?? 0.0).toDouble();
                      final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lon";
                      launchUrl(Uri.parse(googleMapsUrl), mode: LaunchMode.externalApplication);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFlash ? Colors.red : (isRisky ? Colors.orange.shade700 : Colors.green.shade600), 
                        foregroundColor: Colors.white,
                        elevation: isFlash ? 8 : 2,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isProcessing ? null : _acceptDonation,
                      child: _isProcessing 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isFlash ? "RESPOND NOW 🔥" : (isRisky ? "Accept Risky Rescue" : "Accept Rescue"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
