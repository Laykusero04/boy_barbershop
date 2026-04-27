import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/barber_shift.dart';

class ShiftsState extends Equatable {
  const ShiftsState({
    required this.openShiftByBarberId,
    required this.errorMessage,
    required this.isReady,
  });

  const ShiftsState.initial()
      : openShiftByBarberId = const <String, BarberShift>{},
        errorMessage = null,
        isReady = false;

  final Map<String, BarberShift> openShiftByBarberId;
  final String? errorMessage;
  final bool isReady;

  ShiftsState copyWith({
    Map<String, BarberShift>? openShiftByBarberId,
    String? errorMessage,
    bool? isReady,
    bool clearError = false,
  }) {
    return ShiftsState(
      openShiftByBarberId: openShiftByBarberId ?? this.openShiftByBarberId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isReady: isReady ?? this.isReady,
    );
  }

  BarberShift? openShiftFor(String barberId) =>
      openShiftByBarberId[barberId.trim()];

  bool isOnDuty(String barberId) =>
      openShiftByBarberId.containsKey(barberId.trim());

  @override
  List<Object?> get props => [openShiftByBarberId, errorMessage, isReady];
}
