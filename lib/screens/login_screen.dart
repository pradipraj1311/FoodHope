import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'volunteer_dashboard.dart';
import 'ngo_dashboard.dart';
import 'donor_dashboard.dart';
import 'volunteer_profile_setup.dart';
import 'ngo_profile_setup.dart';
import 'donor_profile_setup.dart';
import 'role_selection_screen.dart';
import 'landing_screen.dart';

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
  final TextEditingController _confirmPasswordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = "";
  bool _isOtpSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- SAVE INITIAL USER DATA (FIXED: Don't overwrite isProfileComplete) ---
  Future<void> _saveUserInitialData(User user) async {
    if (widget.role != null) {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      DocumentSnapshot doc = await userRef.get();
      
      if (!doc.exists) {
        // Only set initial data if user doesn't exist
        await userRef.set({
          'uid': user.uid,
          'email': user.email,
          'phone': user.phoneNumber,
          'role': widget.role,
          'isProfileComplete': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // If user exists, only update role if it's currently missing
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['role'] == null || data['role'].toString().isEmpty) {
          await userRef.update({'role': widget.role});
        }
      }
    }
  }

  // --- STRICT ROUTING LOGIC ---
  Future<void> _routeUser(User user) async {
    await _saveUserInitialData(user);

    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!mounted) return;

    if (doc.exists && doc.data() != null) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String userRole = data['role'] ?? widget.role ?? '';
      bool isComplete = data['isProfileComplete'] ?? false;

      if (userRole.isNotEmpty && !isComplete) {
        _navigateToSetup(userRole);
        return;
      }

      if (userRole == 'Volunteer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerDashboard()));
      } else if (userRole == 'NGO') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NgoDashboard()));
      } else if (userRole == 'Donor') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonorDashboard()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
      }
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
    }
  }

  void _navigateToSetup(String role) {
    if (role == 'Volunteer') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerProfileSetup()));
    } else if (role == 'NGO') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NgoProfileSetup()));
    } else if (role == 'Donor') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonorProfileSetup()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen()));
    }
  }

  // --- EMAIL AUTH ---
  Future<void> _submitEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields")));
      return;
    }

    if (!_isLoginMode && _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red));
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

        await _saveUserInitialData(userCredential.user!);
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

  // --- PHONE AUTH ---
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

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) return;
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId, smsCode: _otpController.text.trim());
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _routeUser(userCredential.user!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP"), backgroundColor: Colors.red));
      setState(() => _isLoading = false);
    }
  }

  // --- UI DIALOGS ---
  void _showVerificationSentDialog(String email) {
    showDialog(context: context, barrierDismissible: false, builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.mark_email_unread, color: Colors.green), SizedBox(width: 8), Text("Check Your Email")]),
        content: Text("We have sent a verification link to:\n\n$email\n\nPlease verify your account then log in."),
        actions: [ElevatedButton(onPressed: () { Navigator.pop(context); setState(() => _isLoginMode = true); }, child: const Text("OK"))]
    ));
  }

  void _showUnverifiedLoginDialog(User user) {
    showDialog(context: context, builder: (context) => AlertDialog(
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text("Email Not Verified")]),
        content: const Text("Please verify your email address before logging in."),
        actions: [
          TextButton(onPressed: () async { Navigator.pop(context); await user.sendEmailVerification(); }, child: const Text("Resend Link")),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))
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
                      Text("${widget.role ?? ''} Login", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 25),
                      if (!_isOtpSent) ...[
                        TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", prefixText: "+91 ", border: OutlineInputBorder())),
                        const SizedBox(height: 25),
                        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { _sendOtp(); }, child: const Text("Send OTP"))),
                      ] else ...[
                        TextField(controller: _otpController, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: "6-Digit OTP", border: OutlineInputBorder())),
                        const SizedBox(height: 25),
                        SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: () { _verifyOtp(); }, child: const Text("Verify & Login"))),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = Colors.green.shade700;
    if (widget.role == 'Donor') themeColor = Colors.orange.shade700;
    if (widget.role == 'NGO') themeColor = Colors.teal.shade700;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LandingScreen())),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [themeColor.withOpacity(0.1), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                ),
                child: Column(
                  children: [
                    Icon(
                        widget.role == 'Donor' ? Icons.restaurant :
                        widget.role == 'NGO' ? Icons.corporate_fare :
                        Icons.volunteer_activism,
                        size: 60, color: themeColor
                    ),
                    const SizedBox(height: 15),
                    Text(
                        "${widget.role ?? 'FoodHope'} Login",
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: themeColor)
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    TextField(controller: _emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
                    if (!_isLoginMode) ...[
                      const SizedBox(height: 16),
                      TextField(controller: _confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder())),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: themeColor), onPressed: _submitEmailAuth, child: Text(_isLoginMode ? "Login" : "Register"))),
                    TextButton(onPressed: () => setState(() => _isLoginMode = !_isLoginMode), child: Text(_isLoginMode ? "Need an account? Register" : "Have an account? Login")),
                    const Divider(),
                    SizedBox(width: double.infinity, height: 55, child: OutlinedButton(onPressed: _showPhoneBottomSheet, child: const Text("Login with OTP"))),
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
