import 'package:equatable/equatable.dart';

class InventoryItem extends Equatable {
  const InventoryItem({
    required this.id,
    required this.itemName,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.unit,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String itemName;
  final double stockQty;
  final int lowStockThreshold;
  final String? unit;
  final bool isActive;
  final DateTime? createdAt;

  bool get isLowStock => isActive && stockQty <= lowStockThreshold;

  @override
  List<Object?> get props => [
        id,
        itemName,
        stockQty,
        lowStockThreshold,
        unit,
        isActive,
        createdAt,
      ];
}

