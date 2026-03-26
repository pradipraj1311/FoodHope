import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'donor_dashboard.dart';
import 'donor_profile_setup.dart';
import 'ngo_profile_setup.dart';
import 'volunteer_profile_setup.dart';
import 'ngo_dashboard.dart';
import 'volunteer_dashboard.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phone;
  final String role;
  final String name;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phone,
    required this.role,
    required this.name,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController otpController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> verifyOTP() async {
    String otp = otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid 6-digit OTP")));
      return;
    }

    setState(() => isLoading = true);

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      String uid = userCredential.user!.uid;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      bool isProfileComplete = false;
      String currentRole = widget.role; // Default to the role they tapped on screen

      if (!userDoc.exists) {
        // NEW USER: Create fresh record
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': widget.name,
          'contact': widget.phone,
          'role': widget.role,
          'createdAt': DateTime.now(),
          'isProfileComplete': false,
        });
      } else {
        // RETURNING USER: Safely try to get data, fallback if it's an old dirty account
        try {
          currentRole = userDoc.get('role') ?? widget.role;
        } catch (e) {
          print("Warning: Old account missing role field.");
        }

        try {
          isProfileComplete = userDoc.get('isProfileComplete') ?? false;
        } catch (e) {
          print("Warning: Old account missing isProfileComplete field.");
        }
      }

      print("Success: OTP verified! Routing Role: $currentRole, Complete: $isProfileComplete");

      if (!mounted) return;

      // THE TRAFFIC CONTROLLER (Now Case-Insensitive!)
      String safeRole = currentRole.toLowerCase();

      if (!isProfileComplete) {
        // 1. INCOMPLETE PROFILES -> Go to Setup Screens
        if (safeRole.contains('donor')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DonorProfileSetup()), (route) => false);
        } else if (safeRole.contains('ngo')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const NgoProfileSetup()), (route) => false);
        } else if (safeRole.contains('volunteer')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const VolunteerProfileSetup()), (route) => false);
        } else {
          print("Error: Unknown Role - $safeRole");
        }
      } else {
        // 2. COMPLETE PROFILES -> Go to Dashboards
        print("Navigating to $currentRole Dashboard...");

        if (safeRole.contains('donor')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DonorDashboard()), (route) => false);
        } else if (safeRole.contains('ngo')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const NgoDashboard()), (route) => false);
        } else if (safeRole.contains('volunteer')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const VolunteerDashboard()), (route) => false);
        }
      }

    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("OTP Failed: ${e.message}")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verify OTP"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Code sent to ${widget.phone}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "------"),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: isLoading ? null : verifyOTP,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Verify & Enter", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}