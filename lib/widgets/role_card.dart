import 'package:flutter/material.dart';

class RoleCard extends StatelessWidget {
    final String title;
    final IconData icon;
    final VoidCallback onTap;

  const RoleCard({
        super.key,
                required this.title,
                required this.icon,
                required this.onTap,
    });

    @override
    Widget build(BuildContext context) {
        return GestureDetector(
                onTap: onTap,
                child: Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
        child: ListTile(
                leading: Icon(icon, size: 35, color: Colors.green),
        title: Text(
                title,
                style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
            ),
          ),
        trailing: const Icon(Icons.arrow_forward),
        ),
      ),
    );
    }
}