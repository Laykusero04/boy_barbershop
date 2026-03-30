import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Expense extends Equatable {
  const Expense({
    required this.id,
    required this.occurredAt,
    required this.occurredDay,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.vendor,
    required this.receiptNo,
    required this.notes,
    required this.isRefund,
    required this.referenceSaleId,
    required this.createdByUid,
    required this.createdAt,
  });

  final String id;
  final DateTime? occurredAt;
  final String occurredDay; // YYYY-MM-DD (Asia/Manila)
  final String category;
  final double amount; // always positive
  final String? paymentMethod;
  final String? vendor;
  final String? receiptNo;
  final String? notes;
  final bool isRefund;
  final String? referenceSaleId;
  final String? createdByUid;
  final DateTime? createdAt;

  static Expense fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Expense(
      id: doc.id,
      occurredAt: (data['occurred_at'] as Timestamp?)?.toDate(),
      occurredDay: ((data['occurred_day'] as String?) ?? '').trim(),
      category: ((data['category'] as String?) ?? '').trim(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: (data['payment_method'] as String?)?.trim(),
      vendor: (data['vendor'] as String?)?.trim(),
      receiptNo: (data['receipt_no'] as String?)?.trim(),
      notes: (data['notes'] as String?)?.trim(),
      isRefund: (data['is_refund'] as bool?) ?? false,
      referenceSaleId: (data['reference_sale_id'] as String?)?.trim(),
      createdByUid: (data['created_by_uid'] as String?)?.trim(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        occurredAt,
        occurredDay,
        category,
        amount,
        paymentMethod,
        vendor,
        receiptNo,
        notes,
        isRefund,
        referenceSaleId,
        createdByUid,
        createdAt,
      ];
}

