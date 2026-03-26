import 'package:equatable/equatable.dart';

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.itemName,
    required this.unit,
    required this.isActive,
  });

  final String id;
  final String itemName;
  final String? unit;
  final bool isActive;

  @override
  List<Object?> get props => [id, itemName, unit, isActive];
}

