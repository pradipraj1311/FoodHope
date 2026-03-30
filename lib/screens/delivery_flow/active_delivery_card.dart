import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class ActiveDeliveryCard extends StatefulWidget {
  final Map<String, dynamic> donationData;
  final String donationId;
  final double vLat;
  final double vLon;

  const ActiveDeliveryCard({super.key, required this.donationData, required this.donationId, required this.vLat, required this.vLon});

  @override
  State<ActiveDeliveryCard> createState() => _ActiveDeliveryCardState();
}

class _ActiveDeliveryCardState extends State<ActiveDeliveryCard> {

  bool _isFraudulentDelivery(double donorLat, double donorLon, double distLat, double distLon) {
    double distance = Geolocator.distanceBetween(donorLat, donorLon, distLat, distLon);
    if (distance < 50.0) { return true; }
    return false;
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
              const Text("To confirm you have picked up the food from the donor, please enter the 4-digit PIN they provide."),
              const SizedBox(height: 15),
              TextField(
                controller: otpController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 4,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ""),
              ),
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
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(" PIN Verified! Calculating the best drop-off location...")));
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN. Please ask the donor for the correct 4 digits.")));
                }
              },
              child: const Text("Verify PIN", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  Widget _buildTrustBadge(String type) {
    String label = "Verified"; IconData icon = Icons.verified; Color color = Colors.green.shade700;
    if (type == 'Volunteer Group') { label = "Community Group"; icon = Icons.star; color = Colors.blue.shade700; }
    else if (type == 'Religious Trust') { label = "Religious Trust"; icon = Icons.temple_hindu; color = Colors.orange.shade800; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 12, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold))]),
    );
  }

  Future<List<Map<String, dynamic>>> _calculateEligibleDestinations() async {
    int foodQuantity = widget.donationData['quantity'] ?? 0;
    double startLat = widget.donationData['latitude'] ?? widget.vLat;
    double startLon = widget.donationData['longitude'] ?? widget.vLon;

    QuerySnapshot ngoSnapshot = await FirebaseFirestore.instance.collection('users').where('isVerified', isEqualTo: true).get();
    List<Map<String, dynamic>> scoredNgos = [];

    for (var doc in ngoSnapshot.docs) {
      Map<String, dynamic> ngoData = doc.data() as Map<String, dynamic>;
      String capacityStr = ngoData['storageCapacity'] ?? '';
      int maxCapacity = 100;
      if (capacityStr.contains('300')) maxCapacity = 300;
      if (capacityStr.contains('500+')) maxCapacity = 10000;
      if (foodQuantity > maxCapacity + 50 && maxCapacity < 1000) continue;

      double nLat = ngoData['latitude'] ?? 0.0;
      double nLon = ngoData['longitude'] ?? 0.0;
      double distKm = Geolocator.distanceBetween(startLat, startLon, nLat, nLon) / 1000;

      int pastSuccesses = ngoData['totalDeliveriesReceived'] ?? 0;
      double capacityBonus = (maxCapacity / 100) * 0.2;
      double reliabilityBonus = (pastSuccesses * 0.1).clamp(0.0, 2.0);
      double matchFactor = distKm - capacityBonus - reliabilityBonus;
      scoredNgos.add({'id': doc.id, 'data': ngoData, 'distKm': distKm, 'matchFactor': matchFactor});
    }

    scoredNgos.sort((a, b) => (a['matchFactor'] as double).compareTo(b['matchFactor'] as double));
    return scoredNgos;
  }

  // --- NEW: THE IMMEDIATE NOTIFICATION TRIGGER ---
  Future<void> _confirmSelectedHub(String ngoId, String ngoName, bool isFraud) async {
    await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
      'selectedNgoId': ngoId,
      'selectedNgoName': ngoName,
      'isFlaggedForFraud': isFraud,
      // CHANGING STATUS TO 'EN ROUTE' TRIGGERS THE HUB NOTIFICATION
      'status': 'En Route',
      'isHubConfirmed': true, // New flag for final handshake logic
      'hubConfirmedAt': DateTime.now(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hub Confirmed! Please start driving.")));
  }

  void _showOverrideDestinationSelector(List<Map<String, dynamic>> allDestinations, String recommendedId) {
    List<String> overrideOptions = [
      '1. I regularly work with this Distributor',
      '2. Recommended Distributor is not responding',
      '3. Recommended Hub is full (no capacity)',
      '4. This Hub is closer / better route',
      '5. This Distributor can distribute faster',
      '6. Food type not accepted by recommended Hub',
      '7. Personal trust / experience',
      '8. Other (write manually)'
    ];

    String selectedOverrideReason = overrideOptions[0];
    TextEditingController otherReasonController = TextEditingController();
    String? proposedNgoId;
    String? proposedNgoName;

    showModalBottomSheet(
        context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Change Drop-off Hub", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 15),
                      const Text("Why would you prefer a different location?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 5),

                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: selectedOverrideReason, decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: overrideOptions.map((val) => DropdownMenuItem(value: val, child: Text(val, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (val) => setModalState(() => selectedOverrideReason = val!),
                      ),

                      if (selectedOverrideReason.contains('Other')) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: otherReasonController,
                          decoration: const InputDecoration(hintText: "Please specify reason...", border: OutlineInputBorder()),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Text("Select New Destination:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                            itemCount: allDestinations.length,
                            itemBuilder: (context, index) {
                              var ngo = allDestinations[index];
                              if (ngo['id'] == recommendedId) return const SizedBox.shrink();

                              bool isSelected = proposedNgoId == ngo['id'];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(ngo['data']['distributorName'] ?? ngo['data']['ngoName'] ?? 'Distributor', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("${ngo['distKm'].toStringAsFixed(1)} km away"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTrustBadge(ngo['data']['distributorType'] ?? 'NGO'),
                                    const SizedBox(width: 8),
                                    isSelected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.circle_outlined),
                                  ],
                                ),
                                onTap: () => setModalState(() { proposedNgoId = ngo['id']; proposedNgoName = ngo['data']['distributorName'] ?? ngo['data']['ngoName']; }),
                              );
                            }
                        ),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
                          onPressed: () async {
                            if (proposedNgoId == null) return;
                            String finalReason = selectedOverrideReason.contains('Other')
                                ? "Other: ${otherReasonController.text.trim()}"
                                : selectedOverrideReason;

                            await FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
                              'selectedNgoId': proposedNgoId,
                              'selectedNgoName': proposedNgoName,
                              'changeReason': finalReason,
                              'isHubConfirmed': false, // Need to re-confirm if changed!
                            });
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text("Confirm Change", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.donationData['status'];
    bool isPickedUp = status == 'Picked Up';
    bool isEnRoute = status == 'En Route';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isPickedUp || isEnRoute ? [Colors.blue.shade500, Colors.blue.shade800] : [Colors.orange.shade400, Colors.deepOrange.shade600]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: isPickedUp || isEnRoute ? Colors.blue.withOpacity(0.4) : Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isPickedUp || isEnRoute ? Icons.local_shipping : Icons.directions_bike, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Text(isPickedUp || isEnRoute ? "GO TO DELIVERY HUB" : "ACTIVE PICKUP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
            ],
          ),
          const Divider(color: Colors.white54, height: 25),
          Text("📦 ${widget.donationData['foodItem']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),

          if (!isPickedUp && !isEnRoute) ...[
            // Status: Accepted (Waiting for PIN)
            Text("📍 From Donor: ${widget.donationData['fullAddress'] ?? widget.donationData['businessName']}", style: const TextStyle(fontSize: 14, color: Colors.white)),
            const SizedBox(height: 5),
            Text("📝 Note: ${widget.donationData['pickupInstructions'] ?? 'See front desk'}", style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 5),
            Text("📞 Donor Contact: ${widget.donationData['donorContact'] ?? 'Not provided'}", style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _showOtpVerification,
                child: const Text("Collect food & Enter PIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ] else ...[
            // Status: Picked Up or En Route
            FutureBuilder<List<Map<String, dynamic>>>(
                future: _calculateEligibleDestinations(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.white));
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text("Calculating best hubs...", style: TextStyle(color: Colors.white70));

                  var allDestinations = snapshot.data!;
                  String bestMatchedId = allDestinations[0]['id'];

                  // Set best match by default if nothing selected
                  if (widget.donationData['selectedNgoId'] == null) {
                    FirebaseFirestore.instance.collection('donations').doc(widget.donationId).update({
                      'selectedNgoId': allDestinations[0]['id'],
                      'selectedNgoName': allDestinations[0]['data']['distributorName'] ?? allDestinations[0]['data']['ngoName'],
                      'isHubConfirmed': false, // Newly assigned, not yet confirmed
                    });
                  }

                  String currentAssignedId = widget.donationData['selectedNgoId'] ?? bestMatchedId;
                  var currentDest = allDestinations.firstWhere((ngo) => ngo['id'] == currentAssignedId, orElse: () => allDestinations[0]);
                  bool isRecommendedSelected = currentAssignedId == bestMatchedId;

                  // Fraud check for the currently selected node
                  double nLat = currentDest['data']['latitude'] ?? 0.0; double nLon = currentDest['data']['longitude'] ?? 0.0;
                  double donorLat = widget.donationData['latitude'] ?? widget.vLat; double donorLon = widget.donationData['longitude'] ?? widget.vLon;
                  bool isFraudPossible = _isFraudulentDelivery(donorLat, donorLon, nLat, nLon);

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Selected Food Hub:", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Row(
                              children: [
                                _buildTrustBadge(currentDest['data']['distributorType'] ?? 'NGO'),
                                const SizedBox(width: 5),
                                if (isRecommendedSelected) const Icon(Icons.star, color: Colors.amber, size: 16),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(currentDest['data']['distributorName'] ?? currentDest['data']['ngoName'] ?? 'Hub', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 3),
                        Text("🏢 ${currentDest['data']['fullAddress'] ?? ''}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text("🗺️ ${currentDest['distKm'].toStringAsFixed(1)} km from pickup", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 15),

                        // --- NEW: PHASE 1 (picked Up, need to click confirm) ---
                        if (isPickedUp) ...[
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _confirmSelectedHub(currentAssignedId, currentDest['data']['distributorName'] ?? currentDest['data']['ngoName'], isFraudPossible),
                              icon: const Icon(Icons.verified),
                              label: const Text("Confirm Delivery Hub", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), // Professional Text
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showOverrideDestinationSelector(allDestinations, bestMatchedId),
                              icon: const Icon(Icons.swap_calls, color: Colors.white70),
                              label: const Text("View other matched hubs", style: TextStyle(color: Colors.white70, fontSize: 13)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30), backgroundColor: Colors.black12),
                            ),
                          )
                        ] else ...[
                          // --- NEW: PHASE 2 (En Route, confirmed) ---
                          Row(children: [
                            CircleAvatar(radius: 12, backgroundColor: Colors.green.shade100, child: const Icon(Icons.check, color: Colors.green, size: 16)),
                            const SizedBox(width: 8),
                            const Text("HUB CONFIRMED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.1)),
                          ]),
                          const SizedBox(height: 10),
                          const Text("Deliver food and wait for coordinator to scan it.", style: TextStyle(color: Colors.white, fontSize: 12, fontStyle: FontStyle.italic)),
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