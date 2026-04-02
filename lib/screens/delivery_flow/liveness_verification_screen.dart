import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class LivenessVerificationScreen extends StatefulWidget {
  final String uid;
  final VoidCallback onSuccess;

  const LivenessVerificationScreen({super.key, required this.uid, required this.onSuccess});

  @override
  State<LivenessVerificationScreen> createState() => _LivenessVerificationScreenState();
}

class _LivenessVerificationScreenState extends State<LivenessVerificationScreen> {
  bool isScanning = false;
  String instruction = "Position your face in the frame";

  // Simulate an AI scan for UI demonstration purposes
  void _startMockScan() async {
    setState(() { isScanning = true; instruction = "Scanning facial landmarks..."; });
    await Future.delayed(const Duration(seconds: 2));
    setState(() => instruction = "Please blink twice slowly...");
    await Future.delayed(const Duration(seconds: 3));
    setState(() => instruction = "Liveness verified! 100% Human.");
    await Future.delayed(const Duration(seconds: 1));

    _verifyUserAndProceed();
  }

  Future<void> _verifyUserAndProceed() async {
    // 1. Mark them as verified in the database
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'isVerifiedVolunteer': true,
      'verifiedAt': DateTime.now(),
    });

    // 2. Go back to the feed and trigger the accept delivery logic!
    if (mounted) {
      Navigator.pop(context);
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Verify Identity"),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text("AI Liveness Check", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(instruction, style: TextStyle(color: Colors.green.shade400, fontSize: 16)),
            const SizedBox(height: 50),

            // THE SCANNER UI
            Center(
              child: Container(
                width: 250, height: 350,
                decoration: BoxDecoration(
                  border: Border.all(color: isScanning ? Colors.green : Colors.grey.shade800, width: 4),
                  borderRadius: BorderRadius.circular(150),
                ),
                child: isScanning
                    ? const Center(child: CircularProgressIndicator(color: Colors.green, strokeWidth: 6))
                    : const Icon(Icons.face, size: 100, color: Colors.white24),
              ),
            ),

            const Spacer(),

            if (!isScanning)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _startMockScan,
                    icon: const Icon(Icons.camera_front),
                    label: const Text("Start Camera Scan"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // --- THE DEVELOPER SKIP BUTTON ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: _verifyUserAndProceed,
                  icon: const Icon(Icons.developer_mode),
                  label: const Text("SKIP (TESTING MODE)"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}