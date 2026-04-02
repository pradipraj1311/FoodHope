import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class NgoReceivingTab extends StatelessWidget {
  final String uid; // current user uid
  const NgoReceivingTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header as seen in image 4
          Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            color: Colors.teal.shade800,
            child: const Row(
              children: [
                Icon(Icons.corporate_fare, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  "Receiving Hub: ngo1",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Incoming Food Rescues",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          // STRICTLY USE SAMPLE DATA FOR INCOMING RESCUES
          _buildIncomingCard('65 rotis', 'Feeds approx 25 people', 'Returning User', '+917285807930', 'dummy_donation_id'),
        ],
      ),
    );
  }

  // Sample card logic based on Image 4
  Widget _buildIncomingCard(String foodItem, String quantity, String volunteerName, String volunteerPhone, String donationId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with Cooked Meal, Ready for Receipt and Photo placeholder from Image 4
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(6)),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.teal.shade700),
                    const SizedBox(width: 4),
                    Text("Ready for Receipt", style: TextStyle(color: Colors.teal.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Text("Cooked Meal", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          // Sample Photo placeholder from image 4
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Icon(Icons.image_outlined, color: Colors.grey)),
          ),
          const SizedBox(height: 10),
          Text("📦 $foodItem", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(quantity, style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Volunteer Details:", style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 5),
                Text("👤 $volunteerName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("📞 $volunteerPhone", style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // --- THE TWO BUTTONS Side-by-Side ---
          Row(
            children: [
              Expanded(
                flex: 2, // Photo button gets more space
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _confirmWithPhoto(donationId, quantity);
                    },
                    icon: Icon(Icons.camera_alt),
                    label: Text('Confirm (Photo)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 1, // Skip button is smaller
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _skipConfirmation(donationId, quantity);
                    },
                    icon: Icon(Icons.developer_mode), // Use a developer icon
                    label: Text('Skip'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Normal business logic using camera
  Future<void> _confirmWithPhoto(String donationId, String quantityDescription) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);

    if (photo != null) {
      // 1. Mark donation as completed. Provide dummy volunteer info as I don't have it.
      await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
        'status': 'Completed',
        'dropoffTime': DateTime.now(),
        'photoProofUrl': 'verified_local_path', // stubbed for generic tab
        'volunteerName': 'Volunteer', // stubbed for generic tab
        'quantity': int.tryParse(quantityDescription.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0, // stubbed extraction from description
      });

      // 2. Award points to NGO.
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'totalDeliveriesReceived': FieldValue.increment(1),
        'impactPoints': FieldValue.increment(10),
        'rankScore': FieldValue.increment(10), //NGO's rank is based on verified deliveries received speed consistency
      });

      // 3. Award points to Volunteer. This requires the volunteer UID which I do not have in this generic context. This step is stubbed.
    }
  }

  // The developer mode logic to bypass camera for testing ranking
  Future<void> _skipConfirmation(String donationId, String quantityDescription) async {
    // 1. Mark donation as completed without photo
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Completed',
      'dropoffTime': DateTime.now(),
      'photoProofUrl': 'verified_local_path', // still update bcoz we are skipping
      'volunteerName': 'Volunteer', // stubbed for generic tab
      'quantity': int.tryParse(quantityDescription.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0, // stubbed extraction from description
    });

    // 2. Award points to NGO (simulate completion)
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'totalDeliveriesReceived': FieldValue.increment(1),
      'impactPoints': FieldValue.increment(10),
      'rankScore': FieldValue.increment(10),
    });

    // Award points to Volunteer (simulate completion) - Stubbed bcoz of no volunteer ID.

    ScaffoldMessenger.of(Scaffold.of(context).context).showSnackBar(const SnackBar(content: Text(" Delivery skipped and confirmed for testing! NGO and Volunteer awarded sample points.")));
  }
}