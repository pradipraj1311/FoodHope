import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class ImpactWrappedScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const ImpactWrappedScreen({super.key, required this.userData});

  @override
  State<ImpactWrappedScreen> createState() => _ImpactWrappedScreenState();
}

class _ImpactWrappedScreenState extends State<ImpactWrappedScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    // Dynamic Month & Year
    String currentMonthYear = DateFormat('MMMM yyyy').format(DateTime.now());

    // Extract Stats
    String role = widget.userData['role'] ?? 'Hero';
    int score = widget.userData['rankScore'] ?? 0;
    int count = 0;
    if (role == 'Volunteer') count = widget.userData['deliveriesMade'] ?? 0;
    else if (role == 'Donor') count = widget.userData['donationsMade'] ?? 0;
    else count = widget.userData['deliveriesReceived'] ?? 0;

    // Derived Stats
    double co2Saved = count * 2.5; 
    int peopleFed = count * 15;

    String title = "Food Guardian";
    if (score > 500) title = "Sustainable GOAT 🐐";
    else if (score > 200) title = "Waste Warrior ⚔️";
    else if (score > 50) title = "Hope Bringer ✨";

    final pages = [
      _buildIntroPage(currentMonthYear),
      _buildStatPage("You've earned", "$score", "Impact Points", Colors.purpleAccent, Icons.stars),
      _buildStatPage("You've completed", "$count", role == 'Donor' ? "Donations" : "Rescues", Colors.greenAccent, Icons.auto_awesome),
      _buildStatPage("You prevented", "${co2Saved.toStringAsFixed(1)}kg", "CO2 Emissions", Colors.blueAccent, Icons.cloud_queue),
      _buildStatPage("You helped feed", "~$peopleFed", "Hungry Souls", Colors.orangeAccent, Icons.favorite),
      _buildSummaryPage(title, score, count, peopleFed, currentMonthYear),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: pages,
          ),
          Positioned(
            top: 60, left: 20, right: 20,
            child: Row(
              children: List.generate(pages.length, (index) => Expanded(
                child: Container(
                  height: 3, margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index <= _currentPage ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )),
            ),
          ),
          Positioned(
            top: 70, right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroPage(String date) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF1a2a6c), Color(0xFFb21f1f), Color(0xFFfdbb2d)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.volunteer_activism, size: 100, color: Colors.white),
            const SizedBox(height: 30),
            Text(
              "IMPACT\nWRAPPED\n${date.toUpperCase()}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1, height: 1.1),
            ),
            const SizedBox(height: 20),
            const Text("Swipe up to see your journey.", style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),
            const Icon(Icons.keyboard_double_arrow_down, color: Colors.white54, size: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatPage(String topText, String mainText, String bottomText, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 60),
          const SizedBox(height: 20),
          Text(topText, style: const TextStyle(color: Colors.white70, fontSize: 24)),
          Text(
            mainText,
            style: TextStyle(fontSize: 70, fontWeight: FontWeight.w900, color: color, letterSpacing: -3),
          ),
          Text(bottomText, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryPage(String title, int score, int count, int fed, String date) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF434343)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.2), blurRadius: 40)],
              ),
              child: Column(
                children: [
                  Text("IMPACT: $date", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.5)),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.green)),
                  const SizedBox(height: 20),
                  _buildSummaryRow(Icons.bolt, "$score", "Points"),
                  _buildSummaryRow(Icons.restaurant, "$count", "Actions"),
                  _buildSummaryRow(Icons.groups, "$fed", "Fed"),
                  const SizedBox(height: 20),
                  const Text("foodhope.app", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.share),
              label: const Text("SHARE STATS", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String val, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
