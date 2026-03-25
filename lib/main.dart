import 'package:flutter/material.dart';
import 'screens/role_selection_screen.dart';

void main() {
  runApp(FoodHopeApp());
}

class FoodHopeApp extends StatelessWidget {
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