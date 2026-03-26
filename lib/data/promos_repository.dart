import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/promo.dart';

class PromoWriteException implements Exception {
  PromoWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PromosRepository {
  PromosRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Promo>> watchAll() {
    return FirestoreCollections.promos(_db).snapshots().map((snap) {
      final list = snap.docs
          .map((d) {
            final data = d.data();
            return Promo(
              id: d.id,
              name: ((data['name'] as String?) ?? '').trim(),
              type: promoTypeFromString(data['promo_type'] as String?),
              value: (data['value'] as num?)?.toDouble() ?? 0,
              validFrom: ((data['valid_from'] as String?) ?? '').trim(),
              validTo: ((data['valid_to'] as String?) ?? '').trim(),
              isActive: (data['is_active'] as bool?) ?? false,
              createdAt: (data['created_at'] as Timestamp?)?.toDate(),
            );
          })
          .where((p) =>
              p.name.isNotEmpty && _isValidDay(p.validFrom) && _isValidDay(p.validTo))
          .toList(growable: false);

      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final at = a.createdAt;
        final bt = b.createdAt;
        if (at != null && bt != null) return at.compareTo(bt);
        if (at != null) return -1;
        if (bt != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  Stream<List<Promo>> watchActiveValidForDay(String day) {
    return FirestoreCollections.promos(_db)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) {
            final data = d.data();
            return Promo(
              id: d.id,
              name: ((data['name'] as String?) ?? '').trim(),
              type: promoTypeFromString(data['promo_type'] as String?),
              value: (data['value'] as num?)?.toDouble() ?? 0,
              validFrom: ((data['valid_from'] as String?) ?? '').trim(),
              validTo: ((data['valid_to'] as String?) ?? '').trim(),
              isActive: (data['is_active'] as bool?) ?? false,
              createdAt: (data['created_at'] as Timestamp?)?.toDate(),
            );
          })
          .where((p) =>
              p.name.isNotEmpty &&
              _isValidDay(p.validFrom) &&
              _isValidDay(p.validTo) &&
              p.isValidOnDay(day))
          .toList(growable: false);

      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> create({
    required String name,
    required PromoType type,
    required double value,
    required String validFrom,
    required String validTo,
  }) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw PromoWriteException('Promo name is required.');
    if (!_isValidDay(validFrom) || !_isValidDay(validTo)) {
      throw PromoWriteException('Valid from/to must be YYYY-MM-DD.');
    }

    final normalizedValue = type == PromoType.free ? 100.0 : value;
    if (normalizedValue.isNaN || normalizedValue.isInfinite || normalizedValue < 0) {
      throw PromoWriteException('Invalid value.');
    }

    try {
      await FirestoreCollections.promos(_db).add({
        'name': cleaned,
        'promo_type': promoTypeToString(type),
        'value': normalizedValue,
        'valid_from': validFrom,
        'valid_to': validTo,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PromoWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PromoWriteException('Could not save promo.');
    }
  }

  Future<void> update({
    required String id,
    required String name,
    required PromoType type,
    required double value,
    required String validFrom,
    required String validTo,
  }) async {
    final cleaned = name.trim();
    if (id.trim().isEmpty) throw PromoWriteException('Invalid promo.');
    if (cleaned.isEmpty) throw PromoWriteException('Promo name is required.');
    if (!_isValidDay(validFrom) || !_isValidDay(validTo)) {
      throw PromoWriteException('Valid from/to must be YYYY-MM-DD.');
    }

    final normalizedValue = type == PromoType.free ? 100.0 : value;
    if (normalizedValue.isNaN || normalizedValue.isInfinite || normalizedValue < 0) {
      throw PromoWriteException('Invalid value.');
    }

    try {
      await FirestoreCollections.promos(_db).doc(id).update({
        'name': cleaned,
        'promo_type': promoTypeToString(type),
        'value': normalizedValue,
        'valid_from': validFrom,
        'valid_to': validTo,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PromoWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PromoWriteException('Could not update promo.');
    }
  }

  Future<void> deactivate(String id) async {
    if (id.trim().isEmpty) throw PromoWriteException('Invalid promo.');
    try {
      await FirestoreCollections.promos(_db).doc(id).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PromoWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PromoWriteException('Could not deactivate promo.');
    }
  }

  Future<void> activate(String id) async {
    if (id.trim().isEmpty) throw PromoWriteException('Invalid promo.');
    try {
      await FirestoreCollections.promos(_db).doc(id).update({
        'is_active': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PromoWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PromoWriteException('Could not activate promo.');
    }
  }
}

bool _isValidDay(String value) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

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

