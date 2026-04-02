import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'widgets/active_urgency_timer.dart';
import 'widgets/delivery_milestone_tracker.dart';
import 'widgets/override_hub_sheet.dart';

class ActiveDeliveryCard extends StatefulWidget {
  final Map<String, dynamic> donationData;
  final String donationId;
  final double vLat;
  final double vLon;

  const ActiveDeliveryCard({super.key, required this.donationData, required this.donationId, required this.vLat, required this.vLon});
  @override State<ActiveDeliveryCard> createState() => _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends State<ActiveDeliveryCard> {

  bool _isFraudulentDelivery(double donorLat, double donorLon, double distLat, double distLon) {
    return Geolocator.distanceBetween(donorLat, donorLon, distLat, distLon) < 50.0;
  }

  void _showOtpVerification() {
    TextEditingController otpController = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Pickup"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Enter the 4-digit PIN from the Donor."), const SizedBox(height: 15),
              TextField(controller: otpController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 4, style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold), decoration: const InputDecoration(border: OutlineInputBorder(), counterText: "")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700),
              onPressed: () async {
                String enteredPin = otpController.text.trim();
                String actualPin = widget.donationData['pickupOtp'].toString().trim();
                if (enteredPin.length == 4 && enteredPin == actualPin) {
                  await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({'status': 'Picked Up'});
                  if (context.mounted) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(" PIN Verified! Calculating best drop-off..."))); }
                } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN."))); }
              },
              child: const Text("Verify PIN", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  Widget _buildTrustBadge(String type) {
    String label = "Verified"; IconData icon = Icons.verified; Color color = Colors.green.shade700;
    if (type == 'Volunteer Group') { label = "Group"; icon = Icons.star; color = Colors.blue.shade700; }
    else if (type == 'Religious Trust') { label = "Trust"; icon = Icons.temple_hindu; color = Colors.orange.shade800; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]));
  }

  Future<void> _completeDeliveryWithPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (photo != null) {
      if (mounted) showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.green)));

      await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
        'status': 'Completed', 'dropoffTime': DateTime.now(), 'photoProofUrl': 'verified_local_path',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🎉 Delivery Completed! Incredible job!")));
      }
    }
  }

  Future<List<Map<String, dynamic>>> _calculateEligibleDestinations(DateTime safeExpiryTime) async {
    int foodQuantity = widget.donationData['quantity'] ?? 0;
    String foodCategory = widget.donationData['category'] ?? 'Veg Only';
    double startLat = widget.donationData['latitude'] ?? widget.vLat;
    double startLon = widget.donationData['longitude'] ?? widget.vLon;
    int minsLeftTotal = safeExpiryTime.difference(DateTime.now()).inMinutes;

    QuerySnapshot ngoSnapshot = await FirebaseFirestore.instance.collection('users').where('isVerified', isEqualTo: true).get();
    List<Map<String, dynamic>> scoredNgos = [];

    for (var doc in ngoSnapshot.docs) {
      Map<String, dynamic> ngoData = doc.data() as Map<String, dynamic>;
      if ((ngoData['foodPreference'] ?? 'Any Food') == 'Veg Only' && (foodCategory == 'Non-Veg' || foodCategory == 'Both (Mixed)')) continue;

      String capacityStr = ngoData['storageCapacity'] ?? '';
      int maxCapacity = capacityStr.contains('500+') ? 10000 : (capacityStr.contains('300') ? 300 : 100);
      if (foodQuantity > maxCapacity + 50 && maxCapacity < 1000) continue;

      double nLat = ngoData['latitude'] ?? 0.0; double nLon = ngoData['longitude'] ?? 0.0;
      double distKm = Geolocator.distanceBetween(startLat, startLon, nLat, nLon) / 1000;

      if ((distKm * 3.0).toInt() > minsLeftTotal) continue;

      double matchFactor = distKm - ((maxCapacity / 100) * 0.2) - (((ngoData['totalDeliveriesReceived'] ?? 0) * 0.1).clamp(0.0, 2.0));
      scoredNgos.add({'id': doc.id, 'data': ngoData, 'distKm': distKm, 'matchFactor': matchFactor});
    }
    scoredNgos.sort((a, b) => (a['matchFactor'] as double).compareTo(b['matchFactor'] as double));
    return scoredNgos;
  }

  Future<void> _confirmSelectedHub(String ngoId, String ngoName, bool isFraud) async {
    await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({'selectedNgoId': ngoId, 'selectedNgoName': ngoName, 'isFlaggedForFraud': isFraud, 'status': 'En Route', 'isHubConfirmed': true, 'hubConfirmedAt': DateTime.now()});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hub Confirmed! Please start driving.")));
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.donationData['status'];
    bool isPickedUp = status == 'Picked Up';
    bool isEnRoute = status == 'En Route';

    Timestamp? trueExpiry = widget.donationData['exactExpiryTime'] as Timestamp?;
    DateTime? safeExpiryTime;
    bool isSafeWindowMissed = false;

    if (trueExpiry != null) {
      safeExpiryTime = trueExpiry.toDate().subtract(const Duration(minutes: 30));
      if (DateTime.now().isAfter(safeExpiryTime)) isSafeWindowMissed = true;
    }

    return Container(
      margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: isPickedUp || isEnRoute ? [Colors.blue.shade500, Colors.blue.shade800] : [Colors.orange.shade400, Colors.deepOrange.shade600]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: isPickedUp || isEnRoute ? Colors.blue.withOpacity(0.4) : Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DeliveryMilestoneTracker(status: status), // <--- EXTRACTED COMPONENT

          Row(children: [Icon(isPickedUp || isEnRoute ? Icons.local_shipping : Icons.directions_bike, color: Colors.white, size: 28), const SizedBox(width: 10), Text(isPickedUp || isEnRoute ? "GO TO HUB" : "ACTIVE PICKUP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2))]),
          const Divider(color: Colors.white54, height: 25),
          Text("📦 ${widget.donationData['foodItem']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 10),

          if (safeExpiryTime != null && !isSafeWindowMissed) ActiveUrgencyTimer(safeExpiryTime: safeExpiryTime), // <--- EXTRACTED COMPONENT
          const SizedBox(height: 15),

          if (!isPickedUp && !isEnRoute) ...[
            Text("📍 From: ${widget.donationData['fullAddress'] ?? widget.donationData['businessName']}", style: const TextStyle(fontSize: 14, color: Colors.white)), const SizedBox(height: 5),
            Text("📞 Contact: ${widget.donationData['donorContact'] ?? 'Not provided'}", style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _showOtpVerification, child: const Text("Collect food & Enter PIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
          ] else if (isSafeWindowMissed) ...[
            Container(
              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade300)),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 30), const SizedBox(height: 5),
                  const Text("⚠️ HUB DELIVERY WINDOW MISSED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 5),
                  const Text("Do not deliver to the NGO. Please safely discard or distribute immediately.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: () async { await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({'status': 'Failed (Mid-Route)', 'dropoffTime': DateTime.now()}); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red.shade900), child: const Text("Mark as Resolved / Discarded"))
                ],
              ),
            )
          ] else ...[
            FutureBuilder<List<Map<String, dynamic>>>(
                future: _calculateEligibleDestinations(safeExpiryTime!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("No safe hubs found. Distribute directly.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold));

                  var allDestinations = snapshot.data!;
                  String bestMatchedId = allDestinations[0]['id'];

                  if (widget.donationData['selectedNgoId'] == null) {
                    FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({'selectedNgoId': allDestinations[0]['id'], 'selectedNgoName': allDestinations[0]['data']['distributorName'] ?? allDestinations[0]['data']['ngoName'], 'isHubConfirmed': false});
                  }

                  String currentAssignedId = widget.donationData['selectedNgoId'] ?? bestMatchedId;
                  var currentDest = allDestinations.firstWhere((ngo) => ngo['id'] == currentAssignedId, orElse: () => allDestinations[0]);
                  bool isFraudPossible = _isFraudulentDelivery(widget.donationData['latitude'] ?? widget.vLat, widget.donationData['longitude'] ?? widget.vLon, currentDest['data']['latitude'] ?? 0.0, currentDest['data']['longitude'] ?? 0.0);

                  return Container(
                    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Selected Food Hub:", style: TextStyle(color: Colors.white70, fontSize: 12)), _buildTrustBadge(currentDest['data']['distributorType'] ?? 'NGO')]), const SizedBox(height: 5),
                        Text(currentDest['data']['distributorName'] ?? 'Hub', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 3),
                        Text("🏢 ${currentDest['data']['fullAddress'] ?? ''}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text("🗺️ ${currentDest['distKm'].toStringAsFixed(1)} km from pickup", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), const SizedBox(height: 15),

                        if (isPickedUp) ...[
                          SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => _confirmSelectedHub(currentAssignedId, currentDest['data']['distributorName'], isFraudPossible), icon: const Icon(Icons.verified), label: const Text("Confirm Delivery Hub", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))), const SizedBox(height: 10),
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                // --- EXTRACTED COMPONENT FOR BOTTOM SHEET ---
                                  onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => OverrideHubSheet(donationId: widget.donationId, allDestinations: allDestinations, recommendedId: bestMatchedId)),
                                  icon: const Icon(Icons.swap_calls, color: Colors.white70), label: const Text("View other matched hubs", style: TextStyle(color: Colors.white70, fontSize: 13)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30), backgroundColor: Colors.black12)
                              )
                          )
                        ] else ...[
                          Row(children: [CircleAvatar(radius: 12, backgroundColor: Colors.green.shade100, child: const Icon(Icons.check, color: Colors.green, size: 16)), const SizedBox(width: 8), const Text("ARRIVED AT HUB", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1))]),
                          const SizedBox(height: 15),
                          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: _completeDeliveryWithPhoto, icon: const Icon(Icons.camera_alt), label: const Text("Take Photo & Complete", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))))
                        ],
                      ],
                    ),
                  );
                }
            ),
          ],
        ],
      ),
    );
  }
}