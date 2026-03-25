import 'package:flutter/material.dart';
import '../widgets/role_card.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});
  void navigateToLogin(BuildContext context,String selectedRole ){
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context)=>LoginScreen(role:selectedRole),
      ),
    );
  }

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
              onTap: ()=>navigateToLogin(context,"Donor"),
            ),

            RoleCard(
              title: "Volunteer",
              icon: Icons.delivery_dining,
              onTap: ()=>navigateToLogin(context,"Volunteer"),
            ),

            RoleCard(
              title: "NGO",
              icon: Icons.groups,
              onTap: ()=>navigateToLogin(context,"NGO"),
            ),

            RoleCard(
              title: "Admin",
              icon: Icons.admin_panel_settings,
              onTap: ()=>navigateToLogin(context,"Admin"),
            ),

          ],
        ),
      ),
    );
  }
}