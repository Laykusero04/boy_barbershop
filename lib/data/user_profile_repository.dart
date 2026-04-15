import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

/// Updates the user's email in both Firebase Auth and Firestore.
///
/// Requires [currentPassword] to re-authenticate before the sensitive change.
Future<void> updateUserEmail({
  required String uid,
  required String currentPassword,
  required String newEmail,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw UserProfileLoadException('Not signed in.');

  try {
    // Re-authenticate first (required by Firebase for email change).
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    // Update Firebase Auth email.
    await user.verifyBeforeUpdateEmail(newEmail.trim());

    // Update Firestore profile.
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'email': newEmail.trim(),
    });
  } on FirebaseAuthException catch (e) {
    throw UserProfileLoadException(_authErrorMessage(e));
  } on FirebaseException catch (e) {
    throw UserProfileLoadException(_firestoreErrorMessage(e));
  }
}

/// Updates the user's password in Firebase Auth.
///
/// Requires [currentPassword] to re-authenticate before the sensitive change.
Future<void> updateUserPassword({
  required String currentPassword,
  required String newPassword,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw UserProfileLoadException('Not signed in.');

  try {
    // Re-authenticate first.
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    // Update password.
    await user.updatePassword(newPassword);
  } on FirebaseAuthException catch (e) {
    throw UserProfileLoadException(_authErrorMessage(e));
  }
}

String _authErrorMessage(FirebaseAuthException e) {
  return switch (e.code) {
    'wrong-password' || 'invalid-credential' => 'Current password is incorrect.',
    'weak-password' => 'New password is too weak (min 6 characters).',
    'email-already-in-use' => 'That email is already in use.',
    'invalid-email' => 'Invalid email address.',
    'requires-recent-login' => 'Please log out and log back in, then try again.',
    _ => 'Error: ${e.message}',
  };
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
