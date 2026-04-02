import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/barber.dart';

sealed class BarbersState extends Equatable {
  const BarbersState();

  @override
  List<Object?> get props => [];
}

final class BarbersLoading extends BarbersState {
  const BarbersLoading();
}

final class BarbersLoaded extends BarbersState {
  const BarbersLoaded({required this.barbers});

  final List<Barber> barbers;

  @override
  List<Object?> get props => [barbers];
}

final class BarbersError extends BarbersState {
  const BarbersError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
