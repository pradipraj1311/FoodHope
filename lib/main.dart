import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Make sure this matches your Firebase setup

// IMPORT YOUR NEW ROLE SELECTION SCREEN
import 'screens/role_selection_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Run the app
  runApp(const FoodHopeApp());
}

class FoodHopeApp extends StatelessWidget {
  const FoodHopeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Hope',
      debugShowCheckedModeBanner: false, // Removes the "DEBUG" banner
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto', // Or whatever font you prefer
      ),
      // THIS IS WHERE YOU SET THE STARTING SCREEN
      home: const RoleSelectionScreen(),
    );
  }
}