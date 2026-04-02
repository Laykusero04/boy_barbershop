import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/inventory/inventory_state.dart';
import 'package:boy_barbershop/data/inventory_repository.dart';

class InventoryCubit extends Cubit<InventoryState> {
  InventoryCubit(this._repo) : super(const InventoryLoading());

  final InventoryRepository _repo;
  StreamSubscription<dynamic>? _sub;

  void watch() {
    _sub = _repo.watchAllInventoryItems().listen(
      (items) => emit(InventoryLoaded(items: items)),
      onError: (Object e) =>
          emit(InventoryError(message: e.toString())),
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
