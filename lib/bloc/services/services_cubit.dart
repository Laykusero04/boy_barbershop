import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/services/services_state.dart';
import 'package:boy_barbershop/data/services_repository.dart';

class ServicesCubit extends Cubit<ServicesState> {
  ServicesCubit(this._repo) : super(const ServicesLoading());

  final ServicesRepository _repo;
  StreamSubscription<dynamic>? _sub;

  void watch() {
    _sub = _repo.watchAllServices().listen(
      (services) => emit(ServicesLoaded(services: services)),
      onError: (Object e) =>
          emit(ServicesError(message: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
