import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/payment_method_item.dart';

sealed class PaymentMethodsState extends Equatable {
  const PaymentMethodsState();

  @override
  List<Object?> get props => [];
}

final class PaymentMethodsLoading extends PaymentMethodsState {
  const PaymentMethodsLoading();
}

final class PaymentMethodsLoaded extends PaymentMethodsState {
  const PaymentMethodsLoaded({required this.methods});

  final List<PaymentMethodItem> methods;

  @override
  List<Object?> get props => [methods];
}

final class PaymentMethodsError extends PaymentMethodsState {
  const PaymentMethodsError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
