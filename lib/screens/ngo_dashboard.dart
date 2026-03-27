import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class NgoDashboard extends StatefulWidget {
  const NgoDashboard({super.key});

  @override
  State<NgoDashboard> createState() => _NgoDashboardState();
}

class _NgoDashboardState extends State<NgoDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    if (currentUser != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (mounted) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>?;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen(role: 'NGO')), (route) => false);
    }
  }

  Future<void> _claimFood(String donationId) async {
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Claimed',
      'claimedByUid': currentUser!.uid,
      'claimedByName': userData?['organizationName'] ?? 'NGO',
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food Claimed Successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String userCity = userData?['city'] ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(userData?['organizationName'] ?? "NGO Dashboard"),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Available Food in $userCity", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // THE MAGIC QUERY: Only show 'Available' food in their specific city
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('city', isEqualTo: userCity)
                  .where('status', isEqualTo: 'Available')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No food available in your area right now.", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var post = snapshot.data!.docs[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(post['foodItem'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Text("Feeds ${post['quantity']}", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                )
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text("📍 Donor: ${post['businessName']}", style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text("⏳ Expires: ${post['expiry']}", style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 15),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                                onPressed: () => _claimFood(post.id),
                                child: const Text("Claim This Food"),
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
      ),
    );
  }
}