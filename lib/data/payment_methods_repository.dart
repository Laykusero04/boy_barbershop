import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/payment_method_item.dart';

class PaymentMethodWriteException implements Exception {
  PaymentMethodWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PaymentMethodsRepository {
  PaymentMethodsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<PaymentMethodItem>> watchAll() {
    return FirestoreCollections.paymentMethods(_db).snapshots().map((snap) {
      final list = snap.docs
          .map((d) {
            final data = d.data();
            return PaymentMethodItem(
              id: d.id,
              name: ((data['name'] as String?) ?? '').trim(),
              isActive: (data['is_active'] as bool?) ?? false,
              createdAt: (data['created_at'] as Timestamp?)?.toDate(),
            );
          })
          .where((m) => m.name.isNotEmpty)
          .toList(growable: false);

      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime != null && bTime != null) return aTime.compareTo(bTime);
        if (aTime != null) return -1;
        if (bTime != null) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return list;
    });
  }

  Future<void> create({required String name}) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw PaymentMethodWriteException('Name is required.');

    try {
      await FirestoreCollections.paymentMethods(_db).add({
        'name': cleaned,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PaymentMethodWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PaymentMethodWriteException('Could not save payment method.');
    }
  }

  Future<void> update({required String id, required String name}) async {
    final cleaned = name.trim();
    if (id.trim().isEmpty) throw PaymentMethodWriteException('Invalid method.');
    if (cleaned.isEmpty) throw PaymentMethodWriteException('Name is required.');

    try {
      await FirestoreCollections.paymentMethods(_db).doc(id).update({
        'name': cleaned,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PaymentMethodWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PaymentMethodWriteException('Could not update payment method.');
    }
  }

  Future<void> deactivate(String id) async {
    if (id.trim().isEmpty) throw PaymentMethodWriteException('Invalid method.');
    try {
      await FirestoreCollections.paymentMethods(_db).doc(id).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw PaymentMethodWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw PaymentMethodWriteException('Could not deactivate payment method.');
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

