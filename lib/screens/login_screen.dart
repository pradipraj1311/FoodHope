import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import 'donor_profile_setup.dart';
import 'ngo_profile_setup.dart';
import 'volunteer_profile_setup.dart';

class LoginScreen extends StatefulWidget {
  final String role; // Accepts the selected role

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // --- HELPER: CHECK DB & ROUTE ---
  Future<void> checkRoleAndRoute(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        String dbRole = userDoc.get('role');

        // Safely check if the profile is complete (defaults to false if field is missing)
        bool isProfileComplete = false;
        try {
          isProfileComplete = userDoc.get('isProfileComplete');
        } catch (e) {
          isProfileComplete = false;
        }

        print("Success: Logged in as $dbRole. Profile Complete: $isProfileComplete");

        if (!mounted) return;

        // --- THE TRAFFIC CONTROLLER ---
        if (!isProfileComplete) {
          // Route to specific Setup Screens if profile is incomplete
          if (dbRole == 'Donor') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DonorProfileSetup()));
          } else if (dbRole == 'NGO') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const NgoProfileSetup()));
          } else if (dbRole == 'Volunteer') {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VolunteerProfileSetup()));
          }
        } else {
          // Profile is complete! Route to actual Dashboards (Coming Next)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Welcome to the $dbRole Dashboard!")));

          // Example of what we will add next:
          // if (dbRole == 'Donor') Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DonorDashboard()));
        }
      } else {
        print("Error: No database record found for this user.");
      }
    } catch (e) {
      print("Database Route Error: $e");
    }
  }

  // --- 1. EMAIL LOGIN ---
  Future<void> loginWithEmail() async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      await checkRoleAndRoute(userCredential.user!.uid);
    } on FirebaseAuthException catch (e) {
      print("Login Error: ${e.message}");
    }
  }

  // --- 2. GOOGLE LOGIN ---
  Future<void> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email']);

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: clientAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      await checkRoleAndRoute(userCredential.user!.uid);
    } catch (e) {
      print("Google Login Error: $e");
    }
  }
  // --- 3. PHONE LOGIN ---
  Future<void> loginWithPhone() async {
    String phone = phoneController.text.trim();
    if (phone.isEmpty) return;

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        await checkRoleAndRoute(userCredential.user!.uid);
      },
      verificationFailed: (FirebaseAuthException e) {
        print("Phone Login Failed: ${e.message}");
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
                name: "Returning User",
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
      appBar: AppBar(title: Text("${widget.role} Login"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Welcome back, ${widget.role}!", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),

            // Email Login
            TextField(controller: emailController, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
            const SizedBox(height: 15),
            TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(onPressed: loginWithEmail, child: const Text("Login", style: TextStyle(fontSize: 18))),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text("OR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            ),

            // Google Login
            SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                onPressed: loginWithGoogle,
                icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.red),
                label: const Text("Login with Google", style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),

            // Phone Login
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                onPressed: loginWithPhone,
                child: const Text("Send OTP", style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),

            // Sign Up Link
            const SizedBox(height: 30),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => SignupScreen(role: widget.role)));
              },
              child: const Text("Don't have an account? Sign Up", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}