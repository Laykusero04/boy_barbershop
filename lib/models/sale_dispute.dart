import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum DisputeStatus {
  pending,
  resolved,
  dismissed;

  String get label => switch (this) {
        DisputeStatus.pending => 'Pending',
        DisputeStatus.resolved => 'Resolved',
        DisputeStatus.dismissed => 'Dismissed',
      };

  static DisputeStatus fromString(String? value) => switch (value) {
        'resolved' => DisputeStatus.resolved,
        'dismissed' => DisputeStatus.dismissed,
        _ => DisputeStatus.pending,
      };
}

/// The type of request the cashier/barber is making.
enum DisputeType {
  report,
  requestEdit,
  requestDelete;

  String get label => switch (this) {
        DisputeType.report => 'Report',
        DisputeType.requestEdit => 'Edit request',
        DisputeType.requestDelete => 'Delete request',
      };

  static DisputeType fromString(String? value) => switch (value) {
        'request_edit' => DisputeType.requestEdit,
        'request_delete' => DisputeType.requestDelete,
        _ => DisputeType.report,
      };

  String toFirestore() => switch (this) {
        DisputeType.report => 'report',
        DisputeType.requestEdit => 'request_edit',
        DisputeType.requestDelete => 'request_delete',
      };
}

class SaleDispute extends Equatable {
  const SaleDispute({
    required this.id,
    required this.saleId,
    required this.saleDay,
    required this.reportedByUid,
    required this.reportedByName,
    required this.reason,
    required this.status,
    this.type = DisputeType.report,
    this.createdAt,
    this.resolvedByUid,
    this.resolvedByName,
    this.adminNotes,
    this.resolvedAt,
    this.proposedChanges,
  });

  final String id;
  final String saleId;
  final String saleDay;
  final String reportedByUid;
  final String reportedByName;
  final String reason;
  final DisputeStatus status;
  final DisputeType type;
  final DateTime? createdAt;
  final String? resolvedByUid;
  final String? resolvedByName;
  final String? adminNotes;
  final DateTime? resolvedAt;

  /// For edit requests: the proposed new values.
  /// Keys: price, barber_id, payment_method, notes
  final Map<String, dynamic>? proposedChanges;

  static SaleDispute fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SaleDispute(
      id: doc.id,
      saleId: (data['sale_id'] as String?) ?? '',
      saleDay: (data['sale_day'] as String?) ?? '',
      reportedByUid: (data['reported_by_uid'] as String?) ?? '',
      reportedByName: (data['reported_by_name'] as String?) ?? '',
      reason: (data['reason'] as String?) ?? '',
      status: DisputeStatus.fromString(data['status'] as String?),
      type: DisputeType.fromString(data['type'] as String?),
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
      resolvedByUid: data['resolved_by_uid'] as String?,
      resolvedByName: data['resolved_by_name'] as String?,
      adminNotes: data['admin_notes'] as String?,
      resolvedAt: (data['resolved_at'] as Timestamp?)?.toDate(),
      proposedChanges: (data['proposed_changes'] as Map<String, dynamic>?),
    );
  }

  @override
  List<Object?> get props => [
        id, saleId, saleDay, reportedByUid, reportedByName,
        reason, status, type, createdAt, resolvedByUid,
        resolvedByName, adminNotes, resolvedAt, proposedChanges,
      ];
}
