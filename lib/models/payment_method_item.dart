import 'package:equatable/equatable.dart';

class PaymentMethodItem extends Equatable {
  const PaymentMethodItem({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final bool isActive;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [id, name, isActive, createdAt];
}

