import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/rank_motivational_banner.dart';
import 'widgets/available_donation_card.dart';
import '../delivery_flow/active_delivery_card.dart';

class VolunteerHomeTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const VolunteerHomeTab({super.key, required this.userData, required this.uid});

  @override
  Widget build(BuildContext context) {
    double vLat = userData['latitude'] ?? 0.0;
    double vLon = userData['longitude'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RankMotivationalBanner(uid: uid, city: userData['city'] ?? 'Unknown', role: 'Volunteer'),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('city', isEqualTo: userData['city'])
                .where('status', whereIn: ['Available', 'Accepted', 'Picked Up', 'En Route'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.green));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No active food alerts in your city.", style: TextStyle(color: Colors.grey)));

              var allActiveDocs = snapshot.data!.docs;

              var myActiveDeliveries = allActiveDocs.where((doc) => (doc.data() as Map<String, dynamic>)['volunteerUid'] == uid && ['Accepted', 'Picked Up', 'En Route'].contains((doc.data() as Map<String, dynamic>)['status'])).toList();

              if (myActiveDeliveries.isNotEmpty) {
                var activeDoc = myActiveDeliveries.first;
                return ActiveDeliveryCard(donationData: activeDoc.data() as Map<String, dynamic>, donationId: activeDoc.id, vLat: vLat, vLon: vLon);
              }

              var availableDocs = allActiveDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Available').toList();
              if (availableDocs.isEmpty) return const Center(child: Text("No available food alerts right now.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.all(16), itemCount: availableDocs.length,
                itemBuilder: (context, index) {
                  return AvailableDonationCard(
                    donation: availableDocs[index].data() as Map<String, dynamic>,
                    donationId: availableDocs[index].id,
                    vLat: vLat, vLon: vLon, volunteerUid: uid,
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