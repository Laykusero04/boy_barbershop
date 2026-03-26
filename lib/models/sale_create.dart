class SaleCreate {
  const SaleCreate({
    required this.barberId,
    required this.serviceId,
    required this.price,
    required this.saleDayManila,
    required this.paymentMethodName,
    required this.notes,
    required this.createdByUid,
    required this.promoId,
    required this.originalPrice,
    required this.discountAmount,
  });

  final String barberId;
  final String serviceId;
  final double price;
  final String saleDayManila; // YYYY-MM-DD in Asia/Manila
  final String? paymentMethodName;
  final String? notes;
  final String createdByUid;

  final String? promoId;
  final double? originalPrice;
  final double? discountAmount;
}

