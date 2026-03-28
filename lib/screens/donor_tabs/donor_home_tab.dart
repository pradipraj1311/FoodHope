import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math'; // NEW: For OTP Generation

// [Keep the CountdownTimerWidget exactly as it was]
class CountdownTimerWidget extends StatefulWidget {
  final Timestamp? expiryTimestamp;
  const CountdownTimerWidget({super.key, this.expiryTimestamp});
  @override State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}
class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer; String timeLeft = "Calculating..."; bool isExpired = false;
  @override void initState() { super.initState(); _updateTime(); _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (mounted) _updateTime(); }); }
  void _updateTime() {
    if (widget.expiryTimestamp == null) { setState(() => timeLeft = "No exact expiry set"); return; }
    DateTime expiryTime = widget.expiryTimestamp!.toDate(); Duration diff = expiryTime.difference(DateTime.now());
    if (diff.isNegative) { setState(() { timeLeft = "EXPIRED"; isExpired = true; }); _timer?.cancel(); }
    else { setState(() => timeLeft = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')} left"); }
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Row(children: [Icon(Icons.timer, size: 16, color: isExpired ? Colors.red : Colors.orange.shade800), const SizedBox(width: 6), Text(timeLeft, style: TextStyle(color: isExpired ? Colors.red : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13))]);
  }
}

class DonorHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  const DonorHomeTab({super.key, required this.userData, required this.uid});
  @override State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {
  Widget _requiredLabel(String text) {
    return Text.rich(TextSpan(text: text, style: TextStyle(color: Colors.grey.shade700, fontSize: 15), children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]));
  }

  void _showPostFoodSheet() {
    TextEditingController foodItemController = TextEditingController();
    TextEditingController quantityController = TextEditingController();
    String foodCategory = 'Cooked Meal'; String foodType = 'Veg Only'; String prepTime = 'Just Cooked (Hot)'; String selectedExpiry = 'Within 2 Hours'; String selectedPickup = 'Hand to front desk / reception';

    showModalBottomSheet(
        context: context, isScrollControlled: true, backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Post a Food Rescue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
                        TextField(controller: foodItemController, decoration: InputDecoration(label: _requiredLabel("Food Details (e.g., 50 Rotis)"), border: const OutlineInputBorder())), const SizedBox(height: 15),
                        TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: InputDecoration(label: _requiredLabel("Feeds how many people?"), border: const OutlineInputBorder())), const SizedBox(height: 15),
                        Row(children: [
                          Expanded(child: DropdownButtonFormField<String>(value: foodCategory, decoration: InputDecoration(label: _requiredLabel("State"), border: const OutlineInputBorder()), items: ['Cooked Meal', 'Packaged Food', 'Raw Ingredients', 'Bakery / Sweets'].map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (val) => setModalState(() => foodCategory = val!))), const SizedBox(width: 10),
                          Expanded(child: DropdownButtonFormField<String>(value: foodType, decoration: InputDecoration(label: _requiredLabel("Dietary"), border: const OutlineInputBorder()), items: ['Veg Only', 'Non-Veg', 'Both (Mixed)'].map((val) => DropdownMenuItem(value: val, child: Text(val, style: const TextStyle(fontSize: 13)))).toList(), onChanged: (val) => setModalState(() => foodType = val!))),
                        ]), const SizedBox(height: 15),
                        DropdownButtonFormField<String>(value: prepTime, decoration: InputDecoration(label: _requiredLabel("Prepared when?"), border: const OutlineInputBorder()), items: ['Just Cooked (Hot)', 'Cooked 2-4 hours ago', 'Cooked yesterday', 'N/A'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (val) => setModalState(() => prepTime = val!)), const SizedBox(height: 15),
                        DropdownButtonFormField<String>(value: selectedExpiry, decoration: InputDecoration(label: _requiredLabel("Must be picked up..."), border: const OutlineInputBorder()), items: ['Within 1 Hour', 'Within 2 Hours', 'Within 4 Hours', 'By End of Day'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(), onChanged: (val) => setModalState(() => selectedExpiry = val!)), const SizedBox(height: 15),
                        DropdownButtonFormField<String>(value: selectedPickup, decoration: InputDecoration(label: _requiredLabel("Pickup Instructions"), border: const OutlineInputBorder()), items: ['Hand to front desk / reception', 'Call upon arrival, I will bring it out', 'Pick up from back door / kitchen', 'Other'].map((val) => DropdownMenuItem(value: val, child: Text(val, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) => setModalState(() => selectedPickup = val!)), const SizedBox(height: 25),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                            onPressed: () async {
                              if (foodItemController.text.isEmpty || quantityController.text.isEmpty) return;
                              DateTime now = DateTime.now(); DateTime exactExpiryTime = now;
                              if (selectedExpiry.contains('1 Hour')) exactExpiryTime = now.add(const Duration(hours: 1));
                              else if (selectedExpiry.contains('2 Hours')) exactExpiryTime = now.add(const Duration(hours: 2));
                              else if (selectedExpiry.contains('4 Hours')) exactExpiryTime = now.add(const Duration(hours: 4));
                              else exactExpiryTime = DateTime(now.year, now.month, now.day, 23, 59, 59);

                              // GENERATE SECURE 4-DIGIT PIN
                              String generatedOtp = (1000 + Random().nextInt(9000)).toString();

                              String exactBuilding = widget.userData['exactAddress'] ?? ''; String landmark = widget.userData['landmark'] ?? ''; String gpsStreet = widget.userData['fullAddress'] ?? widget.userData['shortAddress'] ?? 'Unknown Area';
                              String finalDisplayAddress = "${exactBuilding.isNotEmpty ? '$exactBuilding\n' : ''}${landmark.isNotEmpty ? 'Landmark: $landmark\n' : ''}$gpsStreet";

                              await FirebaseFirestore.instance.collection('donations').add({
                                'donorUid': widget.uid, 'businessName': widget.userData['businessName'] ?? 'Donor', 'donorContact': widget.userData['contact'] ?? 'No Number',
                                'foodItem': foodItemController.text.trim(), 'quantity': int.tryParse(quantityController.text.trim()) ?? 0, 'foodState': foodCategory, 'category': foodType,
                                'prepTime': prepTime, 'expiry': selectedExpiry, 'exactExpiryTime': exactExpiryTime, 'status': 'Available', 'postedAt': now, 'city': widget.userData['city'] ?? 'Unknown',
                                'fullAddress': finalDisplayAddress, 'pickupInstructions': selectedPickup, 'latitude': widget.userData['latitude'], 'longitude': widget.userData['longitude'],
                                'pickupOtp': generatedOtp, // SAVING OTP TO DATABASE
                              });
                              await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'totalDonationsMade': FieldValue.increment(1)});
                              if (mounted) Navigator.pop(context);
                            },
                            child: const Text("Publish Donation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ), const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.all(16.0), child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _showPostFoodSheet, icon: const Icon(Icons.add_circle, size: 28), label: const Text("Post Food Rescue", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Text("Active Donations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').where('donorUid', isEqualTo: widget.uid).where('status', whereIn: ['Available', 'Accepted', 'Picked Up']).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("You have no active food postings.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index]; Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
                  String currentStatus = postData['status']; bool isAccepted = currentStatus == 'Accepted'; bool isPickedUp = currentStatus == 'Picked Up';

                  return Card(
                    elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(postData['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: isPickedUp ? Colors.purple.shade100 : (isAccepted ? Colors.blue.shade100 : Colors.green.shade100), borderRadius: BorderRadius.circular(10)), child: Text(currentStatus, style: TextStyle(color: isPickedUp ? Colors.purple.shade800 : (isAccepted ? Colors.blue.shade800 : Colors.green.shade800), fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(children: [const Icon(Icons.people, size: 16, color: Colors.orange), const SizedBox(width: 8), Text("Feeds ${postData['quantity']} • ${postData['foodState']}")]),
                          const SizedBox(height: 8),
                          CountdownTimerWidget(expiryTimestamp: postData['exactExpiryTime'] as Timestamp?),

                          // NEW: SHOW SECURE PIN IF VOLUNTEER IS COMING
                          if (isAccepted) ...[
                            const Divider(height: 20),
                            Container(
                              padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                              child: Column(
                                children: [
                                  const Text("Give this PIN to the Volunteer:", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(postData['pickupOtp'] ?? 'Error', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.red.shade900)),
                                ],
                              ),
                            )
                          ],

                          if (isPickedUp) ...[
                            const Divider(height: 20),
                            Row(children: [Icon(Icons.local_shipping, size: 18, color: Colors.purple.shade700), const SizedBox(width: 8), Expanded(child: Text("Volunteer ${postData['volunteerName']} has picked up the food!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700)))]),
                          ],

                          if (!isPickedUp && !isAccepted) ...[
                            const SizedBox(height: 15),
                            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () async { await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({'cancellationCount': FieldValue.increment(1)}); await FirebaseFirestore.instance.collection('donations').doc(post.id).delete(); }, style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text("Cancel Donation")))
                          ]
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}