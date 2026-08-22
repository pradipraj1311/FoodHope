import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationEngine {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> processVolunteerDelivery({
    required String uid,
    required int mealQuantity, // Passing meal quantity for accurate stats
  }) async {
    int pointsToAdd = 20 + (mealQuantity > 50 ? 15 : 5);
    await _updateUserScores(uid, points: pointsToAdd, type: "delivery", quantity: mealQuantity);
  }

  static Future<void> processDonorDonation({
    required String uid,
    required int quantity,
  }) async {
    int pointsToAdd = 10 + (quantity > 50 ? 10 : 0);
    await _updateUserScores(uid, points: pointsToAdd, type: "donation", quantity: quantity);
  }

  static Future<void> _updateUserScores(String uid, {required int points, required String type, required int quantity}) async {
    DocumentReference userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      int currentPoints = data['impactPoints'] ?? 0;
      int totalMeals = data['totalMealsSaved'] ?? 0; // NEW: Track total meals (quantity)

      int newPoints = (currentPoints + points).clamp(0, 999999);
      int newMeals = totalMeals + quantity;

      Map<String, dynamic> updates = {
        'impactPoints': newPoints,
        'rankScore': newPoints + 200, // Rank based on points
        'totalMealsSaved': newMeals,
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      if (type == "delivery") updates['deliveriesMade'] = (data['deliveriesMade'] ?? 0) + 1;
      if (type == "donation") updates['donationsMade'] = (data['donationsMade'] ?? 0) + 1;

      transaction.update(userRef, updates);

      // Squad activity logic remains same but with null safety...
    });
  }
}
