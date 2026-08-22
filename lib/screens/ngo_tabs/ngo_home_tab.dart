import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../services/needy_spots_service.dart';
import '../gamification/squads_hub_screen.dart';
import '../../widgets/rank_motivational_banner.dart';
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

  Future<void> _raiseNeed({int? currentCount, bool isEdit = false}) async {
    int count = int.tryParse(_needController.text.trim()) ?? 0;
    if (count <= 0 && !isEdit) return;
    if (isEdit && count <= 0) count = currentCount ?? 0;

    setState(() => isProcessing = true);
    
    // Senior Dev Logic: Demands now have an expiry (4 hours) 
    // and can be edited before they expire.
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
                    Text(hasActiveNeed ? "You can edit your current requirement below." : "How many meals can your hub distribute right now?", style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
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
                    if (hasActiveNeed) Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("Expires: ${snap.data!['expiryTime'].toDate().toString().substring(11, 16)}", style: const TextStyle(fontSize: 9, color: Colors.teal, fontWeight: FontWeight.bold)),
                    )
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
            var incoming = snapshot.data!.docs.where((d) => ['NGO Requested', 'En Route', 'Picked Up'].contains(d['status'])).toList();
            
            return Column(
              children: incoming.map((post) {
                Map<String, dynamic> data = post.data() as Map<String, dynamic>;
                String fullAddr = "${data['exactAddress'] ?? ''}, ${data['city'] ?? ''}";
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text(data['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("From: $fullAddr\nVolunteer: ${data['volunteerName'] ?? 'Hero'}"),
                    isThreeLine: true,
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(data['status'], style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 10)),
                        if (data['status'] == 'Picked Up') IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          onPressed: () async {
                             await FirebaseFirestore.instance.collection('donations').doc(post.id).update({'status': 'NGO Accepted'});
                          },
                        )
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),

        const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text("Spot Network Nearby", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ...NeedySpotsService.getNearbySpots(ngoLat, ngoLon).map((spot) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.home_work, color: Colors.teal),
            title: Text(spot['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
            subtitle: Text("${spot['distKm'].toStringAsFixed(1)} km • ${spot['type']}\n📞 ${spot['phone']}"),
            trailing: IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: () => launchUrl(Uri.parse("tel:${spot['phone']}"))),
          ),
        )).toList(),
        const SizedBox(height: 50),
      ],
    );
  }
}
