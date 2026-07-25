import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_screen.dart';
import 'volunteer_profile_setup.dart';
import 'ngo_profile_setup.dart';
import 'donor_profile_setup.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(BuildContext context, String role) async {
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() => _isLoading = false);
        Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: role)));
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
        'email': user.email ?? '',
        'isProfileComplete': false,
      }, SetOptions(merge: true));

      if (!context.mounted) return;

      if (role == 'Volunteer') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VolunteerProfileSetup()));
      } else if (role == 'NGO') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const NgoProfileSetup()));
      } else if (role == 'Donor') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DonorProfileSetup()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFeatureItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.green.shade800),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildRoleCard({required String title, required String subtitle, required String badgeText, required IconData badgeIcon, required IconData mainIcon, required Color themeColor, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: themeColor.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: themeColor.withOpacity(0.12), blurRadius: 15, offset: const Offset(0, 5))]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14), border: Border.all(color: themeColor.withOpacity(0.3), width: 1)),
                  child: Icon(mainIcon, color: themeColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.3)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 12, color: themeColor),
                            const SizedBox(width: 4),
                            Text(badgeText, style: TextStyle(color: themeColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, color: themeColor.withOpacity(0.8), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Colors.green), SizedBox(height: 16), Text("Loading...", style: TextStyle(fontSize: 16, color: Colors.grey))]))
            : SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.green.shade50, border: Border.all(color: Colors.green.shade200, width: 1.5), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language, size: 18, color: Colors.green.shade800),
                        const SizedBox(width: 6),
                        Text("English", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.green.shade800),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

              Text("FoodHope", style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.green.shade800, letterSpacing: -1.0)),
              const SizedBox(height: 12),
              const Text("Choose your role to get started.", style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w500)),
              const SizedBox(height: 24),

              Wrap(
                spacing: 12, runSpacing: 10,
                children: [
                  _buildFeatureItem(Icons.verified, "Verified Users"),
                  _buildFeatureItem(Icons.location_on, "Live Tracking"),
                  _buildFeatureItem(Icons.leaderboard, "Local Rankings"),
                ],
              ),
              const SizedBox(height: 35),

              _buildRoleCard(
                title: "I want to Donate Food", subtitle: "Restaurants, events, hostel mess, or individuals with surplus food.", badgeText: "Earn points & top the City Leaderboard",
                badgeIcon: Icons.emoji_events, mainIcon: Icons.restaurant, themeColor: Colors.orange.shade800, onTap: () => _selectRole(context, "Donor"),
              ),

              _buildRoleCard(
                title: "I am a Volunteer", subtitle: "Pick up and deliver food. Become a Verified Volunteer.", badgeText: "Level up & save lives",
                badgeIcon: Icons.star, mainIcon: Icons.electric_bike, themeColor: Colors.green.shade700, onTap: () => _selectRole(context, "Volunteer"),
              ),

              _buildRoleCard(
                title: "I Distribute Food", subtitle: "NGOs and trusts that feed the needy.", badgeText: "Build trust & grow impact",
                badgeIcon: Icons.favorite, mainIcon: Icons.storefront, themeColor: Colors.teal.shade700, onTap: () => _selectRole(context, "NGO"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
