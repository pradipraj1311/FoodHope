import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../services/needy_spots_service.dart';
import '../gamification/squads_hub_screen.dart';
import '../../widgets/rank_banner.dart';
import '../donor_tabs/widgets/post_food_sheet.dart';
import '../../widgets/countdown_timer_widget.dart';

class NgoHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;
  const NgoHomeTab({super.key, required this.userData, required this.uid});
  @override State<NgoHomeTab> createState() => _NgoHomeTabState();
}

class _NgoHomeTabState extends State<NgoHomeTab> {
  bool isProcessing = false;
  final TextEditingController _needController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _needController.dispose();
    super.dispose();
  }

  Future<void> _launchMaps(double lat, double lon) async {
    final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lon");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maps unavailable")));
    }
  }

  Future<void> _raiseNeed({int? currentCount, bool isEdit = false}) async {
    int count = int.tryParse(_needController.text.trim()) ?? 0;
    if (count <= 0 && !isEdit) return;
    if (isEdit && count <= 0) count = currentCount ?? 0;

    setState(() => isProcessing = true);
    await FirebaseFirestore.instance.collection('needs').doc(widget.uid).set({
      'ngoUid': widget.uid,
      'ngoName': widget.userData['organizationName'] ?? 'NGO Hub',
      'mealsNeeded': count,
      'city': widget.userData['city'],
      'updatedAt': FieldValue.serverTimestamp(),
      'expiryTime': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 4))),
    });
    
    setState(() => isProcessing = false);
    _needController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isEdit ? "Demand Updated!" : "Demand Raised! Expires in 4h."), 
        backgroundColor: Colors.teal
      ));
    }
  }

  Future<void> _acceptRescue(String donationId) async {
    setState(() => isProcessing = true);
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'En Route',
      'ngoAcceptedAt': FieldValue.serverTimestamp(),
    });
    setState(() => isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    double ngoLat = (widget.userData['latitude'] ?? 0.0).toDouble();
    double ngoLon = (widget.userData['longitude'] ?? 0.0).toDouble();
    String city = widget.userData['city'] ?? 'Unknown';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        RankMotivationalBanner(uid: widget.uid, city: city, role: 'NGO'),
        
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white),
            onPressed: () => showModalBottomSheet(
              context: context, isScrollControlled: true,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (context) => PostFoodSheet(userData: widget.userData, uid: widget.uid)
            ),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text("Post Surplus Food", style: TextStyle(fontWeight: FontWeight.bold))
          ),
        ),

        const SizedBox(height: 15),
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('needs').doc(widget.uid).snapshots(),
          builder: (context, snap) {
            bool hasActiveNeed = false;
            int currentMeals = 0;
            if (snap.hasData && snap.data!.exists) {
              var data = snap.data!.data() as Map<String, dynamic>;
              var expiry = data['expiryTime'] as Timestamp?;
              if (expiry != null && expiry.toDate().isAfter(DateTime.now())) {
                hasActiveNeed = true;
                currentMeals = data['mealsNeeded'] ?? 0;
              }
            }

            return Card(
              elevation: 0, color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.teal.shade100)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hasActiveNeed ? "ACTIVE DEMAND 📢" : "RAISE FOOD DEMAND 📢", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _needController, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: hasActiveNeed ? "$currentMeals Meals" : "Count", border: const OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isProcessing ? null : () => _raiseNeed(currentCount: currentMeals, isEdit: hasActiveNeed),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18)),
                          child: Text(hasActiveNeed ? "UPDATE" : "RAISE"),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        ),

        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Incoming Food Rescues", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('donations')
              .where('selectedNgoId', isEqualTo: widget.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No incoming rescues.", style: TextStyle(color: Colors.grey, fontSize: 12)));
            
            var incoming = snapshot.data!.docs.where((d) {
              var data = d.data() as Map<String, dynamic>;
              String status = data['status'];
              if (['Delivered', 'Expired', 'Cancelled'].contains(status)) return false;
              if (data['exactExpiryTime'] != null) {
                if ((data['exactExpiryTime'] as Timestamp).toDate().isBefore(DateTime.now())) return false;
              }
              return ['NGO Requested', 'En Route', 'Picked Up'].contains(status);
            }).toList();
            
            if (incoming.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No active requests.", style: TextStyle(color: Colors.grey))));

            return Column(
              children: incoming.map((post) {
                Map<String, dynamic> data = post.data() as Map<String, dynamic>;
                String status = data['status'];
                bool isNonVeg = data['foodType'] == 'Non-Veg';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: IconButton(
                      icon: const Icon(Icons.map, color: Colors.blue),
                      onPressed: () => _launchMaps(data['latitude'], data['longitude']),
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(data['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (isNonVeg) Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: const Text("NON-VEG", style: TextStyle(color: Colors.white, fontSize: 8))),
                      ],
                    ),
                    subtitle: Text("Volunteer: ${data['volunteerName'] ?? 'Hero'}\nStatus: $status"),
                    trailing: status == 'NGO Requested' 
                      ? ElevatedButton(
                          onPressed: isProcessing ? null : () => _acceptRescue(post.id),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          child: const Text("ACCEPT", style: TextStyle(fontSize: 10)),
                        )
                      : const Icon(Icons.check_circle, color: Colors.blue),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Spot Network Nearby", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ...NeedySpotsService.getNearbySpots(ngoLat, ngoLon).map((spot) => ListTile(
          leading: IconButton(
            icon: const Icon(Icons.directions, color: Colors.blue),
            onPressed: () => _launchMaps(spot['lat'], spot['lon']),
          ),
          title: Text(spot['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
          subtitle: Text("${spot['distKm'].toStringAsFixed(1)} km • ${spot['type']}"),
          trailing: IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => launchUrl(Uri.parse("tel:${spot['phone']}"))),
        )).toList(),
        const SizedBox(height: 50),
      ],
    );
  }
}
