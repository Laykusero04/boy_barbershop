import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/service_item.dart';

sealed class ServicesState extends Equatable {
  const ServicesState();

  @override
  List<Object?> get props => [];
}

final class ServicesLoading extends ServicesState {
  const ServicesLoading();
}

final class ServicesLoaded extends ServicesState {
  const ServicesLoaded({required this.services});

  final List<ServiceItem> services;

  @override
  List<Object?> get props => [services];
}

final class ServicesError extends ServicesState {
  const ServicesError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
