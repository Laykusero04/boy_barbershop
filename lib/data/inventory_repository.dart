import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/inventory_item.dart';

class InventoryWriteException implements Exception {
  InventoryWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class InventoryRepository {
  InventoryRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<InventoryItem>> watchActiveInventoryItems() {
    return FirestoreCollections.inventoryItems(_db)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
              .map((d) {
                final data = d.data();
                return InventoryItem(
                  id: d.id,
                  itemName: ((data['item_name'] as String?) ?? '').trim(),
                  stockQty: (data['stock_qty'] as num?)?.toDouble() ?? 0,
                  lowStockThreshold: (data['low_stock_threshold'] as num?)?.toInt() ?? 5,
                  unit: (data['unit'] as String?)?.trim(),
                  isActive: (data['is_active'] as bool?) ?? false,
                  createdAt: (data['created_at'] as Timestamp?)?.toDate(),
                );
              })
              .where((i) => i.itemName.isNotEmpty)
              .toList(growable: false);
            list.sort((a, b) =>
                a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
            return list;
          },
        );
  }

  Stream<List<InventoryItem>> watchAllInventoryItems() {
    // Sorted client-side to avoid Firestore composite indexes.
    return FirestoreCollections.inventoryItems(_db).snapshots().map((snap) {
      final list = snap.docs
          .map((d) {
            final data = d.data();
            return InventoryItem(
              id: d.id,
              itemName: ((data['item_name'] as String?) ?? '').trim(),
              stockQty: (data['stock_qty'] as num?)?.toDouble() ?? 0,
              lowStockThreshold: (data['low_stock_threshold'] as num?)?.toInt() ?? 5,
              unit: (data['unit'] as String?)?.trim(),
              isActive: (data['is_active'] as bool?) ?? false,
              createdAt: (data['created_at'] as Timestamp?)?.toDate(),
            );
          })
          .where((i) => i.itemName.isNotEmpty)
          .toList(growable: false);

      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        if (a.isLowStock != b.isLowStock) return a.isLowStock ? -1 : 1;
        return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
      });
      return list;
    });
  }

  Future<void> create({
    required String itemName,
    required double stockQty,
    required int lowStockThreshold,
    String? unit,
  }) async {
    final cleanedName = itemName.trim();
    final cleanedUnit = (unit ?? '').trim();
    if (cleanedName.isEmpty) throw InventoryWriteException('Item name is required.');
    if (stockQty.isNaN || stockQty.isInfinite || stockQty < 0) {
      throw InventoryWriteException('Stock must be 0 or greater.');
    }
    if (lowStockThreshold < 0) {
      throw InventoryWriteException('Low-stock threshold must be 0 or greater.');
    }

    try {
      await FirestoreCollections.inventoryItems(_db).add({
        'item_name': cleanedName,
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        'unit': cleanedUnit.isEmpty ? null : cleanedUnit,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw InventoryWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw InventoryWriteException('Could not save inventory item. Please try again.');
    }
  }

  Future<void> update({
    required String id,
    required String itemName,
    required double stockQty,
    required int lowStockThreshold,
    String? unit,
  }) async {
    final cleanedId = id.trim();
    final cleanedName = itemName.trim();
    final cleanedUnit = (unit ?? '').trim();
    if (cleanedId.isEmpty) throw InventoryWriteException('Invalid inventory item.');
    if (cleanedName.isEmpty) throw InventoryWriteException('Item name is required.');
    if (stockQty.isNaN || stockQty.isInfinite || stockQty < 0) {
      throw InventoryWriteException('Stock must be 0 or greater.');
    }
    if (lowStockThreshold < 0) {
      throw InventoryWriteException('Low-stock threshold must be 0 or greater.');
    }

    try {
      await FirestoreCollections.inventoryItems(_db).doc(cleanedId).update({
        'item_name': cleanedName,
        'stock_qty': stockQty,
        'low_stock_threshold': lowStockThreshold,
        'unit': cleanedUnit.isEmpty ? null : cleanedUnit,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw InventoryWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw InventoryWriteException('Could not update inventory item. Please try again.');
    }
  }

  Future<void> deactivate(String id) async {
    final cleanedId = id.trim();
    if (cleanedId.isEmpty) throw InventoryWriteException('Invalid inventory item.');
    try {
      await FirestoreCollections.inventoryItems(_db).doc(cleanedId).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw InventoryWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw InventoryWriteException('Could not deactivate inventory item.');
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

