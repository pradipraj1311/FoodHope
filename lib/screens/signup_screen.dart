import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'otp_screen.dart';
import 'login_screen.dart'; // Required for the redirect

// This tracks which signup method the user selected
enum SignupMethod { none, email, phone }

class SignupScreen extends StatefulWidget {
  final String role;

  const SignupScreen({super.key, required this.role});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Start with no method selected (shows the 3 main buttons)
  SignupMethod _selectedMethod = SignupMethod.none;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // --- HELPER: SAVE TO FIRESTORE ---
  Future<void> _saveUserToDatabase(String uid, String contactInfo, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'name': name.isEmpty ? "Unknown User" : name,
      'contact': contactInfo,
      'role': widget.role,
      'createdAt': DateTime.now(),
      'isProfileComplete': false, // Ready for your next progressive profiling step!
    });
  }

  // --- 1. EMAIL SIGNUP (With Verification & Redirect) ---
  Future<void> signUpWithEmail() async {
    if (nameController.text.trim().isEmpty || emailController.text.trim().isEmpty || passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    try {
      // 1. Create the user
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // 2. Send the verification email
      await userCredential.user!.sendEmailVerification();

      // 3. Save basic details to database
      await _saveUserToDatabase(userCredential.user!.uid, emailController.text.trim(), nameController.text.trim());

      // 4. Sign them out immediately so they are forced to verify before actually logging in
      await FirebaseAuth.instance.signOut();

      // 5. Show success message and redirect to Login
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

  // --- 2. GOOGLE SIGNUP (No fields needed, gets info directly from Google) ---
  Future<void> signUpWithGoogle() async {
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

      // Grab Name and Email straight from their Google Account
      String googleName = userCredential.user!.displayName ?? "Google User";
      String googleEmail = userCredential.user!.email ?? "";

      await _saveUserToDatabase(userCredential.user!.uid, googleEmail, googleName);

      // Force sign out and redirect to login per your flow
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google Registration Successful! Please log in.")));
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(role: widget.role)));
      }
    } catch (e) {
      print("Google Auth Error: $e");
    }
  }

  // --- 3. PHONE SIGNUP (Needs Name & Phone only) ---
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
          // Send them to OTP screen. The OTP screen handles the database save & redirect!
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
        leading: _selectedMethod != SignupMethod.none
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedMethod = SignupMethod.none), // Go back to options
        )
            : null, // Default back button behavior
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // ==========================================
              // VIEW 1: SELECT A METHOD (Shows Initially)
              // ==========================================
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
                    onPressed: signUpWithGoogle, // Processes immediately, no form needed!
                  ),
                ),
              ],

              // ==========================================
              // VIEW 2: EMAIL FORM
              // ==========================================
              if (_selectedMethod == SignupMethod.email) ...[
                const Text("Register with Email", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: emailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder())),
                const SizedBox(height: 15),
                TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder())),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(onPressed: signUpWithEmail, child: const Text("Send Verification & Register", style: TextStyle(fontSize: 18))),
                ),
              ],

              // ==========================================
              // VIEW 3: PHONE FORM
              // ==========================================
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