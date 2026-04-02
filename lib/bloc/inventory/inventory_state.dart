import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/inventory_item.dart';

sealed class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

final class InventoryLoading extends InventoryState {
  const InventoryLoading();
}

final class InventoryLoaded extends InventoryState {
  const InventoryLoaded({required this.items});

  final List<InventoryItem> items;

  @override
  List<Object?> get props => [items];
}

final class InventoryError extends InventoryState {
  const InventoryError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}
