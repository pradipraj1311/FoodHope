import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Needed for logout routing

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? donorData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDonorDetails();
  }

  // Fetch the donor's details so we can attach their city/name to the food post
  Future<void> _fetchDonorDetails() async {
    if (currentUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (mounted) {
        setState(() {
          donorData = doc.data() as Map<String, dynamic>?;
          isLoading = false;
        });
      }
    }
  }

  // --- LOGOUT LOGIC ---
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      // Clears the entire navigation stack and sends them back to the Role Selection/Login
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen(role: 'Donor')),
              (route) => false
      );
    }
  }

  // --- POST NEW FOOD LOGIC (The Bottom Sheet) ---
  void _showAddDonationModal() {
    final TextEditingController foodItemController = TextEditingController();
    final TextEditingController quantityController = TextEditingController();
    String selectedCategory = 'Veg Only';
    String selectedExpiry = 'Within 2 hours';

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Post a Food Rescue", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                TextField(
                  controller: foodItemController,
                  decoration: const InputDecoration(labelText: "What food is available? (e.g., 50 Rotis & Dal)", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),

                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Feeds approximately how many people?", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: "Food Category", border: OutlineInputBorder()),
                  items: ['Veg Only', 'Non-Veg Only', 'Both Veg & Non-Veg'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (val) => selectedCategory = val!,
                ),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  value: selectedExpiry,
                  decoration: const InputDecoration(labelText: "Must be consumed within...", border: OutlineInputBorder()),
                  items: ['Within 2 hours', 'Within 4 hours', 'By End of Day', 'By Tomorrow Morning'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                  onChanged: (val) => selectedExpiry = val!,
                ),
                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (foodItemController.text.isEmpty || quantityController.text.isEmpty) return;

                      // Save to a new 'donations' collection in the database
                      await FirebaseFirestore.instance.collection('donations').add({
                        'donorUid': currentUser!.uid,
                        'businessName': donorData?['businessName'] ?? 'Unknown Business',
                        'foodItem': foodItemController.text.trim(),
                        'quantity': int.tryParse(quantityController.text.trim()) ?? 0,
                        'category': selectedCategory,
                        'expiry': selectedExpiry,
                        'status': 'Available', // Can be: Available, Claimed, Completed
                        'postedAt': DateTime.now(),
                        // Crucial for the matching algorithm later!
                        'city': donorData?['city'] ?? 'Unknown City',
                        'latitude': donorData?['latitude'],
                        'longitude': donorData?['longitude'],
                      });

                      if (mounted) {
                        Navigator.pop(context); // Close the modal
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food successfully posted! Volunteers are being notified.")));
                      }
                    },
                    child: const Text("Post Food Alert", style: TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text(donorData?['businessName'] ?? "Donor Dashboard"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      // --- REAL-TIME FEED OF THEIR POSTS ---
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('donations')
            .where('donorUid', isEqualTo: currentUser?.uid) // Only show THEIR posts
            .orderBy('postedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("You haven't posted any food yet. Click the + button to start!", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var post = snapshot.data!.docs[index];
              bool isAvailable = post['status'] == 'Available';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  title: Text(post['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Feeds: ${post['quantity']} people • ${post['category']}"),
                      Text("Consume: ${post['expiry']}", style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 10),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.green.shade100 : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          post['status'],
                          style: TextStyle(color: isAvailable ? Colors.green.shade800 : Colors.orange.shade800, fontWeight: FontWeight.bold),
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
      // --- THE BIG POST BUTTON ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        onPressed: _showAddDonationModal,
        icon: const Icon(Icons.add),
        label: const Text("Donate Food"),
      ),
    );
  }
}