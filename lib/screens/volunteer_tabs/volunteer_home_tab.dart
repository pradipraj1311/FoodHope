import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../delivery_flow/active_delivery_card.dart';
import '../delivery_flow/liveness_verification_screen.dart';

// ... (Keep CountdownTimerWidget exactly as before)
class CountdownTimerWidget extends StatefulWidget {
  final Timestamp? expiryTimestamp;
  const CountdownTimerWidget({super.key, this.expiryTimestamp});
  @override State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}
class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer; String timeLeft = "Calculating..."; bool isExpired = false;
  @override void initState() { super.initState(); _updateTime(); _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (mounted) _updateTime(); }); }
  void _updateTime() {
    if (widget.expiryTimestamp == null) { setState(() => timeLeft = "No expiry set"); return; }
    DateTime expiryTime = widget.expiryTimestamp!.toDate(); Duration diff = expiryTime.difference(DateTime.now());
    if (diff.isNegative) { setState(() { timeLeft = "EXPIRED"; isExpired = true; }); _timer?.cancel(); }
    else { setState(() => timeLeft = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}:${(diff.inSeconds % 60).toString().padLeft(2, '0')} left"); }
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return Row(children: [Icon(Icons.timer, size: 18, color: isExpired ? Colors.red : Colors.orange.shade800), const SizedBox(width: 8), Text(timeLeft, style: TextStyle(color: isExpired ? Colors.red : Colors.orange.shade800, fontWeight: FontWeight.bold))]);
  }
}

class VolunteerHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  const VolunteerHomeTab({super.key, required this.userData, required this.uid});
  @override State<VolunteerHomeTab> createState() => _VolunteerHomeTabState();
}

class _VolunteerHomeTabState extends State<VolunteerHomeTab> {
  String _searchQuery = ""; String _selectedFilter = "All";

  Future<void> _acceptDelivery(BuildContext context, String donationId, double vLat, double vLon) async {
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Accepted',
      'volunteerUid': widget.uid, 'volunteerName': widget.userData['name'] ?? 'Volunteer', 'volunteerContact': widget.userData['contact'] ?? '',
      'pickupTime': DateTime.now(), 'volunteerLatitude': vLat, 'volunteerLongitude': vLon,
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery Accepted! Drive to the Donor.")));
  }

  // PROFILE COMPLETION CHECKER
  void _handleAcceptAttempt(BuildContext context, String donationId, double vLat, double vLon) {
    bool isProfileComplete = widget.userData.containsKey('contact') && widget.userData['contact'].toString().isNotEmpty &&
        widget.userData.containsKey('exactAddress') && widget.userData['exactAddress'].toString().isNotEmpty;

    if (!isProfileComplete) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Profile Incomplete"),
              content: const Text("You must complete your profile details (Phone, Building, Street) in the Profile tab before accepting deliveries."),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))]
          )
      );
      return;
    }

    bool isVerified = widget.userData['isVerifiedVolunteer'] ?? false;

    if (isVerified) {
      // Skip camera, directly accept
      _acceptDelivery(context, donationId, vLat, vLon);
    } else {
      // Must do camera verification once
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LivenessVerificationScreen(
            uid: widget.uid,
            onSuccess: () => _acceptDelivery(context, donationId, vLat, vLon),
          ),
        ),
      );
    }
  }

  Widget _buildFilterChip(String label, IconData icon) {
    bool isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Row(children: [Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.green.shade700), const SizedBox(width: 4), Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
        selected: isSelected, selectedColor: Colors.green.shade700, backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
        onSelected: (bool selected) => setState(() => _selectedFilter = selected ? label : "All"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String userCity = widget.userData['city'] ?? 'Unknown City';
    double vLat = widget.userData['latitude'] ?? 0.0; double vLon = widget.userData['longitude'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('donations').where('volunteerUid', isEqualTo: widget.uid).where('status', whereIn: ['Accepted', 'Picked Up']).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
            var activePost = snapshot.data!.docs.first;
            return ActiveDeliveryCard(donationData: activePost.data() as Map<String, dynamic>, donationId: activePost.id, vLat: vLat, vLon: vLon);
          },
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              TextField(decoration: InputDecoration(hintText: "Search for food...", prefixIcon: const Icon(Icons.search, color: Colors.grey), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 0), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300))), onChanged: (value) => setState(() => _searchQuery = value.toLowerCase())),
              const SizedBox(height: 12),
              SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [_buildFilterChip("All", Icons.filter_list), _buildFilterChip("Veg Only", Icons.grass), _buildFilterChip("Expiring Soon", Icons.timer), _buildFilterChip("Large Qty (>50)", Icons.group)])),
            ],
          ),
        ),

        const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), child: Text("Recommended Rescues", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87))),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations').where('city', isEqualTo: userCity).where('status', isEqualTo: 'Available').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No available food in this area."));

              var filteredDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                if (data['exactExpiryTime'] != null && (data['exactExpiryTime'] as Timestamp).toDate().isBefore(DateTime.now())) return false;
                if (_searchQuery.isNotEmpty && !(data['foodItem'] ?? '').toString().toLowerCase().contains(_searchQuery)) return false;
                if (_selectedFilter == "Veg Only" && data['category'] != "Veg Only") return false;
                if (_selectedFilter == "Large Qty (>50)" && (data['quantity'] ?? 0) < 50) return false;
                if (_selectedFilter == "Expiring Soon" && data['exactExpiryTime'] != null && (data['exactExpiryTime'] as Timestamp).toDate().difference(DateTime.now()).inMinutes > 60) return false;
                return true;
              }).toList();

              if (filteredDocs.isEmpty) return const Center(child: Text("No food matches filters."));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  var post = filteredDocs[index]; Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
                  double dLat = postData['latitude'] ?? 0.0; double dLon = postData['longitude'] ?? 0.0;
                  String distStr = (Geolocator.distanceBetween(vLat, vLon, dLat, dLon) / 1000).toStringAsFixed(1);

                  return Card(
                    elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(postData['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), Chip(label: Text(postData['category'] ?? 'Food', style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade50, side: BorderSide.none)]),
                          const SizedBox(height: 5), Row(children: [const Icon(Icons.people, size: 16, color: Colors.blue), const SizedBox(width: 4), Text("Feeds ${postData['quantity']} • ${postData['foodState']}", style: const TextStyle(fontWeight: FontWeight.w600))]),
                          const Divider(height: 25),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("📍 Pickup Details:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), if (vLat != 0.0 && dLat != 0.0) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)), child: Row(children: [Icon(Icons.route, size: 14, color: Colors.grey.shade800), const SizedBox(width: 4), Text("$distStr km away", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800))]))]),
                          const SizedBox(height: 4), Text("🗺️ Address: ${postData['fullAddress'] ?? 'N/A'}", style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                          const SizedBox(height: 8), CountdownTimerWidget(expiryTimestamp: postData['exactExpiryTime'] as Timestamp?), const SizedBox(height: 15),

                          // WIRED UP NEW HANDLER
                          SizedBox(
                              width: double.infinity, height: 45,
                              child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  onPressed: () => _handleAcceptAttempt(context, post.id, vLat, vLon),
                                  icon: const Icon(Icons.motorcycle),
                                  label: const Text("Accept Delivery", style: TextStyle(fontSize: 16))
                              )
                          )
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