import 'package:equatable/equatable.dart';

enum BarberCompensationType {
  percentage,
  dailyRate,
  guaranteedBase,
}

class Barber extends Equatable {
  const Barber({
    required this.id,
    required this.name,
    required this.compensationType,
    required this.percentageShare,
    required this.dailyRate,
    required this.isActive,
    this.removed = false,
    this.removedReason,
  });

  final String id;
  final String name;
  final BarberCompensationType compensationType;
  /// Used when [compensationType] is [BarberCompensationType.percentage] (0–100).
  final double percentageShare;
  /// Used when [compensationType] is [BarberCompensationType.dailyRate].
  final double dailyRate;
  final bool isActive;
  final bool removed;
  final String? removedReason;

  /// Reads Firestore fields; missing `compensation_type` defaults to percentage (legacy docs).
  factory Barber.fromFirestoreMap(String id, Map<String, dynamic> data) {
    final name = ((data['name'] as String?) ?? '').trim();
    final compensationType = _parseCompensationType(data['compensation_type']);
    final percentageShare =
        (data['percentage_share'] as num?)?.toDouble() ?? 0;
    final dailyRate = (data['daily_rate'] as num?)?.toDouble() ?? 0;
    return Barber(
      id: id,
      name: name,
      compensationType: compensationType,
      percentageShare: percentageShare,
      dailyRate: dailyRate,
      isActive: (data['is_active'] as bool?) ?? false,
      removed: (data['removed'] as bool?) ?? false,
      removedReason: data['removed_reason'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, compensationType, percentageShare, dailyRate, isActive, removed, removedReason];
}

BarberCompensationType _parseCompensationType(dynamic raw) {
  final value = (raw is String) ? raw.trim().toLowerCase() : '';
  if (value == 'daily') return BarberCompensationType.dailyRate;
  if (value == 'guaranteed_base') return BarberCompensationType.guaranteedBase;
  return BarberCompensationType.percentage;
}