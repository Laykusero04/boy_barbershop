import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:boy_barbershop/models/sale_dispute.dart';

class DisputesRepository {
  DisputesRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('sale_disputes');

  /// Submit a general report (cashier / barber).
  Future<void> reportSale({
    required String saleId,
    required String saleDay,
    required String reportedByUid,
    required String reportedByName,
    required String reason,
  }) async {
    await _col.add({
      'sale_id': saleId,
      'sale_day': saleDay,
      'reported_by_uid': reportedByUid,
      'reported_by_name': reportedByName,
      'reason': reason.trim(),
      'type': DisputeType.report.toFirestore(),
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Submit an edit request with proposed changes.
  Future<void> requestEdit({
    required String saleId,
    required String saleDay,
    required String reportedByUid,
    required String reportedByName,
    required String reason,
    required Map<String, dynamic> proposedChanges,
  }) async {
    await _col.add({
      'sale_id': saleId,
      'sale_day': saleDay,
      'reported_by_uid': reportedByUid,
      'reported_by_name': reportedByName,
      'reason': reason.trim(),
      'type': DisputeType.requestEdit.toFirestore(),
      'proposed_changes': proposedChanges,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Submit a delete request with a reason.
  Future<void> requestDelete({
    required String saleId,
    required String saleDay,
    required String reportedByUid,
    required String reportedByName,
    required String reason,
  }) async {
    await _col.add({
      'sale_id': saleId,
      'sale_day': saleDay,
      'reported_by_uid': reportedByUid,
      'reported_by_name': reportedByName,
      'reason': reason.trim(),
      'type': DisputeType.requestDelete.toFirestore(),
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Stream all disputes (newest first). Admin uses this.
  Stream<List<SaleDispute>> watchAll({int limit = 200}) {
    return _col
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(SaleDispute.fromDoc).toList());
  }

  /// Stream only pending disputes (for badge count).
  Stream<int> watchPendingCount() {
    return _col
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Admin resolves or dismisses a dispute.
  Future<void> resolve({
    required String disputeId,
    required DisputeStatus newStatus,
    required String adminUid,
    required String adminName,
    String? adminNotes,
  }) async {
    await _col.doc(disputeId).update({
      'status': newStatus.name,
      'resolved_by_uid': adminUid,
      'resolved_by_name': adminName,
      'admin_notes': adminNotes?.trim(),
      'resolved_at': FieldValue.serverTimestamp(),
    });
  }
}
