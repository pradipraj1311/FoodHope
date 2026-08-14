import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationEngine {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> processVolunteerDelivery({
    required String uid,
    required double distanceKm,
    required int minsLeftAtPickup,
    required bool choseRecommendedHub,
  }) async {
    int basePoints = 20;
    int distanceBonus = distanceKm > 5 ? 15 : (distanceKm > 2 ? 10 : 5);
    int urgencyBonus = minsLeftAtPickup < 60 ? 15 : (minsLeftAtPickup <= 180 ? 10 : 5);
    int recommendationBonus = choseRecommendedHub ? 10 : 0;
    
    int totalPointsEarned = basePoints + distanceBonus + urgencyBonus + recommendationBonus;
    await _updateUserScores(uid, impactPointsToAdd: totalPointsEarned, trustBoost: 2);
  }

  static Future<void> processDonorDonation({
    required String uid,
    required int quantity,
  }) async {
    int basePoints = 10;
    int largeQuantityBonus = quantity >= 50 ? 10 : 0;
    int totalPointsEarned = basePoints + 5 + largeQuantityBonus;

    DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
    // Synchronized field name: donationsMade
    int totalDonations = (doc.data() as Map<String, dynamic>)['donationsMade'] ?? 0;

    if ((totalDonations + 1) % 5 == 0) totalPointsEarned += 50; 

    await _updateUserScores(uid, impactPointsToAdd: totalPointsEarned, trustBoost: 2);
  }

  static Future<void> _updateUserScores(String uid, {required int impactPointsToAdd, required int trustBoost}) async {
    DocumentReference userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;

      int currentPoints = data['impactPoints'] ?? 0;
      int currentTrust = data['trustScore'] ?? 100;
      int currentConsistency = data['consistencyScore'] ?? 0;

      int newPoints = (currentPoints + impactPointsToAdd).clamp(0, 999999);
      int newTrust = (currentTrust + trustBoost).clamp(0, 100);
      
      // THE GOLDEN RANK FORMULA
      int newRankScore = newPoints + (newTrust * 2) + currentConsistency;

      transaction.update(userRef, {
        'impactPoints': newPoints,
        'trustScore': newTrust,
        'rankScore': newRankScore,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
