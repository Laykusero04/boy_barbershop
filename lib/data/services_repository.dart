import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/service_item.dart';

class ServiceWriteException implements Exception {
  ServiceWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ServicesRepository {
  ServicesRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<ServiceItem>> watchAllServices() {
    // Sorted client-side to avoid Firestore composite indexes.
    return FirestoreCollections.services(_db)
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
              .map((d) {
                final data = d.data();
                return ServiceItem(
                  id: d.id,
                  name: ((data['name'] as String?) ?? '').trim(),
                  defaultPrice: (data['default_price'] as num?)?.toDouble() ?? 0,
                  isActive: (data['is_active'] as bool?) ?? false,
                );
              })
              .where((s) => s.name.isNotEmpty)
              .toList(growable: false);

            list.sort((a, b) {
              if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
            return list;
          },
        );
  }

  Future<Map<String, double>> fetchInventoryUsage(String serviceId) async {
    if (serviceId.trim().isEmpty) return const {};
    final snap = await FirestoreCollections.services(_db)
        .doc(serviceId)
        .collection('inventory_usage')
        .get();

    final out = <String, double>{};
    for (final d in snap.docs) {
      final qty = (d.data()['quantity_per_service'] as num?)?.toDouble();
      if (qty != null && qty > 0) out[d.id] = qty;
    }
    return out;
  }

  Future<void> createService({
    required String name,
    required double defaultPrice,
    required Map<String, double> inventoryUsage,
  }) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) throw ServiceWriteException('Service name is required.');
    if (defaultPrice.isNaN || defaultPrice.isInfinite || defaultPrice < 0) {
      throw ServiceWriteException('Default price must be 0 or greater.');
    }

    try {
      final docRef = await FirestoreCollections.services(_db).add({
        'name': cleanedName,
        'default_price': defaultPrice,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _replaceInventoryUsage(docRef.id, inventoryUsage);
    } on FirebaseException catch (e) {
      throw ServiceWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ServiceWriteException('Could not save service. Please try again.');
    }
  }

  Future<void> updateService({
    required String serviceId,
    required String name,
    required double defaultPrice,
    required Map<String, double> inventoryUsage,
  }) async {
    final cleanedName = name.trim();
    if (serviceId.trim().isEmpty) throw ServiceWriteException('Invalid service.');
    if (cleanedName.isEmpty) throw ServiceWriteException('Service name is required.');
    if (defaultPrice.isNaN || defaultPrice.isInfinite || defaultPrice < 0) {
      throw ServiceWriteException('Default price must be 0 or greater.');
    }

    try {
      await FirestoreCollections.services(_db).doc(serviceId).update({
        'name': cleanedName,
        'default_price': defaultPrice,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _replaceInventoryUsage(serviceId, inventoryUsage);
    } on FirebaseException catch (e) {
      throw ServiceWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ServiceWriteException('Could not update service. Please try again.');
    }
  }

  Future<void> deactivateService(String serviceId) async {
    if (serviceId.trim().isEmpty) throw ServiceWriteException('Invalid service.');
    try {
      await FirestoreCollections.services(_db).doc(serviceId).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ServiceWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ServiceWriteException('Could not deactivate service. Please try again.');
    }
  }

  Future<void> _replaceInventoryUsage(
    String serviceId,
    Map<String, double> usage,
  ) async {
    final col = FirestoreCollections.services(_db)
        .doc(serviceId)
        .collection('inventory_usage');

    final existing = await col.get();
    final batch = _db.batch();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    usage.forEach((inventoryItemId, qty) {
      if (inventoryItemId.trim().isEmpty) return;
      if (qty.isNaN || qty.isInfinite || qty <= 0) return;
      batch.set(col.doc(inventoryItemId), {
        'quantity_per_service': qty,
        'updated_at': FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
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

