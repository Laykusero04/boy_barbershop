import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:developer' as dev;

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class CashflowWriteException implements Exception {
  CashflowWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CashflowRepository {
  CashflowRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<CashflowEntry>> watchEntriesForDay(
    String occurredDay, {
    int limit = 200,
  }) {
    final cleanedDay = occurredDay.trim();
    final safeLimit = limit <= 0 ? 200 : limit;
    if (!isValidYyyyMmDd(cleanedDay)) return const Stream<List<CashflowEntry>>.empty();

    return FirestoreCollections.cashflowEntries(_db)
        .where('occurred_day', isEqualTo: cleanedDay)
        .orderBy('occurred_at', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(CashflowEntry.fromDoc).toList(growable: false);
      final sorted = [...list];
      // `occurred_at` can be null briefly after serverTimestamp writes.
      sorted.sort((a, b) {
        final aDt = a.occurredAt;
        final bDt = b.occurredAt;
        if (aDt != null && bDt != null) return bDt.compareTo(aDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        return b.id.compareTo(a.id);
      });
      return sorted;
    });
  }

  Future<List<CashflowEntry>> fetchEntriesForDays(
    List<String> occurredDays, {
    int chunkSize = 10,
  }) async {
    final cleaned =
        occurredDays.map((d) => d.trim()).where((d) => isValidYyyyMmDd(d)).toSet().toList();
    if (cleaned.isEmpty) return const <CashflowEntry>[];

    final safeChunk = (chunkSize <= 0) ? 10 : chunkSize;
    final chunks = <List<String>>[];
    for (var i = 0; i < cleaned.length; i += safeChunk) {
      chunks.add(cleaned.sublist(i, (i + safeChunk) > cleaned.length ? cleaned.length : (i + safeChunk)));
    }

    final out = <CashflowEntry>[];
    for (final c in chunks) {
      final snap = await FirestoreCollections.cashflowEntries(_db)
          .where('occurred_day', whereIn: c)
          .orderBy('occurred_at', descending: true)
          .get();
      out.addAll(snap.docs.map(CashflowEntry.fromDoc));
    }

    out.sort((a, b) {
      final aDt = a.occurredAt;
      final bDt = b.occurredAt;
      if (aDt != null && bDt != null) return bDt.compareTo(aDt);
      if (aDt != null) return -1;
      if (bDt != null) return 1;
      if (a.occurredDay != b.occurredDay) return b.occurredDay.compareTo(a.occurredDay);
      return b.id.compareTo(a.id);
    });
    return out;
  }

  Stream<List<CashflowEntry>> watchEntriesForRangeUtc({
    required DateTime startUtcInclusive,
    required DateTime endUtcExclusive,
    int limit = 8000,
  }) {
    final safeLimit = limit <= 0 ? 8000 : limit;
    dev.log(
      'watchEntriesForRangeUtc',
      name: 'CashflowRepository',
      error: 'startUtcInclusive=$startUtcInclusive endUtcExclusive=$endUtcExclusive limit=$safeLimit',
    );
    return FirestoreCollections.cashflowEntries(_db)
        .where('occurred_at', isGreaterThanOrEqualTo: startUtcInclusive)
        .orderBy('occurred_at', descending: true)
        .limit(safeLimit)
        .snapshots()
        .handleError((error, stack) {
          if (error is FirebaseException) {
            dev.log(
              'Firestore error code=${error.code} message=${error.message}',
              name: 'CashflowRepository',
              error: error,
              stackTrace: stack as StackTrace?,
            );
          } else {
            dev.log(
              'Stream error: $error',
              name: 'CashflowRepository',
              error: error,
              stackTrace: stack is StackTrace ? stack : null,
            );
          }
          dev.log(
            'Query params: startUtcInclusive=$startUtcInclusive endUtcExclusive=$endUtcExclusive limit=$safeLimit',
            name: 'CashflowRepository',
          );
        })
        .map((snap) {
      final list = snap.docs
          .map(CashflowEntry.fromDoc)
          .where((e) {
            final dt = e.occurredAt;
            if (dt == null) return false;
            return dt.toUtc().isBefore(endUtcExclusive);
          })
          .toList(growable: false);
      final sorted = [...list];
      sorted.sort((a, b) {
        final aDt = a.occurredAt;
        final bDt = b.occurredAt;
        if (aDt != null && bDt != null) return bDt.compareTo(aDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        return b.id.compareTo(a.id);
      });
      return sorted;
    });
  }

  Stream<List<CashflowEntry>> watchEntriesForRangeDays(
    String startDayInclusive,
    String endDayInclusive, {
    int limit = 5000,
  }) {
    final start = startDayInclusive.trim();
    final end = endDayInclusive.trim();
    final safeLimit = limit <= 0 ? 5000 : limit;
    if (!isValidYyyyMmDd(start) || !isValidYyyyMmDd(end)) {
      return const Stream<List<CashflowEntry>>.empty();
    }

    return FirestoreCollections.cashflowEntries(_db)
        .where('occurred_day', isGreaterThanOrEqualTo: start)
        .orderBy('occurred_day')
        .limit(safeLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(CashflowEntry.fromDoc)
          .where((e) => e.occurredDay.compareTo(end) <= 0)
          .toList(growable: false);
      final sorted = [...list];
      sorted.sort((a, b) {
        final aDt = a.occurredAt;
        final bDt = b.occurredAt;
        if (aDt != null && bDt != null) return bDt.compareTo(aDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        if (a.occurredDay != b.occurredDay) return b.occurredDay.compareTo(a.occurredDay);
        return b.id.compareTo(a.id);
      });
      return sorted;
    });
  }

  Future<String> createEntry({
    required DateTime occurredAtUtc,
    required String occurredDayManila,
    required CashflowType type,
    required String category,
    required double amount,
    required String? paymentMethod,
    required String? referenceSaleId,
    required String? referenceExpenseId,
    required String? notes,
    required String? createdByUid,
  }) async {
    final cleanedCategory = category.trim();
    final cleanedPayment = (paymentMethod ?? '').trim().isEmpty ? null : paymentMethod!.trim();
    final cleanedSaleRef =
        (referenceSaleId ?? '').trim().isEmpty ? null : referenceSaleId!.trim();
    final cleanedExpenseRef = (referenceExpenseId ?? '').trim().isEmpty
        ? null
        : referenceExpenseId!.trim();
    final cleanedNotes = (notes ?? '').trim().isEmpty ? null : notes!.trim();

    if (!isValidYyyyMmDd(occurredDayManila)) {
      throw CashflowWriteException('Invalid date.');
    }
    if (cleanedCategory.isEmpty) {
      throw CashflowWriteException('Category is required.');
    }
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw CashflowWriteException('Amount must be greater than 0.');
    }

    final requiresNotes = _requiresNotes(cleanedCategory);
    if (requiresNotes && (cleanedNotes == null || cleanedNotes.isEmpty)) {
      throw CashflowWriteException('Notes are required for "$cleanedCategory".');
    }

    try {
      final docRef = await FirestoreCollections.cashflowEntries(_db).add({
        'occurred_at': Timestamp.fromDate(occurredAtUtc),
        'occurred_day': occurredDayManila.trim(),
        'flow_type': type.wire,
        'category': cleanedCategory,
        'amount': amount,
        'payment_method': cleanedPayment,
        'reference_sale_id': cleanedSaleRef,
        'reference_expense_id': cleanedExpenseRef,
        'notes': cleanedNotes,
        'created_by_uid': (createdByUid ?? '').trim().isEmpty ? null : createdByUid!.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } on FirebaseException catch (e) {
      throw CashflowWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw CashflowWriteException('Could not save cashflow entry. Please try again.');
    }
  }

  Future<void> createCashInForSale({
    required String saleId,
    required String saleDayManila,
    required double amount,
    required String? paymentMethod,
    required String? createdByUid,
    String category = 'Cash sale',
  }) async {
    final cleanedSaleId = saleId.trim();
    if (cleanedSaleId.isEmpty) return;
    if (!isValidYyyyMmDd(saleDayManila)) return;
    if (amount.isNaN || amount.isInfinite || amount <= 0) return;

    try {
      await FirestoreCollections.cashflowEntries(_db).add({
        'occurred_at': FieldValue.serverTimestamp(),
        'occurred_day': saleDayManila.trim(),
        'flow_type': CashflowType.cashIn.wire,
        'category': category.trim(),
        'amount': amount,
        'payment_method': (paymentMethod ?? '').trim().isEmpty ? null : paymentMethod!.trim(),
        'reference_sale_id': cleanedSaleId,
        'reference_expense_id': null,
        'notes': null,
        'created_by_uid': (createdByUid ?? '').trim().isEmpty ? null : createdByUid!.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on Object {
      // Best-effort; sales should still save even if cashflow write fails.
    }
  }

  Future<void> deleteEntriesForSale(String saleId) async {
    final cleaned = saleId.trim();
    if (cleaned.isEmpty) return;
    try {
      final snap = await FirestoreCollections.cashflowEntries(_db)
          .where('reference_sale_id', isEqualTo: cleaned)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } on Object {
      // Best-effort cleanup.
    }
  }

  Future<void> deleteEntriesForExpense(String expenseId) async {
    final cleaned = expenseId.trim();
    if (cleaned.isEmpty) return;
    try {
      final snap = await FirestoreCollections.cashflowEntries(_db)
          .where('reference_expense_id', isEqualTo: cleaned)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } on Object {
      // Best-effort cleanup.
    }
  }

  Future<void> deleteEntry(String entryId) async {
    final cleaned = entryId.trim();
    if (cleaned.isEmpty) throw CashflowWriteException('Invalid entry.');
    try {
      await FirestoreCollections.cashflowEntries(_db).doc(cleaned).delete();
    } on FirebaseException catch (e) {
      throw CashflowWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw CashflowWriteException('Could not delete entry. Please try again.');
    }
  }
}

bool _requiresNotes(String category) {
  final c = category.trim().toLowerCase();
  if (c == 'refund') return true;
  if (c.contains('over/short')) return true;
  if (c.contains('over / short')) return true;
  if (c.contains('over-short')) return true;
  if (c.contains('adjustment')) return true;
  return false;
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

