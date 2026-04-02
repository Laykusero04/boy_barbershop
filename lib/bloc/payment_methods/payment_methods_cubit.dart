import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/payment_methods/payment_methods_state.dart';
import 'package:boy_barbershop/data/payment_methods_repository.dart';

class PaymentMethodsCubit extends Cubit<PaymentMethodsState> {
  PaymentMethodsCubit(this._repo) : super(const PaymentMethodsLoading());

  final PaymentMethodsRepository _repo;
  StreamSubscription<dynamic>? _sub;

  void watch() {
    _sub = _repo.watchAll().listen(
      (methods) => emit(PaymentMethodsLoaded(methods: methods)),
      onError: (Object e) =>
          emit(PaymentMethodsError(message: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
