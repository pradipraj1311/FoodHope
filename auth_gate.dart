import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'volunteer_dashboard.dart';
import 'ngo_dashboard.dart';
import 'donor_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to Auth state changes (Login, Logout, App Restart)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // 1. App is checking if user is logged in...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        // 2. USER IS LOGGED IN! (App was restarted, but they are still logged in)
        if (snapshot.hasData && snapshot.data != null) {

          // Now we must check Firestore to see WHICH dashboard they belong to
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, docSnapshot) {

              if (docSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
              }

              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                Map<String, dynamic> data = docSnapshot.data!.data() as Map<String, dynamic>;
                String role = data['role'] ?? '';
                String name = data['name'] ?? data['distributorName'] ?? data['businessName'] ?? '';

                // If they logged in but never finished profile setup, force them to Role Selection
                if (role.isNotEmpty && name.isEmpty) {
                  return const RoleSelectionScreen();
                }

                // MAGIC ROUTING: Send them straight to their dashboard!
                if (role == 'Volunteer') return const VolunteerDashboard();
                if (role == 'NGO') return const NgoDashboard();
                if (role == 'Donor') return const DonorDashboard();
              }

              // If they have no role in Firestore, ask them to pick one
              return const RoleSelectionScreen();
            },
          );
        }

        // 3. USER IS LOGGED OUT! (Or opened the app for the very first time)
        return const LoginScreen();
      },
    );
  }
}