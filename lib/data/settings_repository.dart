import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';

class SettingsWriteException implements Exception {
  SettingsWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SettingsRepository {
  SettingsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<double> watchDouble(
    String key, {
    required double defaultValue,
  }) {
    final cleanedKey = key.trim();
    if (cleanedKey.isEmpty) return Stream<double>.value(defaultValue);

    return FirestoreCollections.settings(_db).doc(cleanedKey).snapshots().map((doc) {
      final data = doc.data() ?? const <String, dynamic>{};
      final raw = data['value'];
      if (raw is num) return raw.toDouble();
      return defaultValue;
    });
  }

  Stream<double?> watchOptionalDouble(String key) {
    final cleanedKey = key.trim();
    if (cleanedKey.isEmpty) return Stream<double?>.value(null);

    return FirestoreCollections.settings(_db).doc(cleanedKey).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final raw = data['value'];
      if (raw is num) return raw.toDouble();
      return null;
    });
  }

  Future<void> setDouble(String key, double value) async {
    final cleanedKey = key.trim();
    if (cleanedKey.isEmpty) {
      throw SettingsWriteException('Invalid setting key.');
    }
    if (value.isNaN || value.isInfinite) {
      throw SettingsWriteException('Invalid value.');
    }

    try {
      await FirestoreCollections.settings(_db).doc(cleanedKey).set(
        {
          'value': value,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } on FirebaseException catch (e) {
      throw SettingsWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw SettingsWriteException('Could not save setting. Please try again.');
    }
  }
}

String _firestoreErrorMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Permission denied. Check Firestore Rules.';
    case 'unavailable':
      return 'Service unavailable. Check your internet connection.';
    default:
      return 'Request failed (${e.code}).';
  }
}

