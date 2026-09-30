import 'package:cloud_firestore/cloud_firestore.dart';

class GamificationEngine {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> processVolunteerDelivery({
    required String uid,
    required int mealQuantity,
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

  static Future<void> processNgoReception({
    required String ngoUid,
    required int mealQuantity,
  }) async {
    int pointsToAdd = (mealQuantity / 5).floor().clamp(5, 50); 
    await _updateUserScores(ngoUid, points: pointsToAdd, type: "reception", quantity: mealQuantity);
  }

  static Future<void> _updateUserScores(String uid, {required int points, required String type, required int quantity}) async {
    DocumentReference userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(userRef);
      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      int currentPoints = data['impactPoints'] ?? 0;
      
      int newPoints = (currentPoints + points).clamp(0, 999999);

      Map<String, dynamic> updates = {
        'impactPoints': newPoints,
        'rankScore': newPoints + 200, 
        'lastActiveAt': FieldValue.serverTimestamp(),
      };

      if (type == "delivery") {
        updates['deliveriesMade'] = (data['deliveriesMade'] ?? 0) + 1;
        updates['totalMealsSaved'] = (data['totalMealsSaved'] ?? 0) + quantity;
      }
      if (type == "donation") {
        updates['donationsMade'] = (data['donationsMade'] ?? 0) + 1;
        updates['totalMealsDonated'] = (data['totalMealsDonated'] ?? 0) + quantity;
      }
      if (type == "reception") {
        updates['deliveriesReceived'] = (data['deliveriesReceived'] ?? 0) + 1;
        updates['mealsReceived'] = (data['mealsReceived'] ?? 0) + quantity;
      }

      transaction.update(userRef, updates);
    });
  }
}
