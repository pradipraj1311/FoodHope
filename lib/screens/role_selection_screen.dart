import 'package:flutter/material.dart';
import '../widgets/role_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FoodHope"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const SizedBox(height: 20),

            const Text(
              "Select Your Role",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            RoleCard(
              title: "Donor",
              icon: Icons.restaurant,
              onTap: () {
                print("Donor selected");
              },
            ),

            RoleCard(
              title: "Volunteer",
              icon: Icons.delivery_dining,
              onTap: () {
                print("Volunteer selected");
              },
            ),

            RoleCard(
              title: "NGO",
              icon: Icons.groups,
              onTap: () {
                print("NGO selected");
              },
            ),

            RoleCard(
              title: "Admin",
              icon: Icons.admin_panel_settings,
              onTap: () {
                print("Admin selected");
              },
            ),

          ],
        ),
      ),
    );
  }
}