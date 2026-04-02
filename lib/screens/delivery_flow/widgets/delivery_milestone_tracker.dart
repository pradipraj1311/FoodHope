import 'package:flutter/material.dart';

class DeliveryMilestoneTracker extends StatelessWidget {
  final String status;

  const DeliveryMilestoneTracker({super.key, required this.status});

  Widget _buildStep(String label, bool isActive) {
    return Column(
      children: [
        CircleAvatar(radius: 10, backgroundColor: isActive ? Colors.white : Colors.white30, child: isActive ? Icon(Icons.check, size: 14, color: Colors.green.shade700) : null),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? Colors.white : Colors.white70, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildLine(bool isActive) {
    return Expanded(child: Container(height: 2, color: isActive ? Colors.white : Colors.white30, margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10)));
  }

  @override
  Widget build(BuildContext context) {
    int step = 0;
    if (status == 'Accepted') step = 1;
    if (status == 'Picked Up') step = 2;
    if (status == 'En Route') step = 3;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStep("Post", true), _buildLine(step >= 1),
          _buildStep("Accepted", step >= 1), _buildLine(step >= 2),
          _buildStep("Picked", step >= 2), _buildLine(step >= 3),
          _buildStep("Confirmed", step >= 3), _buildLine(step >= 4),
          _buildStep("Delivered", step >= 4),
        ],
      ),
    );
  }
}