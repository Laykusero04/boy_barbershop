import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum DayClassification { full, half }

extension DayClassificationWire on DayClassification {
  String get wire => this == DayClassification.full ? 'full' : 'half';

  static DayClassification? fromWire(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'full') return DayClassification.full;
    if (value == 'half') return DayClassification.half;
    return null;
  }
}

class BarberShift extends Equatable {
  const BarberShift({
    required this.id,
    required this.barberId,
    required this.occurredDay,
    required this.openedAt,
    required this.openedByUid,
    required this.closedAt,
    required this.closedByUid,
    required this.dayClassification,
    required this.notes,
  });

  final String id;
  final String barberId;
  final String occurredDay; // YYYY-MM-DD (Asia/Manila)
  final DateTime? openedAt;
  final String? openedByUid;
  final DateTime? closedAt;
  final String? closedByUid;
  final DayClassification? dayClassification;
  final String? notes;

  bool get isOpen => closedAt == null;

  static BarberShift fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return BarberShift(
      id: doc.id,
      barberId: ((data['barber_id'] as String?) ?? '').trim(),
      occurredDay: ((data['occurred_day'] as String?) ?? '').trim(),
      openedAt: (data['opened_at'] as Timestamp?)?.toDate(),
      openedByUid: (data['opened_by_uid'] as String?)?.trim(),
      closedAt: (data['closed_at'] as Timestamp?)?.toDate(),
      closedByUid: (data['closed_by_uid'] as String?)?.trim(),
      dayClassification:
          DayClassificationWire.fromWire(data['day_classification'] as String?),
      notes: (data['notes'] as String?)?.trim(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        barberId,
        occurredDay,
        openedAt,
        openedByUid,
        closedAt,
        closedByUid,
        dayClassification,
        notes,
      ];
}
