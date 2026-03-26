import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/inventory_item.dart';

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
                  unit: (data['unit'] as String?)?.trim(),
                  isActive: (data['is_active'] as bool?) ?? false,
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
}

