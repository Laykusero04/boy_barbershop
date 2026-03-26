import 'package:equatable/equatable.dart';

enum PromoType { percentOff, amountOff, free }

PromoType promoTypeFromString(String? value) {
  switch ((value ?? '').trim()) {
    case 'percent_off':
      return PromoType.percentOff;
    case 'amount_off':
      return PromoType.amountOff;
    case 'free':
      return PromoType.free;
    default:
      return PromoType.percentOff;
  }
}

String promoTypeToString(PromoType value) {
  switch (value) {
    case PromoType.percentOff:
      return 'percent_off';
    case PromoType.amountOff:
      return 'amount_off';
    case PromoType.free:
      return 'free';
  }
}

class Promo extends Equatable {
  const Promo({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.validFrom,
    required this.validTo,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String name;
  final PromoType type;
  final double value;
  final String validFrom; // YYYY-MM-DD
  final String validTo; // YYYY-MM-DD
  final bool isActive;
  final DateTime? createdAt;

  bool isValidOnDay(String day) {
    // Works for YYYY-MM-DD lexicographic ordering.
    return validFrom.compareTo(day) <= 0 && validTo.compareTo(day) >= 0;
  }

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        value,
        validFrom,
        validTo,
        isActive,
        createdAt,
      ];
}

