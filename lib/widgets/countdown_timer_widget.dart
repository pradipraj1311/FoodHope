import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class CountdownTimerWidget extends StatefulWidget {
  final Timestamp? expiryTimestamp;
  const CountdownTimerWidget({super.key, this.expiryTimestamp});
  @override State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  Timer? _timer; String timeLeft = "Calculating..."; bool isExpired = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (mounted) _updateTime(); });
  }

  void _updateTime() {
    if (widget.expiryTimestamp == null) return;
    DateTime expiryTime = widget.expiryTimestamp!.toDate();
    Duration diff = expiryTime.difference(DateTime.now());

    if (diff.isNegative) {
      setState(() { timeLeft = "00:00:00 EXPIRED"; isExpired = true; });
      _timer?.cancel();
    } else {
      String h = diff.inHours.toString().padLeft(2, '0');
      String m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      String s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      setState(() => timeLeft = "$h:$m:$s left");
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.timer, size: 16, color: isExpired ? Colors.red : Colors.orange.shade800), const SizedBox(width: 6),
        Text(timeLeft, style: TextStyle(color: isExpired ? Colors.red : Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1)),
      ],
    );
  }
}