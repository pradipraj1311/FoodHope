import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DonorHomeTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String uid;

  const DonorHomeTab({super.key, required this.userData, required this.uid});

  @override
  State<DonorHomeTab> createState() => _DonorHomeTabState();
}

class _DonorHomeTabState extends State<DonorHomeTab> {

  Widget _requiredLabel(String text) {
    return Text.rich(
      TextSpan(
        text: text, style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
        children: const [TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
      ),
    );
  }

  void _showPostFoodSheet() {
    TextEditingController foodItemController = TextEditingController();
    TextEditingController quantityController = TextEditingController();
    String selectedCategory = 'Veg Only';
    String selectedExpiry = 'Within 2 Hours';

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Post a Food Rescue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),

                        TextField(
                          controller: foodItemController,
                          decoration: InputDecoration(label: _requiredLabel("Food Description (e.g., 50 Rotis, Rice)"), border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 15),

                        TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(label: _requiredLabel("Feeds approx how many people?"), border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: InputDecoration(label: _requiredLabel("Food Category"), border: const OutlineInputBorder()),
                          items: ['Veg Only', 'Non-Veg', 'Both Veg & Non-Veg', 'Packaged Snacks'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                          onChanged: (val) => setModalState(() => selectedCategory = val!),
                        ),
                        const SizedBox(height: 15),

                        DropdownButtonFormField<String>(
                          value: selectedExpiry,
                          decoration: InputDecoration(label: _requiredLabel("Must be picked up..."), border: const OutlineInputBorder()),
                          items: ['Within 1 Hour', 'Within 2 Hours', 'Within 4 Hours', 'By End of Day'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                          onChanged: (val) => setModalState(() => selectedExpiry = val!),
                        ),
                        const SizedBox(height: 25),

                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                            onPressed: () async {
                              if (foodItemController.text.isEmpty || quantityController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields!")));
                                return;
                              }

                              // CRITICAL: We attach the Donor's exact location to the food so Volunteers can find it!
                              await FirebaseFirestore.instance.collection('donations').add({
                                'donorUid': widget.uid,
                                'businessName': widget.userData['businessName'] ?? 'Local Donor',
                                'foodItem': foodItemController.text.trim(),
                                'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
                                'category': selectedCategory,
                                'expiry': selectedExpiry,
                                'status': 'Available',
                                'postedAt': DateTime.now(),
                                'city': widget.userData['city'] ?? 'Unknown',
                                'shortAddress': widget.userData['shortAddress'] ?? 'Unknown',
                                'latitude': widget.userData['latitude'],
                                'longitude': widget.userData['longitude'],
                              });

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food Alert Posted! Volunteers notified.")));
                              }
                            },
                            child: const Text("Publish Donation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 20),
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity, height: 60,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: _showPostFoodSheet,
              icon: const Icon(Icons.add_circle, size: 28),
              label: const Text("Post Food Rescue", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text("Active Donations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('donorUid', isEqualTo: widget.uid)
                .where('status', whereIn: ['Available', 'In Transit'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("You have no active food postings.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index];
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
                  bool isInTransit = postData['status'] == 'In Transit';

                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 15),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(postData['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isInTransit ? Colors.blue.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(postData['status'], style: TextStyle(color: isInTransit ? Colors.blue.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(children: [const Icon(Icons.people, size: 16, color: Colors.orange), const SizedBox(width: 8), Text("Feeds ${postData['quantity']}")]),
                          if (isInTransit) ...[
                            const SizedBox(height: 5),
                            Row(children: [const Icon(Icons.motorcycle, size: 16, color: Colors.blue), const SizedBox(width: 8), Text("Driver: ${postData['volunteerName']}", style: const TextStyle(fontWeight: FontWeight.bold))]),
                          ],
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                FirebaseFirestore.instance.collection('donations').doc(post.id).delete();
                              },
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text("Cancel Donation"),
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