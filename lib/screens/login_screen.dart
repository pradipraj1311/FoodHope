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
  bool _isLoginMode = true; // Toggle between Login and Register

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  String _verificationId = "";
  bool _isOtpSent = false;

  // --- SMART ROUTING LOGIC ---
  Future<void> _routeUser(User user) async {
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (!mounted) return;

    if (doc.exists && doc.data() != null) {
      String userRole = doc['role'] ?? '';
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

  // --- NATIVE FIREBASE EMAIL VERIFICATION DIALOGS ---
  void _showVerificationSentDialog(String email) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.mark_email_unread, color: Colors.green), SizedBox(width: 8), Text("Check Your Email")]),
          content: Text("We have sent a verification link to:\n\n$email\n\nPlease check your Inbox (and Spam folder) to verify your account, then come back here to log in."),
          actions: [
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isLoginMode = true);
                },
                child: const Text("I Understand")
            )
          ],
        )
    );
  }

  void _showUnverifiedLoginDialog(User user) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange), SizedBox(width: 8), Text("Email Not Verified")]),
          content: const Text("You must verify your email address before logging in. Please check your inbox (or spam) for the verification link."),
          actions: [
            TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _isLoading = true);
                  try {
                    await user.sendEmailVerification();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Verification email resent! Check your inbox."), backgroundColor: Colors.green));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
                  }
                  setState(() => _isLoading = false);
                },
                child: const Text("Resend Link", style: TextStyle(color: Colors.green))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK")
            )
          ],
        )
    );
  }

  // --- FORGOT PASSWORD FLOW ---
  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter your email address first.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (mounted) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(children: [Icon(Icons.lock_reset, color: Colors.green), SizedBox(width: 8), Text("Password Reset")]),
              content: Text("If an account exists for ${_emailController.text.trim()}, we have sent a password reset link. Please check your email."),
              actions: [
                ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("OK")
                )
              ],
            )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- EMAIL AUTH (LOGIN & REGISTER WITH VERIFICATION) ---
  Future<void> _submitEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // --- LOGIN EXISTING USER ---
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );

        // Security Check: Did they click the email link?
        if (!userCredential.user!.emailVerified) {
          await _auth.signOut(); // Immediately sign them back out
          setState(() => _isLoading = false);
          _showUnverifiedLoginDialog(userCredential.user!);
          return;
        }

        await _routeUser(userCredential.user!);

      } else {
        // --- REGISTER NEW USER ---
        UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim()
        );

        // Send the native Firebase verification link
        await userCredential.user!.sendEmailVerification();

        // Sign them out immediately so they are forced to verify before logging in
        await _auth.signOut();

        setState(() => _isLoading = false);
        _showVerificationSentDialog(_emailController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      String errMsg = "Authentication Failed";
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        errMsg = "Incorrect email or password. Do you need to register?";
      } else if (e.code == 'email-already-in-use') {
        errMsg = "Account already exists! Please switch to Login.";
      } else if (e.code == 'weak-password') {
        errMsg = "Password is too weak. Use at least 6 characters.";
      } else {
        errMsg = e.message ?? errMsg;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg), backgroundColor: Colors.red.shade800));
      setState(() => _isLoading = false);
    }
  }

  // --- PHONE LOGIN (STEP A) ---
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

  // --- PHONE LOGIN (STEP B) ---
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo and Title
              const Icon(Icons.volunteer_activism, size: 70, color: Colors.green),
              const SizedBox(height: 15),
              Text("FoodHope", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: -0.5)),
              const SizedBox(height: 40),

              // Form Header
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_isLoginMode ? "Welcome back" : "Create an account", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              const SizedBox(height: 20),

              // EMAIL LOGIN/REGISTER SECTION
              TextField(
                  controller: _emailController, keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: "Email Address", prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)
              ),
              const SizedBox(height: 16),
              TextField(
                  controller: _passwordController, obscureText: true,
                  decoration: InputDecoration(labelText: "Password", prefixIcon: const Icon(Icons.lock_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)
              ),

              // --- FORGOT PASSWORD BUTTON ---
              if (_isLoginMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text("Forgot Password?", style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  ),
                )
              else
                const SizedBox(height: 24),

              SizedBox(
                  width: double.infinity, height: 55,
                  child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitEmailAuth,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_isLoginMode ? "Login" : "Register", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  )
              ),

              // TOGGLE LOGIN/REGISTER
              TextButton(
                onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                child: Text(_isLoginMode ? "Don't have an account? Register" : "Already have an account? Login", style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600)),
              ),

              const SizedBox(height: 20),
              Row(children: [Expanded(child: Divider(color: Colors.grey.shade300)), Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("OR", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold))), Expanded(child: Divider(color: Colors.grey.shade300))]),
              const SizedBox(height: 30),

              // PHONE BUTTON
              SizedBox(
                width: double.infinity, height: 55,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showPhoneBottomSheet,
                  icon: const Icon(Icons.phone_android, color: Colors.black87),
                  label: const Text("Mobile Login", style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: Colors.grey.shade300, width: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}