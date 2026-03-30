import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:developer' as dev;

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class ExpenseWriteException implements Exception {
  ExpenseWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExpensesRepository {
  ExpensesRepository({
    FirebaseFirestore? db,
    CashflowRepository? cashflow,
  })  : _db = db ?? FirebaseFirestore.instance,
        _cashflow = cashflow ?? CashflowRepository(db: db);

  final FirebaseFirestore _db;
  final CashflowRepository _cashflow;

  Stream<List<Expense>> watchExpensesForDay(
    String occurredDay, {
    int limit = 200,
  }) {
    final cleanedDay = occurredDay.trim();
    final safeLimit = limit <= 0 ? 200 : limit;
    if (!isValidYyyyMmDd(cleanedDay)) return const Stream<List<Expense>>.empty();

    return FirestoreCollections.expenses(_db)
        .where('occurred_day', isEqualTo: cleanedDay)
        .orderBy('occurred_at', descending: true)
        .limit(safeLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map(Expense.fromDoc).toList(growable: false);
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

  Future<List<Expense>> fetchExpensesForDays(
    List<String> occurredDays, {
    int chunkSize = 10,
  }) async {
    final cleaned =
        occurredDays.map((d) => d.trim()).where((d) => isValidYyyyMmDd(d)).toSet().toList();
    if (cleaned.isEmpty) return const <Expense>[];

    final safeChunk = (chunkSize <= 0) ? 10 : chunkSize;
    final chunks = <List<String>>[];
    for (var i = 0; i < cleaned.length; i += safeChunk) {
      chunks.add(cleaned.sublist(i, (i + safeChunk) > cleaned.length ? cleaned.length : (i + safeChunk)));
    }

    final out = <Expense>[];
    for (final c in chunks) {
      final snap = await FirestoreCollections.expenses(_db)
          .where('occurred_day', whereIn: c)
          .orderBy('occurred_at', descending: true)
          .get();
      out.addAll(snap.docs.map(Expense.fromDoc));
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

  Stream<List<Expense>> watchExpensesForRangeUtc({
    required DateTime startUtcInclusive,
    required DateTime endUtcExclusive,
    int limit = 5000,
  }) {
    final safeLimit = limit <= 0 ? 5000 : limit;
    dev.log(
      'watchExpensesForRangeUtc',
      name: 'ExpensesRepository',
      error: 'startUtcInclusive=$startUtcInclusive endUtcExclusive=$endUtcExclusive limit=$safeLimit',
    );
    return FirestoreCollections.expenses(_db)
        .where('occurred_at', isGreaterThanOrEqualTo: startUtcInclusive)
        .orderBy('occurred_at', descending: true)
        .limit(safeLimit)
        .snapshots()
        .handleError((error, stack) {
          if (error is FirebaseException) {
            dev.log(
              'Firestore error code=${error.code} message=${error.message}',
              name: 'ExpensesRepository',
              error: error,
              stackTrace: stack as StackTrace?,
            );
          } else {
            dev.log(
              'Stream error: $error',
              name: 'ExpensesRepository',
              error: error,
              stackTrace: stack is StackTrace ? stack : null,
            );
          }
          dev.log(
            'Query params: startUtcInclusive=$startUtcInclusive endUtcExclusive=$endUtcExclusive limit=$safeLimit',
            name: 'ExpensesRepository',
          );
        })
        .map((snap) {
      final list = snap.docs
          .map(Expense.fromDoc)
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

  Stream<List<Expense>> watchExpensesForRangeDays(
    String startDayInclusive,
    String endDayInclusive, {
    int limit = 5000,
  }) {
    final start = startDayInclusive.trim();
    final end = endDayInclusive.trim();
    final safeLimit = limit <= 0 ? 5000 : limit;
    if (!isValidYyyyMmDd(start) || !isValidYyyyMmDd(end)) {
      return const Stream<List<Expense>>.empty();
    }

    return FirestoreCollections.expenses(_db)
        .where('occurred_day', isGreaterThanOrEqualTo: start)
        .orderBy('occurred_day')
        .limit(safeLimit)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map(Expense.fromDoc)
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

  Future<String> createExpense({
    required DateTime occurredAtUtc,
    required String occurredDayManila,
    required String category,
    required double amount,
    required String? paymentMethod,
    required String? vendor,
    required String? receiptNo,
    required String? notes,
    required bool isRefund,
    required String? referenceSaleId,
    required String? createdByUid,
  }) async {
    final cleanedCategory = category.trim();
    final cleanedPayment = (paymentMethod ?? '').trim().isEmpty ? null : paymentMethod!.trim();
    final cleanedVendor = (vendor ?? '').trim().isEmpty ? null : vendor!.trim();
    final cleanedReceipt = (receiptNo ?? '').trim().isEmpty ? null : receiptNo!.trim();
    final cleanedNotes = (notes ?? '').trim().isEmpty ? null : notes!.trim();
    final cleanedSaleRef =
        (referenceSaleId ?? '').trim().isEmpty ? null : referenceSaleId!.trim();

    if (!isValidYyyyMmDd(occurredDayManila)) {
      throw ExpenseWriteException('Invalid date.');
    }
    if (cleanedCategory.isEmpty) {
      throw ExpenseWriteException('Category is required.');
    }
    if (amount.isNaN || amount.isInfinite || amount <= 0) {
      throw ExpenseWriteException('Amount must be greater than 0.');
    }

    final isRefundCategory = cleanedCategory.toLowerCase().trim() == 'refund';
    final requireRefundFields = isRefund || isRefundCategory;
    if (requireRefundFields && (cleanedNotes == null || cleanedNotes.isEmpty)) {
      throw ExpenseWriteException('Notes are required for refunds.');
    }

    try {
      final docRef = await FirestoreCollections.expenses(_db).add({
        'occurred_at': Timestamp.fromDate(occurredAtUtc),
        'occurred_day': occurredDayManila.trim(),
        'category': cleanedCategory,
        'amount': amount,
        'payment_method': cleanedPayment,
        'vendor': cleanedVendor,
        'receipt_no': cleanedReceipt,
        'notes': cleanedNotes,
        'is_refund': requireRefundFields,
        'reference_sale_id': cleanedSaleRef,
        'created_by_uid': (createdByUid ?? '').trim().isEmpty ? null : createdByUid!.trim(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Approach B: each Expense creates a matching cashflow cash-out entry.
      // This keeps Cashflow as a complete ledger.
      await _cashflow.createEntry(
        occurredAtUtc: occurredAtUtc,
        occurredDayManila: occurredDayManila,
        type: CashflowType.cashOut,
        category: 'Expense: $cleanedCategory',
        amount: amount,
        paymentMethod: cleanedPayment,
        referenceSaleId: cleanedSaleRef,
        referenceExpenseId: docRef.id,
        notes: cleanedNotes,
        createdByUid: createdByUid,
      );

      return docRef.id;
    } on FirebaseException catch (e) {
      throw ExpenseWriteException(_firestoreErrorMessage(e));
    } on ExpenseWriteException {
      rethrow;
    } on Object {
      throw ExpenseWriteException('Could not save expense. Please try again.');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final cleaned = expenseId.trim();
    if (cleaned.isEmpty) throw ExpenseWriteException('Invalid expense.');
    try {
      await FirestoreCollections.expenses(_db).doc(cleaned).delete();
      await _cashflow.deleteEntriesForExpense(cleaned);
    } on FirebaseException catch (e) {
      throw ExpenseWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ExpenseWriteException('Could not delete expense. Please try again.');
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

