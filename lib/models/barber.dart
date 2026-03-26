import 'package:equatable/equatable.dart';

class Barber extends Equatable {
  const Barber({
    required this.id,
    required this.name,
    required this.percentageShare,
    required this.isActive,
  });

  final String id;
  final String name;
  final double percentageShare;
  final bool isActive;

  @override
  List<Object?> get props => [id, name, percentageShare, isActive];
}

