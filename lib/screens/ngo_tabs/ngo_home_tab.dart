import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NgoHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const NgoHomeTab({super.key, required this.userData, required this.uid});

  @override
  State<NgoHomeTab> createState() => _NgoHomeTabState();
}

class _NgoHomeTabState extends State<NgoHomeTab> {

  // This will be linked to the OTP logic in the next phase!
  void _showOtpVerificationDialog(String donationId, String volunteerName) {
    TextEditingController otpController = TextEditingController();

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Verify Delivery"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Enter the 4-digit PIN provided by $volunteerName to confirm safe receipt of the food."),
              const SizedBox(height: 15),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ""),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () async {
                // In the next step, we will validate the OTP. For now, we mock success.
                await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
                  'status': 'Completed',
                  'dropoffTime': DateTime.now(),
                });

                // Increment NGO Impact Stats
                await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
                  'totalDeliveriesReceived': FieldValue.increment(1)
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery Verified Successfully!")));
                }
              },
              child: const Text("Verify & Complete", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.teal.shade800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Receiving Hub", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 5),
              Text(widget.userData['ngoName'] ?? 'NGO Dashboard', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Incoming Food Rescues", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Listens ONLY for food directed to this specific NGO that is on the way
            stream: FirebaseFirestore.instance.collection('donations')
                .where('selectedNgoId', isEqualTo: widget.uid)
                .where('status', isEqualTo: 'Picked Up')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.teal));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.radar, size: 60, color: Colors.grey.shade300),
                      const SizedBox(height: 15),
                      const Text("No volunteers are currently en route to your location.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index];
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 3,
                    shadowColor: Colors.teal.withOpacity(0.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.teal.shade100)),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.directions_car, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text("On The Way", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                              Text(postData['foodState'] ?? 'Food', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          const Divider(height: 20),

                          Text("📦 ${postData['foodItem']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Feeds approx ${postData['quantity']} people", style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w600)),

                          const SizedBox(height: 15),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Volunteer Details:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.person, size: 16, color: Colors.teal), const SizedBox(width: 8), Text(postData['volunteerName'] ?? 'Unknown')]),
                                const SizedBox(height: 4),
                                Row(children: [const Icon(Icons.phone, size: 16, color: Colors.teal), const SizedBox(width: 8), Text(postData['volunteerContact'] ?? 'Phone hidden')]),
                              ],
                            ),
                          ),

                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _showOtpVerificationDialog(post.id, postData['volunteerName'] ?? 'Volunteer'),
                              icon: const Icon(Icons.verified_user),
                              label: const Text("Verify & Receive Food", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
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