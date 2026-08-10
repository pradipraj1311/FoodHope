import 'package:flutter/material.dart';
import 'admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  // IMPORTANT: Change these to your own secret values.
  // Do not share these or push the final versions to GitHub.
  final String _adminUser = "admin123"; 
  final String _adminPass = "foodhope@2024";

  void _login() {
    if (_userController.text == _adminUser && _passController.text == _adminPass) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Admin Credentials"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, color: Colors.greenAccent, size: 50),
              const SizedBox(height: 20),
              const Text("ADMIN ACCESS", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 30),
              TextField(controller: _userController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Username", labelStyle: TextStyle(color: Colors.white60))),
              const SizedBox(height: 15),
              TextField(controller: _passController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password", labelStyle: TextStyle(color: Colors.white60))),
              const SizedBox(height: 30),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _login, style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black), child: const Text("UNLOCK CENTER"))),
            ],
          ),
        ),
      ),
    );
  }
}
