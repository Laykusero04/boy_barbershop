import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/user_role.dart';

class AdminException implements Exception {
  AdminException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Manages user accounts and audit logs in Firestore.
class AdminRepository {
  AdminRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get _auditCol =>
      _db.collection('audit_logs');

  // ── Users ──────────────────────────────────────────────────────────

  /// Stream of all user profiles.
  Stream<List<AppUser>> watchAllUsers() {
    return _usersCol.orderBy('first_name').snapshots().map((snap) {
      return snap.docs
          .map((doc) => _docToUser(doc))
          .whereType<AppUser>()
          .toList();
    });
  }

  /// Create a new user account via Firebase Auth + Firestore profile.
  ///
  /// Because Firebase Admin SDK is not available in Flutter, we create the
  /// auth account with [FirebaseAuth.createUserWithEmailAndPassword] from
  /// the admin's session, then immediately re-authenticate the admin.
  /// This is the standard approach for Flutter-only projects without a
  /// backend.
  Future<void> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    required AppUser actingAdmin,
  }) async {
    // Remember current admin credentials – we will need to re-sign-in.
    final adminUser = _auth.currentUser;
    if (adminUser == null) throw AdminException('Not authenticated.');

    try {
      // 1. Create the new Firebase Auth account.
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final newUid = cred.user!.uid;

      // 2. Write the Firestore profile for the new user.
      await _usersCol.doc(newUid).set({
        'email': email.trim(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': _roleToInt(role),
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': actingAdmin.uid,
      });

      // 3. Log the action.
      await writeAuditLog(
        actorUid: actingAdmin.uid,
        actorName: actingAdmin.displayName,
        action: 'create_user',
        targetId: newUid,
        details: 'Created ${role.label} account for ${email.trim()}',
      );
    } on FirebaseAuthException catch (e) {
      throw AdminException(_authError(e));
    } on FirebaseException catch (e) {
      throw AdminException('Firestore error: ${e.message}');
    }
  }

  /// Update an existing user's profile fields (not password).
  Future<void> updateUser({
    required String uid,
    required String firstName,
    required String lastName,
    required UserRole role,
    required bool isActive,
    required AppUser actingAdmin,
  }) async {
    try {
      await _usersCol.doc(uid).update({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'role': _roleToInt(role),
        'is_active': isActive,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': actingAdmin.uid,
      });

      await writeAuditLog(
        actorUid: actingAdmin.uid,
        actorName: actingAdmin.displayName,
        action: 'update_user',
        targetId: uid,
        details:
            'Updated to ${role.label}, active=$isActive, name=$firstName $lastName',
      );
    } on FirebaseException catch (e) {
      throw AdminException('Could not update user: ${e.message}');
    }
  }

  /// Toggle a user's active state.
  Future<void> setUserActive({
    required String uid,
    required bool isActive,
    required AppUser actingAdmin,
  }) async {
    try {
      await _usersCol.doc(uid).update({
        'is_active': isActive,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': actingAdmin.uid,
      });

      await writeAuditLog(
        actorUid: actingAdmin.uid,
        actorName: actingAdmin.displayName,
        action: isActive ? 'enable_user' : 'disable_user',
        targetId: uid,
        details: isActive ? 'Enabled account' : 'Disabled account',
      );
    } on FirebaseException catch (e) {
      throw AdminException('Could not update user: ${e.message}');
    }
  }

  // ── Audit logs ─────────────────────────────────────────────────────

  /// Write one audit log entry.
  Future<void> writeAuditLog({
    required String actorUid,
    required String actorName,
    required String action,
    String? targetId,
    String? details,
  }) async {
    await _auditCol.add({
      'actor_uid': actorUid,
      'actor_name': actorName,
      'action': action,
      'target_id': targetId,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream the latest [limit] audit log entries (newest first).
  Stream<List<AuditLogEntry>> watchAuditLogs({int limit = 100}) {
    return _auditCol
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(_docToAuditLog).toList());
  }

  // ── Helpers ────────────────────────────────────────────────────────

  AppUser? _docToUser(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return null;
    final role = UserRole.fromInt((data['role'] as num?)?.toInt());
    if (role == null) return null;
    return AppUser(
      uid: doc.id,
      email: (data['email'] as String?)?.trim() ?? '',
      firstName: (data['first_name'] as String?)?.trim() ?? '',
      lastName: (data['last_name'] as String?)?.trim() ?? '',
      role: role,
    );
  }

  AuditLogEntry _docToAuditLog(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      actorUid: data['actor_uid'] as String? ?? '',
      actorName: data['actor_name'] as String? ?? '',
      action: data['action'] as String? ?? '',
      targetId: data['target_id'] as String?,
      details: data['details'] as String?,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  static int _roleToInt(UserRole role) => switch (role) {
        UserRole.admin => 1,
        UserRole.cashier => 2,
        UserRole.barber => 3,
      };

  static String _authError(FirebaseAuthException e) => switch (e.code) {
        'email-already-in-use' => 'That email is already registered.',
        'invalid-email' => 'Invalid email address.',
        'weak-password' => 'Password too weak (min 6 characters).',
        _ => 'Auth error: ${e.message}',
      };
}

/// A single audit log entry.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    this.targetId,
    this.details,
    this.timestamp,
  });

  final String id;
  final String actorUid;
  final String actorName;
  final String action;
  final String? targetId;
  final String? details;
  final DateTime? timestamp;
}
