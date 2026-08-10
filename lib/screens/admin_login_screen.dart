import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin_dashboard.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  void _login() {
    // Reading credentials from .env for security
    final String adminUser = dotenv.get('ADMIN_USER', fallback: 'admin');
    final String adminPass = dotenv.get('ADMIN_PASS', fallback: 'password');

    if (_userController.text == adminUser && _passController.text == adminPass) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Access Denied: Invalid Credentials"), 
          backgroundColor: Colors.red
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 350,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security, color: Colors.greenAccent, size: 50),
                const SizedBox(height: 20),
                const Text(
                  "ADMIN CONTROL", 
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)
                ),
                const SizedBox(height: 10),
                const Text(
                  "SECURE GATEWAY", 
                  style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _userController, 
                  style: const TextStyle(color: Colors.white), 
                  decoration: InputDecoration(
                    labelText: "Username", 
                    labelStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person, color: Colors.white60),
                  )
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passController, 
                  obscureText: true, 
                  style: const TextStyle(color: Colors.white), 
                  decoration: InputDecoration(
                    labelText: "Password", 
                    labelStyle: const TextStyle(color: Colors.white60),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white60),
                  )
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity, 
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _login, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, 
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ), 
                    child: const Text("UNLOCK SYSTEM", style: TextStyle(fontWeight: FontWeight.bold))
                  )
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
