import 'package:flutter/material.dart';
import 'dart:async';

class ActiveUrgencyTimer extends StatefulWidget {
  final DateTime safeExpiryTime;
  const ActiveUrgencyTimer({super.key, required this.safeExpiryTime});

  @override
  State<ActiveUrgencyTimer> createState() => _ActiveUrgencyTimerState();
}

class _ActiveUrgencyTimerState extends State<ActiveUrgencyTimer> {
  Timer? _timer;
  String timeLeft = "--:--:--";
  bool isExpired = false;
  String warningMessage = "";

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) { if (mounted) _updateTime(); });
  }

  void _updateTime() {
    Duration diff = widget.safeExpiryTime.difference(DateTime.now());
    if (diff.isNegative) {
      setState(() { timeLeft = "00:00:00"; isExpired = true; warningMessage = "⚠️ SAFE HUB WINDOW CLOSED"; });
      _timer?.cancel();
    } else {
      String h = diff.inHours.toString().padLeft(2, '0');
      String m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      String s = (diff.inSeconds % 60).toString().padLeft(2, '0');

      int totalMins = diff.inMinutes; String currentWarning = "";
      if (totalMins <= 5) currentWarning = "🚨 CRITICAL: Hub deadline in 5 mins!";
      else if (totalMins <= 10) currentWarning = "🚨 HURRY: 10 mins left to reach Hub!";
      else if (totalMins == 25 || totalMins == 30) currentWarning = "⚠️ Reminder: $totalMins mins to deadline.";

      setState(() { timeLeft = "$h:$m:$s"; warningMessage = currentWarning; });
    }
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white54)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer, color: isExpired ? Colors.redAccent : Colors.white, size: 16), const SizedBox(width: 6),
              Text(isExpired ? "EXPIRED FOR HUB" : "Delivery Deadline: $timeLeft", style: TextStyle(color: isExpired ? Colors.redAccent : Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
            ],
          ),
        ),
        if (warningMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade900, borderRadius: BorderRadius.circular(6)),
            child: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16), const SizedBox(width: 6), Text(warningMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))]),
          )
        ]
      ],
    );
  }
}