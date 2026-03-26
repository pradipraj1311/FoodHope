import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class VolunteerProfileSetup extends StatefulWidget {
  const VolunteerProfileSetup({super.key});

  @override
  State<VolunteerProfileSetup> createState() => _VolunteerProfileSetupState();
}

class _VolunteerProfileSetupState extends State<VolunteerProfileSetup> {
  final TextEditingController affiliatedNgoController = TextEditingController();

  String selectedTransport = 'Two-Wheeler (Bike/Scooter)';
  final List<String> transportOptions = ['Walking', 'Two-Wheeler (Bike/Scooter)', 'Car', 'Large Van/Truck'];

  String selectedAvailability = 'Anytime / On-Call';
  final List<String> availabilityOptions = ['Weekday Mornings', 'Weekday Evenings', 'Weekends Only', 'Anytime / On-Call'];

  double travelRadius = 5.0;
  bool isAffiliatedWithNgo = false;
  bool isLoading = false;

  @override
  void dispose() {
    affiliatedNgoController.dispose();
    super.dispose();
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> saveProfile() async {
    setState(() => isLoading = true);

    try {
      Position? position = await _determinePosition();
      if (position == null) {
        setState(() => isLoading = false);
        return;
      }

      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'transportationMode': selectedTransport,
        'availability': selectedAvailability,
        'travelRadiusKm': travelRadius,
        'isAffiliatedWithNgo': isAffiliatedWithNgo,
        'affiliatedNgoName': isAffiliatedWithNgo ? affiliatedNgoController.text.trim() : "Independent",
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isProfileComplete': true,
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Volunteer Profile Complete!")));
    } catch (e) {
      print("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Volunteer Setup"), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selectedTransport,
              decoration: const InputDecoration(labelText: "Mode of Transportation", border: OutlineInputBorder()),
              items: transportOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedTransport = val!),
            ),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              value: selectedAvailability,
              decoration: const InputDecoration(labelText: "Typical Availability", border: OutlineInputBorder()),
              items: availabilityOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
              onChanged: (val) => setState(() => selectedAvailability = val!),
            ),
            const SizedBox(height: 25),

            Text("Willing to travel: ${travelRadius.toInt()} km", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Slider(
              value: travelRadius,
              min: 1, max: 30, divisions: 29,
              activeColor: Colors.green,
              label: "${travelRadius.toInt()} km",
              onChanged: (value) => setState(() => travelRadius = value),
            ),
            const Divider(height: 40),

            SwitchListTile(
              title: const Text("I am delivering for a specific NGO"),
              subtitle: const Text("Turn on if you are not an independent volunteer"),
              value: isAffiliatedWithNgo,
              activeColor: Colors.green,
              onChanged: (bool value) => setState(() => isAffiliatedWithNgo = value),
            ),

            if (isAffiliatedWithNgo) ...[
              const SizedBox(height: 10),
              TextField(
                controller: affiliatedNgoController,
                decoration: const InputDecoration(labelText: "Enter NGO Name or Invite Code", border: OutlineInputBorder()),
              ),
            ],

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: isLoading ? null : saveProfile,
                child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Base Location & Start", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}