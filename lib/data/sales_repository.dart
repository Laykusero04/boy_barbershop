import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:developer' as dev;

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/models/sale_create.dart';

class SaleCreateException implements Exception {
  SaleCreateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SalesRepository {
  SalesRepository({FirebaseFirestore? db, CashflowRepository? cashflow})
      : _db = db ?? FirebaseFirestore.instance,
        _cashflow = cashflow;

  final FirebaseFirestore _db;
  final CashflowRepository? _cashflow;

  Stream<List<Sale>> watchSalesForDay(
    String saleDay, {
    int limit = 20,
  }) {
    final cleanedDay = saleDay.trim();
    final safeLimit = limit <= 0 ? 20 : limit;
    if (!_isValidDay(cleanedDay)) return const Stream<List<Sale>>.empty();

    return FirestoreCollections.sales(_db)
        .where('sale_day', isEqualTo: cleanedDay)
        .orderBy('sale_datetime', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Sale.fromDoc).toList(growable: false);
      // `sale_datetime` can be null briefly after serverTimestamp writes.
      final sorted = [...list];
      sorted.sort((a, b) {
        final aDt = a.saleDateTime;
        final bDt = b.saleDateTime;
        if (aDt != null && bDt != null) return bDt.compareTo(aDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        return b.id.compareTo(a.id);
      });
      return sorted;
    });
  }

  /// Safe daily watcher that does NOT query/order by `sale_datetime`.
  /// Use this when legacy data may contain non-Timestamp `sale_datetime` values.
  Stream<List<Sale>> watchSalesForDaySafe(
    String saleDay, {
    int limit = 5000,
  }) {
    final cleanedDay = saleDay.trim();
    final safeLimit = limit <= 0 ? 5000 : limit;
    if (!_isValidDay(cleanedDay)) return const Stream<List<Sale>>.empty();

    return FirestoreCollections.sales(_db)
        .where('sale_day', isEqualTo: cleanedDay)
        .limit(safeLimit)
        .snapshots()
        .map((snap) => snap.docs.map(Sale.fromDoc).toList(growable: false));
  }

  Future<List<Sale>> fetchSalesForDays(
    List<String> saleDays, {
    int chunkSize = 10,
  }) async {
    final cleaned = saleDays.map((d) => d.trim()).where((d) => _isValidDay(d)).toSet().toList();
    if (cleaned.isEmpty) return const <Sale>[];

    final safeChunk = (chunkSize <= 0) ? 10 : chunkSize;
    final chunks = <List<String>>[];
    for (var i = 0; i < cleaned.length; i += safeChunk) {
      chunks.add(cleaned.sublist(i, (i + safeChunk) > cleaned.length ? cleaned.length : (i + safeChunk)));
    }

    final out = <Sale>[];
    for (final c in chunks) {
      final snap = await FirestoreCollections.sales(_db)
          .where('sale_day', whereIn: c)
          .orderBy('sale_datetime', descending: true)
          .get();
      out.addAll(snap.docs.map(Sale.fromDoc));
    }

    out.sort((a, b) {
      final aDt = a.saleDateTime;
      final bDt = b.saleDateTime;
      if (aDt != null && bDt != null) return bDt.compareTo(aDt);
      if (aDt != null) return -1;
      if (bDt != null) return 1;
      if (a.saleDay != b.saleDay) return b.saleDay.compareTo(a.saleDay);
      return b.id.compareTo(a.id);
    });
    return out;
  }

  /// Safe ranged fetch that does NOT query/order by `sale_datetime`.
  /// It uses `sale_day whereIn [...]` only, so mixed `sale_datetime` types won't break.
  Future<List<Sale>> fetchSalesForDaysSafe(
    List<String> saleDays, {
    int chunkSize = 10,
  }) async {
    final cleaned = saleDays.map((d) => d.trim()).where((d) => _isValidDay(d)).toSet().toList();
    if (cleaned.isEmpty) return const <Sale>[];

    final safeChunk = (chunkSize <= 0) ? 10 : chunkSize;
    final chunks = <List<String>>[];
    for (var i = 0; i < cleaned.length; i += safeChunk) {
      chunks.add(
        cleaned.sublist(
          i,
          (i + safeChunk) > cleaned.length ? cleaned.length : (i + safeChunk),
        ),
      );
    }

    final out = <Sale>[];
    for (final c in chunks) {
      final snap =
          await FirestoreCollections.sales(_db).where('sale_day', whereIn: c).get();
      out.addAll(snap.docs.map(Sale.fromDoc));
    }

    // Best-effort sorting: use sale_datetime when present, otherwise sale_day.
    out.sort((a, b) {
      final aDt = a.saleDateTime;
      final bDt = b.saleDateTime;
      if (aDt != null && bDt != null) return bDt.compareTo(aDt);
      if (aDt != null) return -1;
      if (bDt != null) return 1;
      if (a.saleDay != b.saleDay) return b.saleDay.compareTo(a.saleDay);
      return b.id.compareTo(a.id);
    });
    return out;
  }

  /// Firestore structured queries reject [limit] above 10,000 (`invalid-argument`).
  static const int _maxFirestoreQueryLimit = 10000;

  Stream<List<Sale>> watchSalesForRangeUtc({
    required DateTime startUtcInclusive,
    required DateTime endUtcExclusive,
    int limit = 5000,
  }) {
    final safeLimit = limit <= 0 ? 5000 : limit;
    final cappedLimit = safeLimit > _maxFirestoreQueryLimit
        ? _maxFirestoreQueryLimit
        : safeLimit;
    dev.log(
      'watchSalesForRangeUtc',
      name: 'SalesRepository',
      error: 'startUtcInclusive=$startUtcInclusive endUtcExclusive=$endUtcExclusive '
          'limit=$cappedLimit${safeLimit > _maxFirestoreQueryLimit ? ' (capped from $safeLimit)' : ''}',
    );

    return FirestoreCollections.sales(_db)
        .where('sale_datetime', isGreaterThanOrEqualTo: startUtcInclusive)
        .where('sale_datetime', isLessThan: endUtcExclusive)
        .orderBy('sale_datetime', descending: true)
        .limit(cappedLimit)
        .snapshots()
        .handleError((error, stack) {
          if (error is FirebaseException) {
            dev.log(
              'Firestore error code=${error.code} message=${error.message}',
              name: 'SalesRepository',
              error: error,
              stackTrace: stack as StackTrace?,
            );
          } else {
            dev.log(
              'Stream error: $error',
              name: 'SalesRepository',
              error: error,
              stackTrace: stack is StackTrace ? stack : null,
            );
          }
          dev.log(
            'Query params: startUtcInclusive=$startUtcInclusive endUtcExclusive=$endUtcExclusive limit=$cappedLimit',
            name: 'SalesRepository',
          );
        })
        .map((snap) {
      final list = snap.docs
          .map(Sale.fromDoc)
          .toList(growable: false);
      final sorted = [...list];
      sorted.sort((a, b) {
        final aDt = a.saleDateTime;
        final bDt = b.saleDateTime;
        if (aDt != null && bDt != null) return bDt.compareTo(aDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        return b.id.compareTo(a.id);
      });
      return sorted;
    });
  }

  Stream<List<Sale>> watchSalesForRangeDays(
    String startDayInclusive,
    String endDayInclusive, {
    int limit = 5000,
  }) {
    final start = startDayInclusive.trim();
    final end = endDayInclusive.trim();
    final safeLimit = limit <= 0 ? 5000 : limit;
    if (!_isValidDay(start) || !_isValidDay(end)) {
      return const Stream<List<Sale>>.empty();
    }

    return FirestoreCollections.sales(_db)
        .where('sale_day', isGreaterThanOrEqualTo: start)
        .where('sale_day', isLessThanOrEqualTo: end)
        .orderBy('sale_day')
        .limit(safeLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(Sale.fromDoc)
          .toList(growable: false);
      final sorted = [...list];
      sorted.sort((a, b) {
        final aDt = a.saleDateTime;
        final bDt = b.saleDateTime;
        if (aDt != null && bDt != null) return bDt.compareTo(aDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        if (a.saleDay != b.saleDay) return b.saleDay.compareTo(a.saleDay);
        return b.id.compareTo(a.id);
      });
      return sorted;
    });
  }

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
        data['owner_covers_discount'] = input.ownerCoversDiscount;
      }

      final docRef = await FirestoreCollections.sales(_db).add(data);

      final pm = (input.paymentMethodName ?? '').trim();
      if (_cashflow != null && _isCashPayment(pm)) {
        await _cashflow.createCashInForSale(
          saleId: docRef.id,
          saleDayManila: input.saleDayManila,
          amount: input.price,
          paymentMethod: pm.isEmpty ? null : pm,
          createdByUid: input.createdByUid,
        );
      }
      return docRef.id;
    } on FirebaseException catch (e) {
      throw SaleCreateException(_firestoreErrorMessage(e));
    } on Object {
      throw SaleCreateException('Could not save sale. Please try again.');
    }
  }

  Future<void> deleteSale(String saleId) async {
    final cleanedId = saleId.trim();
    if (cleanedId.isEmpty) {
      throw SaleCreateException('Invalid sale.');
    }
    try {
      await FirestoreCollections.sales(_db).doc(cleanedId).delete();
      if (_cashflow != null) {
        await _cashflow.deleteEntriesForSale(cleanedId);
      }
    } on FirebaseException catch (e) {
      throw SaleCreateException(_firestoreErrorMessage(e));
    } on Object {
      throw SaleCreateException('Could not delete sale. Please try again.');
    }
  }

  Future<void> updateSaleFields({
    required String saleId,
    required double price,
    required String? paymentMethodName,
    required String? notes,
    String? barberId,
  }) async {
    final cleanedId = saleId.trim();
    if (cleanedId.isEmpty) throw SaleCreateException('Invalid sale.');
    if (price.isNaN || price.isInfinite || price < 0) {
      throw SaleCreateException('Price must be 0 or greater.');
    }

    final cleanedPayment =
        (paymentMethodName ?? '').trim().isEmpty ? null : paymentMethodName!.trim();
    final cleanedNotes = (notes ?? '').trim().isEmpty ? null : notes!.trim();

    final updates = <String, Object?>{
      'price': price,
      'payment_method': cleanedPayment,
      'notes': cleanedNotes,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (barberId != null && barberId.trim().isNotEmpty) {
      updates['barber_id'] = barberId.trim();
    }

    try {
      await FirestoreCollections.sales(_db).doc(cleanedId).update(updates);
    } on FirebaseException catch (e) {
      throw SaleCreateException(_firestoreErrorMessage(e));
    } on Object {
      throw SaleCreateException('Could not update sale. Please try again.');
    }
  }
}

bool _isCashPayment(String paymentMethodName) {
  final pm = paymentMethodName.trim().toLowerCase();
  if (pm.isEmpty) return false;
  if (pm == 'cash') return true;
  // Tolerate variants like "Cash (drawer)"
  if (pm.startsWith('cash')) return true;
  return false;
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

