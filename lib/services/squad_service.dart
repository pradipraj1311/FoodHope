import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class SquadService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 1. Create a Role-Locked Squad
  static Future<String?> createSquad({
    required String name,
    required String description,
    required String creatorUid,
    required String city,
    required String role, 
  }) async {
    // Senior Dev Check: Prevent duplicate squad names in the same city and role
    QuerySnapshot existing = await _db.collection('squads')
        .where('city', isEqualTo: city)
        .where('role', isEqualTo: role)
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return "A squad with this name already exists in $city.";
    }

    String inviteCode = _generateInviteCode();
    DocumentReference squadRef = _db.collection('squads').doc();

    await _db.runTransaction((transaction) async {
      transaction.set(squadRef, {
        'name': name.trim(),
        'description': description,
        'inviteCode': inviteCode,
        'city': city,
        'role': role, 
        'totalPoints': 0,
        'memberCount': 1,
        'members': [creatorUid],
        'createdBy': creatorUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(_db.collection('users').doc(creatorUid), {
        'squadId': squadRef.id,
        'squadName': name.trim(),
      });
    });
    return null; // Success
  }

  // 2. Join Squad with Role Validation
  static Future<String?> joinSquadByCode(String code, String userUid) async {
    DocumentSnapshot userDoc = await _db.collection('users').doc(userUid).get();
    if (!userDoc.exists) return "User not found";
    String userRole = userDoc.get('role') ?? 'Volunteer';

    QuerySnapshot snap = await _db.collection('squads')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1).get();

    if (snap.docs.isEmpty) return "Invalid Code";

    DocumentSnapshot squadDoc = snap.docs.first;
    Map<String, dynamic> squadData = squadDoc.data() as Map<String, dynamic>;

    if (squadData['role'] != userRole) {
      return "This is a ${squadData['role']} squad. You cannot join as a $userRole.";
    }

    DocumentReference squadRef = squadDoc.reference;
    
    await _db.runTransaction((transaction) async {
      transaction.update(squadRef, {
        'members': FieldValue.arrayUnion([userUid]),
        'memberCount': FieldValue.increment(1),
      });
      transaction.update(_db.collection('users').doc(userUid), {
        'squadId': squadRef.id,
        'squadName': squadData['name'],
      });
    });
    return null; // Success
  }

  static Future<void> leaveSquad(String squadId, String userUid) async {
    DocumentReference squadRef = _db.collection('squads').doc(squadId);

    await _db.runTransaction((transaction) async {
      transaction.update(squadRef, {
        'members': FieldValue.arrayRemove([userUid]),
        'memberCount': FieldValue.increment(-1),
      });
      transaction.update(_db.collection('users').doc(userUid), {
        'squadId': null,
        'squadName': null,
      });
    });
  }

  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }
}
