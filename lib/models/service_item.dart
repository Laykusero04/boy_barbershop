import 'package:equatable/equatable.dart';

class ServiceItem extends Equatable {
  const ServiceItem({
    required this.id,
    required this.name,
    required this.defaultPrice,
    required this.isActive,
  });

  final String id;
  final String name;
  final double defaultPrice;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, defaultPrice, isActive];
}

