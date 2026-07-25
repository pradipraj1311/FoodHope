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
          // Use StreamBuilder for user data to handle immediate updates when profile is completed
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

                // If user exists but role is not assigned, go to role selection
                if (role.isEmpty) {
                  return const RoleSelectionScreen();
                }

                // If role exists but profile setup is not done, route to specific setup screen
                if (!isComplete) {
                  if (role == 'Volunteer') return const VolunteerProfileSetup();
                  if (role == 'NGO') return const NgoProfileSetup();
                  if (role == 'Donor') return const DonorProfileSetup();
                }

                // If everything is complete, go to role dashboard
                if (role == 'Volunteer') return const VolunteerDashboard();
                if (role == 'NGO') return const NgoDashboard();
                if (role == 'Donor') return const DonorDashboard();
              }

              // Fallback for new users who don't have a doc yet
              return const RoleSelectionScreen();
            },
          );
        }

        // Not logged in
        return const LandingScreen();
      },
    );
  }
}
