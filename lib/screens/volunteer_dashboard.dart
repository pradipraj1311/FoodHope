import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class VolunteerDashboard extends StatefulWidget {
  const VolunteerDashboard({super.key});

  @override
  State<VolunteerDashboard> createState() => _VolunteerDashboardState();
}

class _VolunteerDashboardState extends State<VolunteerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  int _currentIndex = 0;

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
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen(role: 'Volunteer')), (route) => false);
    }
  }

  // --- 1. UPDATE LOCATION (AUTO GPS) ---
  Future<void> _updateLocationWithGPS() async {
    setState(() => isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS.')));
        setState(() => isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => isLoading = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];

      String newCity = place.locality ?? "Unknown City";
      String newState = place.administrativeArea ?? "Unknown State";

      await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': newCity,
        'state': newState,
      });

      if (mounted) {
        setState(() {
          userData?['city'] = newCity;
          userData?['state'] = newState;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("GPS Location updated to $newCity!")));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- 2. UPDATE LOCATION (MANUAL TYPING) ---
  Future<void> _showEditCityDialog() async {
    TextEditingController cityController = TextEditingController(text: userData?['city']);

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Enter City Manually"),
          content: TextField(
            controller: cityController,
            decoration: const InputDecoration(
                hintText: "e.g., Nadiad",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city)
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              onPressed: () async {
                String newCity = cityController.text.trim();
                if (newCity.isNotEmpty) {
                  await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).update({'city': newCity});
                  if (mounted) {
                    setState(() => userData?['city'] = newCity);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("City updated to $newCity")));
                  }
                }
              },
              child: const Text("Save"),
            )
          ],
        )
    );
  }

  Future<void> _startDelivery(String donationId) async {
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'In Transit',
      'volunteerUid': currentUser!.uid,
      'volunteerName': userData?['name'] ?? 'Volunteer',
      'pickupTime': DateTime.now(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delivery Started! Please head to the donor.")));
  }

  Future<void> _completeDelivery(String donationId) async {
    await FirebaseFirestore.instance.collection('donations').doc(donationId).update({
      'status': 'Completed',
      'dropoffTime': DateTime.now(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Food Successfully Delivered! Great job!")));
  }

  Stream<QuerySnapshot> _getSmartStream(String userCity) {
    bool isAffiliated = userData?['isAffiliatedWithNgo'] ?? false;
    String ngoName = userData?['affiliatedNgoName'] ?? '';

    if (isAffiliated && ngoName.isNotEmpty) {
      return FirebaseFirestore.instance.collection('donations')
          .where('status', isEqualTo: 'Claimed')
          .where('claimedByName', isEqualTo: ngoName).snapshots();
    } else {
      return FirebaseFirestore.instance.collection('donations')
          .where('city', isEqualTo: userCity)
          .where('status', whereIn: ['Available', 'Claimed']).snapshots();
    }
  }

  // =========================================================
  // TAB 1: HOME FEED
  // =========================================================
  Widget _buildHomeTab(String userCity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('donations')
              .where('volunteerUid', isEqualTo: currentUser?.uid)
              .where('status', isEqualTo: 'In Transit').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

            var activePost = snapshot.data!.docs.first;
            // CRITICAL FIX: Safe data extraction to prevent crashes
            Map<String, dynamic> postData = activePost.data() as Map<String, dynamic>;
            String deliverTo = postData.containsKey('claimedByName') ? postData['claimedByName'] : 'Any Local NGO';

            return Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade600]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.directions_bike, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text("ACTIVE DELIVERY", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    ],
                  ),
                  const Divider(color: Colors.white54, height: 25),
                  Text("📦 ${postData['foodItem']}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text("📍 From: ${postData['businessName']}", style: const TextStyle(fontSize: 16, color: Colors.white)),
                  Text("🎯 To: $deliverTo", style: const TextStyle(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.deepOrange.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _completeDelivery(activePost.id),
                      child: const Text("Mark as Delivered", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            );
          },
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            (userData?['isAffiliatedWithNgo'] == true) ? "Pickups for ${userData?['affiliatedNgoName']}" : "Nearby Rescues",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _getSmartStream(userCity),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No active rescues in your city.\nCheck back later!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index];
                  // CRITICAL FIX: Safe data extraction
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;
                  bool isClaimed = postData['status'] == 'Claimed';
                  String claimedBy = postData.containsKey('claimedByName') ? postData['claimedByName'] : '';

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
                              Chip(
                                label: Text(postData['category'] ?? 'Food', style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.green.shade50,
                                side: BorderSide.none,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(children: [const Icon(Icons.storefront, size: 18, color: Colors.grey), const SizedBox(width: 8), Text(postData['businessName'], style: const TextStyle(fontSize: 15))]),
                          const SizedBox(height: 5),
                          if (isClaimed) Row(children: [const Icon(Icons.business, size: 18, color: Colors.blue), const SizedBox(width: 8), Text("To: $claimedBy", style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600))]),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity, height: 45,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () => _startDelivery(post.id),
                              icon: const Icon(Icons.motorcycle),
                              label: const Text("Accept Delivery", style: TextStyle(fontSize: 16)),
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

  // =========================================================
  // TAB 2: HISTORY
  // =========================================================
  Widget _buildHistoryTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Your Impact 🏆", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('donations')
                .where('volunteerUid', isEqualTo: currentUser?.uid)
                .where('status', isEqualTo: 'Completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("You haven't completed any deliveries yet.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var post = snapshot.data!.docs[index];
                  Map<String, dynamic> postData = post.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.check, color: Colors.green.shade800)),
                      title: Text(postData['foodItem'] ?? 'Food', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("From: ${postData['businessName']}"),
                      trailing: const Text("Delivered", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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

  // =========================================================
  // TAB 3: PROFILE
  // =========================================================
  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(radius: 50, backgroundColor: Colors.green, child: Icon(Icons.person, size: 50, color: Colors.white)),
        const SizedBox(height: 20),
        Text(userData?['name'] ?? 'Volunteer', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(userData?['contact'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 30),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.location_city, color: Colors.blue),
                title: const Text("Base City"),
                trailing: Text(userData?['city'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                onTap: _showEditCityDialog, // Tapping here also lets them change the city!
              ),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.moped), title: const Text("Vehicle"), trailing: Text(userData?['transportationMode'] ?? 'N/A')),
              const Divider(height: 0),
              ListTile(leading: const Icon(Icons.group), title: const Text("Affiliation"), trailing: Text((userData?['isAffiliatedWithNgo'] == true) ? userData!['affiliatedNgoName'] : "Independent")),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // NEW: Two options for Location Updating
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade700, padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _updateLocationWithGPS,
                icon: const Icon(Icons.gps_fixed),
                label: const Text("Auto GPS"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade50, foregroundColor: Colors.orange.shade800, padding: const EdgeInsets.all(12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: _showEditCityDialog,
                icon: const Icon(Icons.edit),
                label: const Text("Type City"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red, padding: const EdgeInsets.all(15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _logout,
          icon: const Icon(Icons.logout),
          label: const Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String userCity = userData?['city'] ?? 'Unknown City';

    final List<Widget> pages = [
      _buildHomeTab(userCity),
      _buildHistoryTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Hi, ${userData?['name']?.split(' ')[0] ?? 'Volunteer'} 👋", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            GestureDetector(
              onTap: _showEditCityDialog, // Tapping the location at the top opens the edit dialog!
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text("$userCity (Tap to change)", style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.green.shade700,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}