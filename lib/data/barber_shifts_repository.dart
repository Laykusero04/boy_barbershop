import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/barber_shift.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class ShiftWriteException implements Exception {
  ShiftWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BarberShiftsRepository {
  BarberShiftsRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<BarberShift>> watchOpenShifts() {
    return FirestoreCollections.barberShifts(_db)
        .where('closed_at', isNull: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(BarberShift.fromDoc)
              .where((s) => s.barberId.isNotEmpty)
              .toList(growable: false),
        );
  }

  Stream<List<BarberShift>> watchShiftsForDay(String occurredDay) {
    final day = occurredDay.trim();
    return FirestoreCollections.barberShifts(_db)
        .where('occurred_day', isEqualTo: day)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(BarberShift.fromDoc)
              .where((s) => s.barberId.isNotEmpty)
              .toList(growable: false),
        );
  }

  Stream<List<BarberShift>> watchShiftsForRangeDays(
    String startDay,
    String endDay,
  ) {
    return FirestoreCollections.barberShifts(_db)
        .where('occurred_day', isGreaterThanOrEqualTo: startDay.trim())
        .where('occurred_day', isLessThanOrEqualTo: endDay.trim())
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(BarberShift.fromDoc)
              .where((s) => s.barberId.isNotEmpty)
              .toList(growable: false),
        );
  }

  Future<List<BarberShift>> fetchShiftsForRangeDays(
    String startDay,
    String endDay,
  ) async {
    try {
      final snap = await FirestoreCollections.barberShifts(_db)
          .where('occurred_day', isGreaterThanOrEqualTo: startDay.trim())
          .where('occurred_day', isLessThanOrEqualTo: endDay.trim())
          .get();
      return snap.docs
          .map(BarberShift.fromDoc)
          .where((s) => s.barberId.isNotEmpty)
          .toList(growable: false);
    } on FirebaseException catch (e) {
      throw ShiftWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ShiftWriteException('Could not load shifts. Please try again.');
    }
  }

  Future<BarberShift?> findOpenShiftForBarber(String barberId) async {
    final cleanedId = barberId.trim();
    if (cleanedId.isEmpty) return null;
    try {
      final snap = await FirestoreCollections.barberShifts(_db)
          .where('barber_id', isEqualTo: cleanedId)
          .where('closed_at', isNull: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return BarberShift.fromDoc(snap.docs.first);
    } on FirebaseException catch (e) {
      throw ShiftWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ShiftWriteException('Could not check shift. Please try again.');
    }
  }

  Future<String> openShift({
    required String barberId,
    required String openedByUid,
    String? notes,
  }) async {
    final cleanedId = barberId.trim();
    if (cleanedId.isEmpty) {
      throw ShiftWriteException('Invalid barber.');
    }
    final existing = await findOpenShiftForBarber(cleanedId);
    if (existing != null) {
      throw ShiftWriteException('A shift is already open for this barber.');
    }
    final today = todayManilaDay();
    final cleanedNotes = (notes ?? '').trim();
    try {
      final ref = await FirestoreCollections.barberShifts(_db).add({
        'barber_id': cleanedId,
        'occurred_day': today,
        'opened_at': FieldValue.serverTimestamp(),
        'opened_by_uid': openedByUid.trim(),
        'closed_at': null,
        'closed_by_uid': null,
        'day_classification': null,
        if (cleanedNotes.isNotEmpty) 'notes': cleanedNotes,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      return ref.id;
    } on FirebaseException catch (e) {
      throw ShiftWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ShiftWriteException('Could not open shift. Please try again.');
    }
  }

  Future<void> closeShift({
    required String shiftId,
    required DayClassification classification,
    required String closedByUid,
    String? notes,
  }) async {
    final cleanedId = shiftId.trim();
    if (cleanedId.isEmpty) {
      throw ShiftWriteException('Invalid shift.');
    }
    final cleanedNotes = (notes ?? '').trim();
    try {
      await FirestoreCollections.barberShifts(_db).doc(cleanedId).update({
        'closed_at': FieldValue.serverTimestamp(),
        'closed_by_uid': closedByUid.trim(),
        'day_classification': classification.wire,
        if (cleanedNotes.isNotEmpty) 'notes': cleanedNotes,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ShiftWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ShiftWriteException('Could not close shift. Please try again.');
    }
  }

  Future<void> deleteShift(String shiftId) async {
    final cleanedId = shiftId.trim();
    if (cleanedId.isEmpty) {
      throw ShiftWriteException('Invalid shift.');
    }
    try {
      await FirestoreCollections.barberShifts(_db).doc(cleanedId).delete();
    } on FirebaseException catch (e) {
      throw ShiftWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ShiftWriteException('Could not cancel shift. Please try again.');
    }
  }

  Future<void> reopenShift(String shiftId) async {
    final cleanedId = shiftId.trim();
    if (cleanedId.isEmpty) {
      throw ShiftWriteException('Invalid shift.');
    }
    try {
      await FirestoreCollections.barberShifts(_db).doc(cleanedId).update({
        'closed_at': null,
        'closed_by_uid': null,
        'day_classification': null,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw ShiftWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw ShiftWriteException('Could not reopen shift. Please try again.');
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
