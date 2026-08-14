import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'otp_screen.dart';
import 'login_screen.dart';
import 'landing_screen.dart';

enum SignupMethod { none, email, phone }

class SignupScreen extends StatefulWidget {
  final String role;

  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  SignupMethod _selectedMethod = SignupMethod.none;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveUserToDatabase(String uid, String contactInfo, String name) async {
    // SENIOR DEV FIX: Initialize ranking fields during signup
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.isEmpty ? "Unknown User" : name,
      'contact': contactInfo,
      'role': widget.role,
      'createdAt': FieldValue.serverTimestamp(),
      'isProfileComplete': false,
      'rankScore': 0,
      'impactPoints': 0,
      'trustScore': 100,
      'isAdmin': false,
      'city': 'Pending',
    });
  }

  Future<void> signUpWithEmail() async {
    if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red));
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCredential.user!.sendEmailVerification();
      await _saveUserToDatabase(userCredential.user!.uid, emailController.text.trim(), nameController.text.trim());
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Verification email sent! Please check your inbox and log in."), duration: Duration(seconds: 5)),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(role: widget.role)));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.message}")));
    }
  }

  Future<void> signUpWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      String googleName = userCredential.user!.displayName ?? "Google User";
      String googleEmail = userCredential.user!.email ?? "";

      await _saveUserToDatabase(userCredential.user!.uid, googleEmail, googleName);
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google Registration Successful! Please log in.")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(role: widget.role)));
      }
    } catch (e) {
      print("Google Auth Error: $e");
    }
  }

  Future<void> signUpWithPhone() async {
    String phone = phoneController.text.trim();
    if (phone.isEmpty || nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Name and Phone number")));
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        await _saveUserToDatabase(userCredential.user!.uid, phone, nameController.text.trim());
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(role: widget.role)));
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Phone Auth Failed: ${e.message}")));
      },
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: verificationId,
                phone: phone,
                role: widget.role,
                name: nameController.text.trim(),
              ),
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.role} Sign Up"),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_selectedMethod != SignupMethod.none) {
              setState(() => _selectedMethod = SignupMethod.none);
            } else {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LandingScreen()));
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedMethod == SignupMethod.none) ...[
                const Text("Choose Registration Method", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.email),
                    label: const Text("Sign up with Email", style: TextStyle(fontSize: 16)),
                    onPressed: () => setState(() => _selectedMethod = SignupMethod.email),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    icon: const Icon(Icons.phone),
                    label: const Text("Sign up with Phone", style: TextStyle(fontSize: 16)),
                    onPressed: () => setState(() => _selectedMethod = SignupMethod.phone),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                    label: const Text("Sign up with Google", style: TextStyle(fontSize: 16)),
                    onPressed: signUpWithGoogle,
                  ),
                ),
              ],

              if (_selectedMethod == SignupMethod.email) ...[
                const Text("Register with Email", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: confirmPasswordController, obscureText: true, decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(onPressed: signUpWithEmail, child: const Text("Send Verification & Register", style: TextStyle(fontSize: 18))),
                ),
              ],

              if (_selectedMethod == SignupMethod.phone) ...[
                const Text("Register with Phone", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number (e.g. +91...)", border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                    onPressed: signUpWithPhone,
                    child: const Text("Send OTP", style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
