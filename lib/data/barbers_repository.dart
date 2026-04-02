import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/data/firestore_collections.dart';
import 'package:boy_barbershop/models/barber.dart';

class BarberWriteException implements Exception {
  BarberWriteException(this.message);
  final String message;
  @override
  String toString() => message;
}

class BarbersRepository {
  BarbersRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Stream<List<Barber>> watchAllBarbers() {
    // Sorted client-side to avoid Firestore composite indexes.
    return FirestoreCollections.barbers(_db)
        .snapshots()
        .map(
          (snap) {
            final list = snap.docs
              .map((d) => Barber.fromFirestoreMap(d.id, d.data()))
              .where((b) => b.name.isNotEmpty)
              .toList(growable: false);

            list.sort((a, b) {
              if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
            return list;
          },
        );
  }

  Future<void> createBarber({
    required String name,
    required BarberCompensationType compensationType,
    required double percentageShare,
    required double dailyRate,
  }) async {
    final cleanedName = name.trim();
    if (cleanedName.isEmpty) {
      throw BarberWriteException('Name is required.');
    }
    if (compensationType == BarberCompensationType.percentage) {
      if (percentageShare.isNaN || percentageShare.isInfinite) {
        throw BarberWriteException('Invalid percentage share.');
      }
      if (percentageShare < 0 || percentageShare > 100) {
        throw BarberWriteException('Percentage share must be 0 to 100.');
      }
    } else {
      if (dailyRate.isNaN || dailyRate.isInfinite || dailyRate < 0) {
        throw BarberWriteException('Daily rate must be a valid non-negative amount.');
      }
    }

    try {
      await FirestoreCollections.barbers(_db).add({
        'name': cleanedName,
        'compensation_type':
            compensationType == BarberCompensationType.dailyRate ? 'daily' : 'percent',
        'percentage_share': compensationType == BarberCompensationType.percentage
            ? percentageShare
            : 0.0,
        'daily_rate': compensationType == BarberCompensationType.dailyRate
            ? dailyRate
            : 0.0,
        'is_active': true,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw BarberWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw BarberWriteException('Could not save barber. Please try again.');
    }
  }

  Future<void> updateBarber({
    required String barberId,
    required String name,
    required BarberCompensationType compensationType,
    required double percentageShare,
    required double dailyRate,
  }) async {
    final cleanedName = name.trim();
    if (barberId.trim().isEmpty) {
      throw BarberWriteException('Invalid barber.');
    }
    if (cleanedName.isEmpty) {
      throw BarberWriteException('Name is required.');
    }
    if (compensationType == BarberCompensationType.percentage) {
      if (percentageShare.isNaN || percentageShare.isInfinite) {
        throw BarberWriteException('Invalid percentage share.');
      }
      if (percentageShare < 0 || percentageShare > 100) {
        throw BarberWriteException('Percentage share must be 0 to 100.');
      }
    } else {
      if (dailyRate.isNaN || dailyRate.isInfinite || dailyRate < 0) {
        throw BarberWriteException('Daily rate must be a valid non-negative amount.');
      }
    }

    try {
      await FirestoreCollections.barbers(_db).doc(barberId).update({
        'name': cleanedName,
        'compensation_type':
            compensationType == BarberCompensationType.dailyRate ? 'daily' : 'percent',
        'percentage_share': compensationType == BarberCompensationType.percentage
            ? percentageShare
            : 0.0,
        'daily_rate': compensationType == BarberCompensationType.dailyRate
            ? dailyRate
            : 0.0,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw BarberWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw BarberWriteException('Could not update barber. Please try again.');
    }
  }

  Future<void> deactivateBarber(String barberId) async {
    if (barberId.trim().isEmpty) {
      throw BarberWriteException('Invalid barber.');
    }
    try {
      await FirestoreCollections.barbers(_db).doc(barberId).update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw BarberWriteException(_firestoreErrorMessage(e));
    } on Object {
      throw BarberWriteException('Could not deactivate barber. Please try again.');
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
