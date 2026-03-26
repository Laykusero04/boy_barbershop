import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/user_role.dart';

class UserProfileLoadException implements Exception {
  UserProfileLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Loads `users/{uid}` created alongside Firebase Auth.
Future<AppUser?> fetchUserProfile(String uid) async {
  DocumentSnapshot<Map<String, dynamic>> snap;
  try {
    snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  } on FirebaseException catch (e) {
    throw UserProfileLoadException(_firestoreErrorMessage(e));
  } on Object {
    throw UserProfileLoadException('Could not contact the server.');
  }

  if (!snap.exists) return null;
  final data = snap.data();
  if (data == null) return null;

  final role = UserRole.fromInt((data['role'] as num?)?.toInt());
  if (role == null) {
    throw UserProfileLoadException('Invalid account role.');
  }

  return AppUser(
    uid: uid,
    email: (data['email'] as String?)?.trim() ?? '',
    firstName: (data['first_name'] as String?)?.trim() ?? '',
    lastName: (data['last_name'] as String?)?.trim() ?? '',
    role: role,
  );
}

String _firestoreErrorMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Permission denied loading your profile. Check Firestore Rules.';
    case 'unavailable':
      return 'Service unavailable. Check your internet connection.';
    default:
      return 'Could not load your profile (${e.code}).';
  }
}
