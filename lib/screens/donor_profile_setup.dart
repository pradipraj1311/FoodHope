import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'donor_dashboard.dart';

class DonorProfileSetup extends StatefulWidget {
  const DonorProfileSetup({super.key});

  @override
  State<DonorProfileSetup> createState() => _DonorProfileSetupState();
}

class _DonorProfileSetupState extends State<DonorProfileSetup> {
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController contactNameController = TextEditingController();

  // New Dropdown States
  String selectedDonorType = 'Restaurant';
  final List<String> donorTypes = ['Restaurant', 'Hostel Mess', 'Hotel / Banquet', 'Supermarket', 'Individual / Other'];

  String selectedPickup = 'Front Desk / Reception';
  final List<String> pickupOptions = ['Front Desk / Reception', 'Kitchen / Back Door', 'Loading Dock', 'Call upon arrival'];

  String selectedFrequency = 'Occasional / Unpredictable';
  final List<String> frequencyOptions = ['Daily recurring', 'Occasional / Unpredictable', 'Weekends only'];

  bool hasFoodSafetyCert = false;
  bool isLoading = false;

  @override
  void dispose() {
    businessNameController.dispose();
    contactNameController.dispose();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enable GPS.')));
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
  Future<void> saveProfile() async {
    if (businessNameController.text.isEmpty || contactNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Business and Contact names.")));
      return;
    }
    setState(() => isLoading = true);

    try {
      Position? position = await _determinePosition();
      if (position == null) {
        setState(() => isLoading = false);
        return;
      }

      // NEW: Convert GPS to readable text
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      Placemark place = placemarks[0];
      String city = place.locality ?? "Unknown City";
      String state = place.administrativeArea ?? "Unknown State";
      String country = place.country ?? "Unknown Country";

      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'businessName': businessNameController.text.trim(),
        'primaryContactName': contactNameController.text.trim(),
        'donorType': selectedDonorType,
        'pickupInstructions': selectedPickup,
        'surplusFrequency': selectedFrequency,
        'hasFoodSafetyCert': hasFoodSafetyCert,
        // NEW: Location details
        'latitude': position.latitude,
        'longitude': position.longitude,
        'city': city,
        'state': state,
        'country': country,
        'address': "${place.street}, $city",
        'isProfileComplete': true,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Donor Profile Complete!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Donor Profile Setup"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(controller: businessNameController, decoration: const InputDecoration(labelText: "Business/Mess Name*", border: OutlineInputBorder())),
            const SizedBox(height: 15),

            TextField(controller: contactNameController, decoration: const InputDecoration(labelText: "Primary Contact Name*", border: OutlineInputBorder())),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedDonorType,
              decoration: const InputDecoration(labelText: "Facility Type", border: OutlineInputBorder()),
              items: donorTypes.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedDonorType = val!),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedFrequency,
              decoration: const InputDecoration(labelText: "How often do you have extra food?", border: OutlineInputBorder()),
              items: frequencyOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedFrequency = val!),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedPickup,
              decoration: const InputDecoration(labelText: "Pickup Instructions", border: OutlineInputBorder()),
              items: pickupOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedPickup = val!),
            ),
            const SizedBox(height: 20),

            CheckboxListTile(
              title: const Text("We follow local food safety guidelines"),
              value: hasFoodSafetyCert,
              onChanged: (val) => setState(() => hasFoodSafetyCert = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save & Get GPS Location", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}