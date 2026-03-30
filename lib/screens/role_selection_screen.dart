import 'package:flutter/material.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedLanguage = 'English';

  final List<String> _languages = [
    'English', 'हिन्दी (Hindi)', 'ગુજરાતી (Gujarati)',
    'मराठी (Marathi)', 'தமிழ் (Tamil)', 'తెలుగు (Telugu)', 'বাংলা (Bengali)'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HIGH VISIBILITY LANGUAGE BUTTON ---
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: PopupMenuButton<String>(
                      initialValue: _selectedLanguage,
                      offset: const Offset(0, 45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      onSelected: (String newValue) {
                        setState(() => _selectedLanguage = newValue);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Language changed to $newValue")));
                      },
                      itemBuilder: (BuildContext context) {
                        return _languages.map((String lang) {
                          return PopupMenuItem<String>(
                            value: lang,
                            child: Text(lang, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          );
                        }).toList();
                      },
                      // BOLD, HIGH-CONTRAST BUTTON
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: Colors.green.shade700,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.language, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(_selectedLanguage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // --- EMOTIONAL HOOK & HEADER ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.volunteer_activism, size: 42, color: Colors.green),
              ),
              const SizedBox(height: 20),
              const Text(
                "Welcome to\nFood Hope.",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1.1, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                "Help save surplus food and feed people near you.", // Deep motivation
                style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 25),

              // --- TRUST SIGNALS (Wrapped to prevent overflow on small screens) ---
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildTrustSignal(Icons.domain_verification, "Verified NGOs"),
                  _buildTrustSignal(Icons.how_to_reg, "Verified Volunteers"),
                  _buildTrustSignal(Icons.emoji_events, "Local Rankings"),
                ],
              ),
              const SizedBox(height: 25),

              // --- ROLE CARDS WITH BOLD ICONS & MOTIVATIONAL HOOKS ---
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildRoleCard(
                      context,
                      title: "I want to Donate Food",
                      subtitle: "Restaurants, events, hostel mess, or individuals with surplus food.",
                      hintText: "🏆 Top the City Leaderboard & Save Food", // Localized motivation
                      icon: Icons.restaurant,
                      color: Colors.orange,
                      roleParam: "Donor",
                    ),
                    const SizedBox(height: 16),

                    _buildRoleCard(
                      context,
                      title: "I am a Volunteer",
                      subtitle: "Pick up and deliver food. Become a Verified local hero.",
                      hintText: "⭐ Climb Local Ranks & Earn Badges", // Localized motivation
                      icon: Icons.electric_moped,
                      color: Colors.green,
                      roleParam: "Volunteer",
                    ),
                    const SizedBox(height: 16),

                    _buildRoleCard(
                      context,
                      title: "I Distribute Food",
                      subtitle: "NGOs, Volunteer Groups, and Trusts that feed the needy.",
                      hintText: "🤝 Build trust & grow your impact", // Trust motivation
                      icon: Icons.storefront,
                      color: Colors.teal,
                      roleParam: "NGO",
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SMALL TRUST BADGE WIDGET ---
  Widget _buildTrustSignal(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.green.shade800), // Bolder Icon
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // --- STRONGER, GAMIFIED CARD WIDGET ---
  Widget _buildRoleCard(BuildContext context, {
    required String title,
    required String subtitle,
    required String hintText,
    required IconData icon,
    required MaterialColor color,
    required String roleParam,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen(role: roleParam)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.18), blurRadius: 20, offset: const Offset(0, 8))
          ],
          border: Border.all(color: color.shade100, width: 2.5), // Thicker border
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // BOLDER ICON CONTAINER
            Container(
              height: 65, width: 65,
              decoration: BoxDecoration(
                color: color.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.shade100, width: 1),
              ),
              child: Icon(icon, size: 38, color: color.shade800), // Larger, darker icon
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)),
                  const SizedBox(height: 12),

                  // MOTIVATIONAL HINT PILL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(6)),
                    child: Text(hintText, style: TextStyle(color: color.shade900, fontSize: 11, fontWeight: FontWeight.bold)), // Darker text
                  )
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade50, shape: BoxShape.circle),
              child: Icon(Icons.arrow_forward_rounded, size: 22, color: color.shade800), // Bolder arrow
            ),
          ],
        ),
      ),
    );
  }
}