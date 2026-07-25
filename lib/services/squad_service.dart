import 'package:cloud_firestore/cloud_firestore.dart';

class SquadService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Create a new Community Team (formerly Squad)
  static Future<void> createSquad({
    required String name,
    required String description,
    required String creatorUid,
    required String city,
    required String role, // NEW: Only users of the same role can join
  }) async {
    DocumentReference squadRef = _db.collection('squads').doc();
    
    await _db.runTransaction((transaction) async {
      // 1. Create the squad document
      transaction.set(squadRef, {
        'id': squadRef.id,
        'name': name,
        'description': description,
        'creatorUid': creatorUid,
        'members': [creatorUid],
        'totalRankScore': 0,
        'city': city,
        'role': role, // Only Volunteers for Volunteer teams, NGOs for NGO teams
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update user's squadId
      transaction.update(_db.collection('users').doc(creatorUid), {
        'squadId': squadRef.id,
        'squadName': name,
      });
    });
  }

  // Join an existing team
  static Future<void> joinSquad(String squadId, String userUid) async {
    DocumentReference squadRef = _db.collection('squads').doc(squadId);
    DocumentReference userRef = _db.collection('users').doc(userUid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot squadSnap = await transaction.get(squadRef);
      if (!squadSnap.exists) return;

      Map<String, dynamic> squadData = squadSnap.data() as Map<String, dynamic>;
      List<String> members = List<String>.from(squadData['members'] ?? []);
      
      if (!members.contains(userUid)) {
        members.add(userUid);
        transaction.update(squadRef, {'members': members});
        transaction.update(userRef, {
          'squadId': squadId,
          'squadName': squadData['name'],
        });
      }
    });
  }

  // Leave a team
  static Future<void> leaveSquad(String squadId, String userUid) async {
    DocumentReference squadRef = _db.collection('squads').doc(squadId);
    DocumentReference userRef = _db.collection('users').doc(userUid);

    await _db.runTransaction((transaction) async {
      DocumentSnapshot squadSnap = await transaction.get(squadRef);
      if (!squadSnap.exists) return;

      Map<String, dynamic> squadData = squadSnap.data() as Map<String, dynamic>;
      List<String> members = List<String>.from(squadData['members'] ?? []);
      
      members.remove(userUid);
      transaction.update(squadRef, {'members': members});
      transaction.update(userRef, {
        'squadId': FieldValue.delete(),
        'squadName': FieldValue.delete(),
      });
    });
  }

  // Update squad scores
  static Future<void> syncSquadScore(String squadId) async {
    QuerySnapshot membersSnap = await _db.collection('users').where('squadId', isEqualTo: squadId).get();
    
    int totalScore = 0;
    for (var doc in membersSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final rankScore = data['rankScore'] ?? 0;
      totalScore += (rankScore as num).toInt();
    }

    await _db.collection('squads').doc(squadId).update({
      'totalRankScore': totalScore,
    });
  }
}
