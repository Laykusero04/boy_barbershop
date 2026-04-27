import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/shifts/shifts_state.dart';
import 'package:boy_barbershop/data/barber_shifts_repository.dart';
import 'package:boy_barbershop/models/barber_shift.dart';

class ShiftsCubit extends Cubit<ShiftsState> {
  ShiftsCubit(this._repo) : super(const ShiftsState.initial());

  final BarberShiftsRepository _repo;
  StreamSubscription<List<BarberShift>>? _sub;

  void watch() {
    _sub?.cancel();
    _sub = _repo.watchOpenShifts().listen(
      (shifts) {
        final map = <String, BarberShift>{
          for (final s in shifts) s.barberId: s,
        };
        emit(state.copyWith(
          openShiftByBarberId: map,
          isReady: true,
          clearError: true,
        ));
      },
      onError: (Object e) {
        emit(state.copyWith(errorMessage: e.toString(), isReady: true));
      },
    );
  }

  Future<String?> openShift({
    required String barberId,
    required String openedByUid,
  }) async {
    try {
      final id = await _repo.openShift(
        barberId: barberId,
        openedByUid: openedByUid,
      );
      return id;
    } on ShiftWriteException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return null;
    }
  }

  Future<bool> closeShift({
    required String shiftId,
    required DayClassification classification,
    required String closedByUid,
  }) async {
    try {
      await _repo.closeShift(
        shiftId: shiftId,
        classification: classification,
        closedByUid: closedByUid,
      );
      return true;
    } on ShiftWriteException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return false;
    }
  }

  Future<bool> reopenShift(String shiftId) async {
    try {
      await _repo.reopenShift(shiftId);
      return true;
    } on ShiftWriteException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return false;
    }
  }

  Future<bool> cancelShift(String shiftId) async {
    try {
      await _repo.deleteShift(shiftId);
      return true;
    } on ShiftWriteException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return false;
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      emit(state.copyWith(clearError: true));
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
