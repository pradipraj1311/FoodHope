import 'package:flutter/material.dart';
import 'screens/role_selection_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async {
  // Required to ensure Flutter framework is ready before Firebase initializes
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const FoodHopeApp());
}

class FoodHopeApp extends StatelessWidget {
  const FoodHopeApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodHope',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: RoleSelectionScreen(),
    );
  }
}