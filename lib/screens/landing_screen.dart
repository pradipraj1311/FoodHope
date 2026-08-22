import 'package:flutter/material.dart';
import 'role_selection_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              // App Logo Placeholder
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.volunteer_activism, size: 80, color: Colors.green),
              ),
              const SizedBox(height: 20),
              const Text(
                "FoodHope",
                style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
              const Text(
                "RESCUE • FEED • REPEAT",
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const Spacer(),
              
              // Features Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFeatureBadge(Icons.bolt, "Flash Rescue"),
                        _buildFeatureBadge(Icons.groups, "Squads"),
                        _buildFeatureBadge(Icons.location_city, "City Rank"), // FIXED: Global -> City
                      ],
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Action Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
                child: SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.green.shade900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 10,
                    ),
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionScreen())),
                    child: const Text("GET STARTED", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
