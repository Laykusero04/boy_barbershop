import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/promos/promos_state.dart';
import 'package:boy_barbershop/data/promos_repository.dart';

class PromosCubit extends Cubit<PromosState> {
  PromosCubit(this._repo) : super(const PromosLoading());

  final PromosRepository _repo;
  StreamSubscription<dynamic>? _sub;

  void watch() {
    _sub = _repo.watchAll().listen(
      (promos) => emit(PromosLoaded(promos: promos)),
      onError: (Object e) =>
          emit(PromosError(message: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
