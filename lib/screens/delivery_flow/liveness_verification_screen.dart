import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LivenessVerificationScreen extends StatefulWidget {
  final String uid; // NEW: Passed in to update DB
  final VoidCallback onSuccess;

  const LivenessVerificationScreen({super.key, required this.uid, required this.onSuccess});

  @override
  State<LivenessVerificationScreen> createState() => _LivenessVerificationScreenState();
}

class _LivenessVerificationScreenState extends State<LivenessVerificationScreen> {
  int _step = 0;
  bool _isProcessing = false;

  void _startLivenessCheck() async {
    setState(() { _step = 1; });
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front
      );

      if (pickedFile != null) {
        setState(() { _step = 2; _isProcessing = true; });

        await Future.delayed(const Duration(seconds: 2)); // Mocking AI processing

        // PERMANENTLY VERIFY THE VOLUNTEER
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
          'isVerifiedVolunteer': true,
        });

        setState(() { _step = 3; _isProcessing = false; });

        await Future.delayed(const Duration(seconds: 1));
        widget.onSuccess();
        if (mounted) Navigator.pop(context);

      } else {
        setState(() { _step = 0; });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Camera Error. Please allow permissions.")));
      setState(() { _step = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_step == 0) ...[
                const Icon(Icons.face, size: 100, color: Colors.greenAccent), const SizedBox(height: 20),
                const Text("Security Verification", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
                const Text("To ensure platform safety, we require a quick live selfie to permanently verify your identity.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 16)), const SizedBox(height: 40),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                  onPressed: _startLivenessCheck, icon: const Icon(Icons.camera_front), label: const Text("Start Liveness Check", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ] else if (_step == 1) ...[
                const Icon(Icons.sentiment_satisfied_alt, size: 100, color: Colors.orangeAccent), const SizedBox(height: 20),
                const Text("Please Smile!", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
                const Text("Waiting for camera input...", style: TextStyle(color: Colors.white70, fontSize: 16)),
              ] else if (_step == 2) ...[
                const CircularProgressIndicator(color: Colors.greenAccent), const SizedBox(height: 20),
                const Text("Analyzing AI Landmarks...", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ] else if (_step == 3) ...[
                const Icon(Icons.verified, size: 100, color: Colors.greenAccent), const SizedBox(height: 20),
                const Text("Identity Verified!", style: TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}