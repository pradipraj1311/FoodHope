import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'admin_login_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Icon(Icons.language, size: 16, color: Colors.green),
                SizedBox(width: 4),
                Text("English", style: TextStyle(color: Colors.black87, fontSize: 12)),
                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.black87),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // HIDDEN TRIGGER: Long press the logo to open Admin Login
            GestureDetector(
              onLongPress: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.volunteer_activism, color: Colors.green, size: 30),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Welcome to\nFood Hope.",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Help save surplus food and feed people near you.",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _buildFeatureBadge(Icons.check_circle, "Verified Users"),
                const SizedBox(width: 12),
                _buildFeatureBadge(Icons.location_on, "Live Tracking"),
                const SizedBox(width: 12),
                _buildFeatureBadge(Icons.emoji_events, "Global Ranks"),
              ],
            ),
            const SizedBox(height: 40),
            
            _buildRoleCard(
              context,
              title: "I want to Donate Food",
              subtitle: "Restaurants, events, hostel mess, or individuals with surplus food.",
              pointsText: "Earn points & top the City Leaderboard",
              icon: Icons.restaurant,
              color: Colors.orange,
              role: 'Donor',
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              context,
              title: "I am a Volunteer",
              subtitle: "Pick up and deliver food. Become a Verified Volunteer on our platform.",
              pointsText: "Level up & climb the State/World ranks",
              icon: Icons.electric_moped,
              color: Colors.green,
              role: 'Volunteer',
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              context,
              title: "I Distribute Food",
              subtitle: "NGOs, Volunteer Groups, and Trusts that feed the needy.",
              pointsText: "Build trust & compete Globally",
              icon: Icons.corporate_fare,
              color: Colors.teal,
              role: 'NGO',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.green),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45)),
      ],
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String pointsText,
    required IconData icon,
    required Color color,
    required String role,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen(role: role)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events, size: 12, color: color),
                        const SizedBox(width: 4),
                        Text(pointsText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            Icon(Icons.arrow_forward, size: 20, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
