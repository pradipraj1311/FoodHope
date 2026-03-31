import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationEngine {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- 1. VOLUNTEER POINTS ENGINE ---
  static Future<void> processVolunteerDelivery({
    required String uid,
    required double distanceKm,
    required int minsLeftAtPickup,
    required bool choseRecommendedHub,
  }) async {
    int basePoints = 20;
    int distanceBonus = 0;
    int urgencyBonus = 0;
    int recommendationBonus = choseRecommendedHub ? 10 : 0;
    int trustBoost = 2; // Successful delivery boosts hidden trust

    // Distance Math
    if (distanceKm <= 2) distanceBonus = 5;
    else if (distanceKm <= 5) distanceBonus = 10;
    else distanceBonus = 15;

    // Urgency Math
    if (minsLeftAtPickup < 60) urgencyBonus = 15;
    else if (minsLeftAtPickup <= 180) urgencyBonus = 10;
    else urgencyBonus = 5;

    int totalPointsEarned = basePoints + distanceBonus + urgencyBonus + recommendationBonus;

    await _updateUserScores(uid, impactPointsToAdd: totalPointsEarned, trustBoost: trustBoost);
  }

  // --- 2. DONOR POINTS ENGINE ---
  static Future<void> processDonorDonation({
    required String uid,
    required int quantity,
  }) async {
    int basePoints = 10;
    int accurateExpiryBonus = 5;
    int largeQuantityBonus = quantity >= 50 ? 10 : 0;
    int trustBoost = 2;

    int totalPointsEarned = basePoints + accurateExpiryBonus + largeQuantityBonus;

    // Check for streak/milestone bonuses
    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    int totalDonations = (doc.data() as Map<String, dynamic>)['totalDonationsMade'] ?? 0;

    if (totalDonations % 5 == 0) totalPointsEarned += 50; // Milestone bonus

    await _updateUserScores(uid, impactPointsToAdd: totalPointsEarned, trustBoost: trustBoost);
  }

  // --- 3. PENALTY ENGINE (ANTI-FRAUD) ---
  static Future<void> applyPenalty({
    required String uid,
    required String reason, // 'Cancel', 'Late', 'WrongLocation', 'Fake'
  }) async {
    int pointPenalty = 0;
    int trustPenalty = 0;

    switch (reason) {
      case 'Cancel': pointPenalty = -20; trustPenalty = -5; break;
      case 'Late': pointPenalty = -10; trustPenalty = 0; break;
      case 'WrongLocation': pointPenalty = -15; trustPenalty = -10; break;
      case 'Fake': pointPenalty = -100; trustPenalty = -50; break; // Massive drop
    }

    await _updateUserScores(uid, impactPointsToAdd: pointPenalty, trustBoost: trustPenalty);
  }

  // --- 4. THE CORE UPDATER & RANK CALCULATOR ---
  static Future<void> _updateUserScores(String uid, {required int impactPointsToAdd, required int trustBoost}) async {
    DocumentReference userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      int currentPoints = data['impactPoints'] ?? 0;
      int currentTrust = data['trustScore'] ?? 100; // Base trust is 100
      int currentConsistency = data['consistencyScore'] ?? 0;

      // Calculate new values (Prevent trust from dropping below 0 or above 100 easily)
      int newPoints = (currentPoints + impactPointsToAdd).clamp(0, 999999);
      int newTrust = (currentTrust + trustBoost).clamp(0, 100);

      // Level Calculation
      String newLevel = _calculateLevel(newPoints);

      // THE GOLDEN RANK FORMULA
      // Firestore cannot sort by math on the fly. We MUST save the final Rank Score to the database.
      int newRankScore = newPoints + (newTrust * 2) + currentConsistency;

      transaction.update(userRef, {
        'impactPoints': newPoints,
        'trustScore': newTrust,
        'level': newLevel,
        'rankScore': newRankScore, // Leaderboard will sort by this!
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static String _calculateLevel(int points) {
    if (points >= 3000) return 'Hero';
    if (points >= 1500) return 'Platinum';
    if (points >= 700) return 'Gold';
    if (points >= 300) return 'Silver';
    if (points >= 100) return 'Bronze';
    return 'Starter';
  }
  // --- UPDATED NGO RANK SCORE ---
  static Future<void> processNgoVerification({required String ngoUid}) async {
    // NGO Rank = (Deliveries * 10) + (Trust * 3) + (Consistency * 5)
    DocumentReference ngoRef = _db.collection('users').doc(ngoUid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(ngoRef);
      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      int deliveries = (data['totalDeliveriesReceived'] ?? 0) + 1;
      int trust = data['trustScore'] ?? 100;
      int consistency = data['consistencyScore'] ?? 0;
      int impactPoints = data['impactPoints'] ?? 0;

      int newRankScore = (deliveries * 10) + (trust * 3) + (consistency * 5);

      transaction.update(ngoRef, {
        'totalDeliveriesReceived': deliveries,
        'rankScore': newRankScore,
        'impactPoints': impactPoints + 10, // Base points per scan
      });
    });
  }
}