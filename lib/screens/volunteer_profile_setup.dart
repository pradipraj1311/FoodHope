import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'volunteer_dashboard.dart';

class VolunteerProfileSetup extends StatefulWidget {
  const VolunteerProfileSetup({super.key});

  @override
  State<VolunteerProfileSetup> createState() => _VolunteerProfileSetupState();
}

class _VolunteerProfileSetupState extends State<VolunteerProfileSetup> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _buildingController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final TextEditingController _restrictionsController = TextEditingController();

  String _selectedVehicle = 'Scooter / Motorcycle';
  String _selectedDistance = '10 km';
  String _selectedCapacity = 'Medium (10-50 meals)';
  String _selectedFoodPref = 'Any Food';
  String _selectedAvailability = 'Anytime';
  
  String _base64Image = '';
  bool _isLoading = false;
  String _currentCity = "Fetching...";

  final List<String> vehicleOptions = ['Bicycle', 'Scooter / Motorcycle', 'Car', 'Walking'];
  final List<String> distanceOptions = ['5 km', '10 km', '20 km', '50+ km'];
  final List<String> capacityOptions = ['Small (1-10 meals)', 'Medium (10-50 meals)', 'Large (50+ meals)'];
  final List<String> prefOptions = ['Any Food', 'Veg Only'];
  final List<String> availOptions = ['Anytime', 'Mornings', 'Evenings', 'Weekends'];

  @override
  void initState() {
    super.initState();
    _autoFetchLocation();
    User? user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _emailController.text = user!.email!;
    }
  }

  Future<void> _autoFetchLocation() async {
    setState(() => _currentCity = "Locating...");
    try {
      Position? position = await _determinePosition();
      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          setState(() {
            _currentCity = placemarks[0].locality ?? "Unknown City";
            if (_streetController.text.isEmpty) {
              _streetController.text = placemarks[0].subLocality ?? placemarks[0].street ?? "";
            }
          });
        }
      }
    } catch (e) {
      setState(() => _currentCity = "Location Error");
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 25);
    if (image != null) {
      List<int> imageBytes = await image.readAsBytes();
      setState(() => _base64Image = base64Encode(imageBytes));
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _completeSetup() async {
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || 
        _buildingController.text.isEmpty || _streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields (*)"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    User? user = FirebaseAuth.instance.currentUser;

    try {
      Position? position = await _determinePosition();
      String city = _currentCity;

      if (position != null) {
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          city = placemarks[0].locality ?? _currentCity;
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'contact': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'exactAddress': _buildingController.text.trim(),
        'streetName': _streetController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'vehicleType': _selectedVehicle,
        'maxDistance': _selectedDistance,
        'capacity': _selectedCapacity,
        'foodPreference': _selectedFoodPref,
        'availability': _selectedAvailability,
        'restrictions': _restrictionsController.text.trim(),
        'profileImageUrl': _base64Image,
        'latitude': position?.latitude ?? 0.0,
        'longitude': position?.longitude ?? 0.0,
        'city': city,
        'fullAddress': "${_buildingController.text.trim()}, ${_streetController.text.trim()}, $city",
        'isVerified': false,
        'trustScore': 100,
        'successRate': 100,
        'deliveriesMade': 0,
        'rankScore': 0,
        'isProfileComplete': true,
      });

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerDashboard()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Volunteer Setup"), automaticallyImplyLeading: false, backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Hero Details 🦸‍♂️", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green)),
            const SizedBox(height: 30),

            Align(
              alignment: Alignment.center,
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.green.shade50,
                      backgroundImage: _base64Image.isNotEmpty ? MemoryImage(base64Decode(_base64Image)) : null,
                      child: _base64Image.isEmpty ? const Icon(Icons.camera_alt, size: 40, color: Colors.green) : null,
                    ),
                  ),
                  if (_base64Image.isNotEmpty)
                    Positioned(
                      top: 0, right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _base64Image = ''),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Full Name *", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number *", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email Address (Optional)", border: OutlineInputBorder())),
            
            const Padding(
              padding: EdgeInsets.only(top: 25, bottom: 15),
              child: Text("Exact Location", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ),
            TextField(controller: _buildingController, decoration: const InputDecoration(labelText: "Flat / Building *", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _streetController, decoration: const InputDecoration(labelText: "Street / Road / Area *", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: _landmarkController, decoration: const InputDecoration(labelText: "Landmark (Optional)", border: OutlineInputBorder())),
            
            const Padding(
              padding: EdgeInsets.only(top: 25, bottom: 15),
              child: Text("Delivery Preferences", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
            ),

            DropdownButtonFormField<String>(
              value: _selectedVehicle,
              decoration: const InputDecoration(labelText: "Transport Type *", border: OutlineInputBorder()),
              items: vehicleOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedVehicle = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedDistance,
              decoration: const InputDecoration(labelText: "Max Distance *", border: OutlineInputBorder()),
              items: distanceOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedDistance = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedCapacity,
              decoration: const InputDecoration(labelText: "Max Capacity *", border: OutlineInputBorder()),
              items: capacityOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedCapacity = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedFoodPref,
              decoration: const InputDecoration(labelText: "Dietary Preference *", border: OutlineInputBorder()),
              items: prefOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedFoodPref = val!),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedAvailability,
              decoration: const InputDecoration(labelText: "Availability *", border: OutlineInputBorder()),
              items: availOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (val) => setState(() => _selectedAvailability = val!),
            ),
            const SizedBox(height: 15),
            TextField(controller: _restrictionsController, decoration: const InputDecoration(labelText: "Restrictions (Optional)", border: OutlineInputBorder())),

            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.red),
                const SizedBox(width: 5),
                Text("City: $_currentCity", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                const Spacer(),
                TextButton(onPressed: _autoFetchLocation, child: const Text("Refresh GPS"))
              ],
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isLoading ? null : _completeSetup,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("FINISH SETUP ✨", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
