import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/promo.dart';

sealed class PromosState extends Equatable {
  const PromosState();

  @override
  List<Object?> get props => [];
}

final class PromosLoading extends PromosState {
  const PromosLoading();
}

final class PromosLoaded extends PromosState {
  const PromosLoaded({required this.promos});

  final List<Promo> promos;

  @override
  List<Object?> get props => [promos];
}

final class PromosError extends PromosState {
  const PromosError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
