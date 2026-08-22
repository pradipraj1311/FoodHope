import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'landing_screen.dart';
import 'role_selection_screen.dart';
import 'volunteer_dashboard.dart';
import 'ngo_dashboard.dart';
import 'donor_dashboard.dart';
import 'volunteer_profile_setup.dart';
import 'ngo_profile_setup.dart';
import 'donor_profile_setup.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        if (snapshot.hasData && snapshot.data != null) {
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).snapshots(),
            builder: (context, docSnapshot) {
              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
              }

              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                Map<String, dynamic> data = docSnapshot.data!.data() as Map<String, dynamic>;
                String role = data['role'] ?? '';
                bool isComplete = data['isProfileComplete'] ?? false;
                String vStatus = data['verificationStatus'] ?? 'none';
                bool isSuspended = data['isSuspended'] ?? false;
                bool isAdmin = data['isAdmin'] ?? false;

                if (isSuspended) {
                  return const Scaffold(
                    backgroundColor: Color(0xFF0F172A),
                    body: Center(child: Text("ACCOUNT SUSPENDED BY ADMIN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  );
                }

                if (role.isEmpty) return const RoleSelectionScreen();
                if (!isComplete) {
                  if (role == 'Volunteer') return const VolunteerProfileSetup();
                  if (role == 'NGO') return const NgoProfileSetup();
                  if (role == 'Donor') return const DonorProfileSetup();
                }

                // Verification Gate (STRICT) - Admins skip
                if (vStatus != 'approved' && !isAdmin) {
                  return _buildVerificationTrackingScreen(vStatus);
                }

                if (role == 'Volunteer') return const VolunteerDashboard();
                if (role == 'NGO') return const NgoDashboard();
                if (role == 'Donor') return const DonorDashboard();
              }
              return const RoleSelectionScreen();
            },
          );
        }
        return const LandingScreen();
      },
    );
  }

  Widget _buildVerificationTrackingScreen(String status) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user_outlined, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 30),
              const Text("VERIFICATION STATUS", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 40),
              _statusLine("Documents Received", true),
              _statusLine("Identity Review", status == 'pending' || status == 'approved'),
              _statusLine("Final Approval", status == 'approved'),
              const SizedBox(height: 40),
              Text(status == 'pending' ? "Admin team is reviewing your profile. Usually takes 2-4 hours." : "Profile rejected. Contact support.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              const SizedBox(height: 40),
              TextButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text("Logout", style: TextStyle(color: Colors.redAccent)))
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusLine(String t, bool done) {
    return Row(children: [Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.greenAccent : Colors.white24), const SizedBox(width: 15), Text(t, style: TextStyle(color: done ? Colors.white : Colors.white24))]);
  }
}
