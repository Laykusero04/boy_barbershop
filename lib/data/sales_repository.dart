import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/sale_create.dart';

class SaleCreateException implements Exception {
  SaleCreateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SalesRepository {
  SalesRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String> createSale(SaleCreate input) async {
    if (input.price.isNaN || input.price.isInfinite || input.price < 0) {
      throw SaleCreateException('Price must be 0 or greater.');
    }
    if (input.barberId.trim().isEmpty) {
      throw SaleCreateException('Please select a barber.');
    }
    if (input.serviceId.trim().isEmpty) {
      throw SaleCreateException('Please select a service.');
    }
    if (!_isValidDay(input.saleDayManila)) {
      throw SaleCreateException('Invalid sale date.');
    }

    try {
      final data = <String, Object?>{
        'barber_id': input.barberId,
        'service_id': input.serviceId,
        'price': input.price,
        'payment_method': input.paymentMethodName?.trim().isEmpty ?? true
            ? null
            : input.paymentMethodName?.trim(),
        'notes': input.notes?.trim().isEmpty ?? true ? null : input.notes?.trim(),
        'sale_day': input.saleDayManila,
        'sale_datetime': FieldValue.serverTimestamp(),
        'created_by_uid': input.createdByUid,
        'created_at': FieldValue.serverTimestamp(),
      };

      final promoId = input.promoId?.trim();
      if (promoId != null && promoId.isNotEmpty) {
        data['promo_id'] = promoId;
        if (input.originalPrice != null) data['original_price'] = input.originalPrice;
        if (input.discountAmount != null) {
          data['discount_amount'] = input.discountAmount;
        }
      }

      final docRef = await FirestoreCollections.sales(_db).add(data);
      return docRef.id;
    } on FirebaseException catch (e) {
      throw SaleCreateException(_firestoreErrorMessage(e));
    } on Object {
      throw SaleCreateException('Could not save sale. Please try again.');
    }
  }
}

bool _isValidDay(String value) {
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);
}

String _firestoreErrorMessage(FirebaseException e) {
  switch (e.code) {
    case 'permission-denied':
      return 'Permission denied saving sale. Check Firestore Rules.';
    case 'unavailable':
      return 'Service unavailable. Check your internet connection.';
    default:
      return 'Could not save sale (${e.code}).';
  }
}

