import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Sale extends Equatable {
  const Sale({
    required this.id,
    required this.barberId,
    required this.serviceId,
    required this.price,
    required this.saleDay,
    required this.saleDateTime,
    required this.paymentMethod,
    required this.notes,
    required this.promoId,
    required this.originalPrice,
    required this.discountAmount,
    required this.ownerCoversDiscount,
    this.createdByUid,
  });

  final String id;
  final String barberId;
  final String serviceId;
  final double price;
  final String saleDay; // YYYY-MM-DD (Asia/Manila)
  final DateTime? saleDateTime;
  final String? paymentMethod;
  final String? notes;

  final String? promoId;
  final double? originalPrice;
  final double? discountAmount;
  final bool ownerCoversDiscount;
  final String? createdByUid;

  static Sale fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Sale(
      id: doc.id,
      barberId: ((data['barber_id'] as String?) ?? '').trim(),
      serviceId: ((data['service_id'] as String?) ?? '').trim(),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      saleDay: ((data['sale_day'] as String?) ?? '').trim(),
      saleDateTime: (data['sale_datetime'] as Timestamp?)?.toDate(),
      paymentMethod: (data['payment_method'] as String?)?.trim(),
      notes: (data['notes'] as String?)?.trim(),
      promoId: (data['promo_id'] as String?)?.trim(),
      originalPrice: (data['original_price'] as num?)?.toDouble(),
      discountAmount: (data['discount_amount'] as num?)?.toDouble(),
      ownerCoversDiscount: (data['owner_covers_discount'] as bool?) ?? false,
      createdByUid: (data['created_by_uid'] as String?)?.trim(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        barberId,
        serviceId,
        price,
        saleDay,
        saleDateTime,
        paymentMethod,
        notes,
        promoId,
        originalPrice,
        discountAmount,
        ownerCoversDiscount,
        createdByUid,
      ];
}

