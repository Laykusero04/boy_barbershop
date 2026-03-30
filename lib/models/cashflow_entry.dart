import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum CashflowType { cashIn, cashOut }

extension CashflowTypeWire on CashflowType {
  String get wire => this == CashflowType.cashIn ? 'in' : 'out';

  static CashflowType? fromWire(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'in':
        return CashflowType.cashIn;
      case 'out':
        return CashflowType.cashOut;
      default:
        return null;
    }
  }
}

class CashflowEntry extends Equatable {
  const CashflowEntry({
    required this.id,
    required this.occurredAt,
    required this.occurredDay,
    required this.type,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.referenceSaleId,
    required this.referenceExpenseId,
    required this.notes,
    required this.createdByUid,
    required this.createdAt,
  });

  final String id;
  final DateTime? occurredAt;
  final String occurredDay; // YYYY-MM-DD (Asia/Manila)
  final CashflowType type;
  final String category;
  final double amount; // always positive
  final String? paymentMethod; // optional (Cash/GCash/etc)
  final String? referenceSaleId;
  final String? referenceExpenseId;
  final String? notes;
  final String? createdByUid;
  final DateTime? createdAt;

  static CashflowEntry fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final rawType = ((data['flow_type'] as String?) ?? '').trim();
    final parsedType = CashflowTypeWire.fromWire(rawType) ?? CashflowType.cashIn;
    return CashflowEntry(
      id: doc.id,
      occurredAt: (data['occurred_at'] as Timestamp?)?.toDate(),
      occurredDay: ((data['occurred_day'] as String?) ?? '').trim(),
      type: parsedType,
      category: ((data['category'] as String?) ?? '').trim(),
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: (data['payment_method'] as String?)?.trim(),
      referenceSaleId: (data['reference_sale_id'] as String?)?.trim(),
      referenceExpenseId: (data['reference_expense_id'] as String?)?.trim(),
      notes: (data['notes'] as String?)?.trim(),
      createdByUid: (data['created_by_uid'] as String?)?.trim(),
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  double get signedAmount => type == CashflowType.cashIn ? amount : -amount;

  @override
  List<Object?> get props => [
        id,
        occurredAt,
        occurredDay,
        type,
        category,
        amount,
        paymentMethod,
        referenceSaleId,
        referenceExpenseId,
        notes,
        createdByUid,
        createdAt,
      ];
}

