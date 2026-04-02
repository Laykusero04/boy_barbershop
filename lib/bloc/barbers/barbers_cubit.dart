import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/barbers/barbers_state.dart';
import 'package:boy_barbershop/data/barbers_repository.dart';

class BarbersCubit extends Cubit<BarbersState> {
  BarbersCubit(this._repo) : super(const BarbersLoading());

  final BarbersRepository _repo;
  StreamSubscription<dynamic>? _sub;

  void watch() {
    _sub = _repo.watchAllBarbers().listen(
      (barbers) => emit(BarbersLoaded(barbers: barbers)),
      onError: (Object e) =>
          emit(BarbersError(message: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
