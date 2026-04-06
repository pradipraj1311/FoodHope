import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'volunteer_dashboard.dart';
import 'ngo_dashboard.dart';
import 'donor_dashboard.dart';
import 'role_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? role;
  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  bool _isLoginMode = true;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = "";
  bool _isOtpSent = false;

  // --- STRICT ROUTING LOGIC (FIXED) ---
  Future<void> _routeUser(User user) async {
    // We must check Firestore to see if this user ACTUALLY finished registration
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!mounted) return;

    if (doc.exists && doc.data() != null) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String userRole = data['role'] ?? '';
      bool isVerified = data['isVerified'] ?? false;
      String name = data['name'] ?? data['distributorName'] ?? data['businessName'] ?? '';

      // If they have a role but no name/data, they haven't finished Profile Setup!
      if (userRole.isNotEmpty && name.isEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
        return;
      }

      if (userRole == 'Volunteer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerDashboard()));
      } else if (userRole == 'NGO') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NgoDashboard()));
      } else if (userRole == 'Donor') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonorDashboard()));
      } else {
        // Fallback: If role is corrupted
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
      }
    } else {
      // NEW USER (E.g., Just did Phone OTP for the first time)
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
    }
  }

  // --- EMAIL AUTH ---
  Future<void> _submitEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );

        if (!userCredential.user!.emailVerified) {
          await _auth.signOut();
          setState(() => _isLoading = false);
          _showUnverifiedLoginDialog(userCredential.user!);
          return;
        }

        await _routeUser(userCredential.user!);

      } else {
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );

        await userCredential.user!.sendEmailVerification();
        await _auth.signOut();

        setState(() => _isLoading = false);
        _showVerificationSentDialog(_emailController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Auth Failed"), backgroundColor: Colors.red.shade800));
      setState(() => _isLoading = false);
    }
  }

  // --- PHONE AUTH (STEP A) ---
  Future<void> _sendOtp() async {
    if (_phoneController.text.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid 10-digit number")));
      return;
    }
    setState(() => _isLoading = true);
    String phoneNumber = "+91${_phoneController.text.trim()}";

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential userCredential = await _auth.signInWithCredential(credential);
        await _routeUser(userCredential.user!);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Verification Failed: ${e.message}")));
        setState(() => _isLoading = false);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() { _verificationId = verificationId; _isOtpSent = true; _isLoading = false; });
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  // --- PHONE AUTH (STEP B) ---
  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) return;
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: _otpController.text.trim());
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _routeUser(userCredential.user!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP", style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  // --- UI DIALOGS ---
  void _showVerificationSentDialog(String email) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.mark_email_unread, color: Colors.green), SizedBox(width: 8), Text("Check Your Email")]),
        content: Text("We have sent a verification link to:\n\n$email\n\nPlease check your Inbox (and Spam folder) to verify your account, then come back here to log in."),
        actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white), onPressed: () { Navigator.pop(context); setState(() => _isLoginMode = true); }, child: const Text("I Understand"))]
    ));
  }

  void _showUnverifiedLoginDialog(User user) {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text("Email Not Verified")]),
        content: const Text("You must verify your email address before logging in. Please check your inbox (or spam) for the verification link."),
        actions: [
          TextButton(onPressed: () async { Navigator.pop(context); setState(() => _isLoading = true); try { await user.sendEmailVerification(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification email resent!"), backgroundColor: Colors.green)); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}"))); } setState(() => _isLoading = false); }, child: const Text("Resend Link", style: TextStyle(color: Colors.green))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text("OK"))
        ]
    ));
  }

  void _showPhoneBottomSheet() {
    showModalBottomSheet(
        context: context, isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (context) {
          return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Mobile Login", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87)),
                      const SizedBox(height: 8),
                      Text(_isOtpSent ? "Enter the 6-digit code sent to your phone." : "We'll send you a secure OTP to verify.", style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                      const SizedBox(height: 25),

                      if (!_isOtpSent) ...[
                        TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: "Phone Number", prefixText: "+91 ", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                        const SizedBox(height: 25),
                        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { setModalState(() => _isLoading = true); _sendOtp().then((_) => setModalState(() => _isLoading = false)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Send OTP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                      ] else ...[
                        TextField(controller: _otpController, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: "6-Digit OTP", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), counterText: "")),
                        const SizedBox(height: 25),
                        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { setModalState(() => _isLoading = true); _verifyOtp().then((_) => setModalState(() => _isLoading = false)); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Verify & Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              }
          );
        }
    ).whenComplete(() => setState(() { _isOtpSent = false; _phoneController.clear(); _otpController.clear(); }));
  }

  // --- BEAUTIFUL HERO UI COMPONENT ---
  Widget _buildServicePill(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- TOP HERO SECTION ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.shade50, Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.volunteer_activism, size: 60, color: Colors.green),
                    const SizedBox(height: 15),
                    Text("FoodHope", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    const Text("Bridging the gap between surplus food and those who need it most.", textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey)),
                    const SizedBox(height: 25),

                    // BRINGING BACK THE SERVICE HIGHLIGHTS!
                    Wrap(
                      spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
                      children: [
                        _buildServicePill("Donate Food", Icons.restaurant, Colors.orange),
                        _buildServicePill("Rescue & Deliver", Icons.directions_bike, Colors.green),
                        _buildServicePill("Receive at NGO", Icons.corporate_fare, Colors.teal),
                      ],
                    ),
                  ],
                ),
              ),

              // --- AUTH FORM SECTION ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isLoginMode ? "Welcome back" : "Create an account", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 20),

                    // EMAIL FIELDS
                    TextField(
                        controller: _emailController, keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(labelText: "Email Address", prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)
                    ),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _passwordController, obscureText: true,
                        decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton(
                            onPressed: _isLoading ? null : _submitEmailAuth,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isLoginMode ? "Login with Email" : "Register with Email", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                        )
                    ),

                    // TOGGLE LOGIN/REGISTER
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                        child: Text(_isLoginMode ? "Don't have an account? Register" : "Already have an account? Login", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    const SizedBox(height: 10),
                    Row(children: [Expanded(child: Divider(color: Colors.grey.shade300)), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold))), Expanded(child: Divider(color: Colors.grey.shade300))]),
                    const SizedBox(height: 25),

                    // PHONE BUTTON
                    SizedBox(
                      width: double.infinity, height: 55,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _showPhoneBottomSheet,
                        icon: const Icon(Icons.phone_android, color: Colors.black87),
                        label: const Text("Mobile Login (OTP)", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}