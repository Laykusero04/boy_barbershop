import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/payment_method_item.dart';
import 'package:boy_barbershop/models/service_item.dart';

class CatalogRepository {
  CatalogRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Barber>> watchActiveBarbers() {
    return FirestoreCollections.barbers(_db)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
              .map(
                (d) => Barber(
                  id: d.id,
                  name: ((d.data()['name'] as String?) ?? '').trim(),
                  percentageShare:
                      (d.data()['percentage_share'] as num?)?.toDouble() ?? 0,
                  isActive: (d.data()['is_active'] as bool?) ?? false,
                ),
              )
              .where((b) => b.name.isNotEmpty)
              .toList(growable: false);
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            return list;
          },
        );
  }

  Stream<List<ServiceItem>> watchActiveServices() {
    return FirestoreCollections.services(_db)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
              .map((d) {
                final data = d.data();
                final defaultPrice = (data['default_price'] as num?)?.toDouble() ?? 0;
                return ServiceItem(
                  id: d.id,
                  name: ((data['name'] as String?) ?? '').trim(),
                  defaultPrice: defaultPrice,
                  isActive: (data['is_active'] as bool?) ?? false,
                );
              })
              .where((s) => s.name.isNotEmpty)
              .toList(growable: false);
            list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            return list;
          },
        );
  }

  Stream<List<PaymentMethodItem>> watchActivePaymentMethods() {
    return FirestoreCollections.paymentMethods(_db)
        .where('is_active', isEqualTo: true)
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
              .map(
                (d) => PaymentMethodItem(
                  id: d.id,
                  name: ((d.data()['name'] as String?) ?? '').trim(),
                  isActive: (d.data()['is_active'] as bool?) ?? false,
                  createdAt: (d.data()['created_at'] as Timestamp?)?.toDate(),
                ),
              )
              .where((m) => m.name.isNotEmpty)
              .toList(growable: false);
            list.sort((a, b) {
              final aTime = a.createdAt;
              final bTime = b.createdAt;
              if (aTime != null && bTime != null) return aTime.compareTo(bTime);
              if (aTime != null) return -1;
              if (bTime != null) return 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
            return list;
          },
        );
  }
}

