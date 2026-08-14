import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
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
  
  // Anti-Bot: Resend Cooldown
  int _resendCooldown = 60; 
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  @override
  void dispose() {
    otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> resendOTP() async {
    if (_resendCooldown > 0) return;
    
    setState(() => isLoading = true);
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      verificationCompleted: (_) {},
      verificationFailed: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}"))),
      codeSent: (id, _) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OTP Resent!")));
        _startCooldown();
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    setState(() => isLoading = false);
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
      String currentRole = widget.role;

      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'uid': uid,
          'name': widget.name,
          'contact': widget.phone,
          'role': widget.role,
          'createdAt': FieldValue.serverTimestamp(),
          'isProfileComplete': false,
          'rankScore': 0,
          'impactPoints': 0,
          'trustScore': 100,
          'isAdmin': false,
        });
      } else {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        currentRole = data['role'] ?? widget.role;
        isProfileComplete = data['isProfileComplete'] ?? false;
      }

      if (!mounted) return;

      String safeRole = currentRole.toLowerCase();

      if (!isProfileComplete) {
        if (safeRole.contains('donor')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const DonorProfileSetup()), (route) => false);
        } else if (safeRole.contains('ngo')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const NgoProfileSetup()), (route) => false);
        } else if (safeRole.contains('volunteer')) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const VolunteerProfileSetup()), (route) => false);
        }
      } else {
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
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Secure Verification"), centerTitle: true, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.verified_user_outlined, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            Text("Enter the 6-digit code sent to", style: TextStyle(color: Colors.grey.shade600)),
            Text(widget.phone, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: "",
                hintText: "------",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: isLoading ? null : verifyOTP,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("VERIFY & LOGIN", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: _resendCooldown == 0 ? resendOTP : null,
              child: Text(
                _resendCooldown == 0 ? "Resend SMS" : "Resend in ${_resendCooldown}s",
                style: TextStyle(color: _resendCooldown == 0 ? Colors.green.shade700 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
