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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
        }

        if (snapshot.hasData && snapshot.data != null) {

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

                if (role.isNotEmpty && name.isEmpty) {
                  return const RoleSelectionScreen();
                }

                if (role == 'Volunteer') return const VolunteerDashboard();
                if (role == 'NGO') return const NgoDashboard();
                if (role == 'Donor') return const DonorDashboard();
              }

              return const RoleSelectionScreen();
            },
          );
        }

        return const LoginScreen();
      },
    );
  }
}