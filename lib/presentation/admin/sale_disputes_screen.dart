import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/disputes_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/sale_dispute.dart';

class SaleDisputesScreen extends StatefulWidget {
  const SaleDisputesScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<SaleDisputesScreen> createState() => _SaleDisputesScreenState();
}

class _SaleDisputesScreenState extends State<SaleDisputesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final DisputesRepository _repo;
  StreamSubscription<List<SaleDispute>>? _sub;

  List<SaleDispute> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repo = context.read<DisputesRepository>();
    _sub = _repo.watchAll(limit: 300).listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _all = list;
          _loading = false;
          _error = null;
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<SaleDispute> _filter(DisputeStatus status) =>
      _all.where((d) => d.status == status).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pendingCount = _filter(DisputeStatus.pending).length;

    return Column(
      children: [
        Material(
          color: scheme.surfaceContainerHighest,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Pending'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      _CountBadge(count: pendingCount),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Resolved'),
              const Tab(text: 'Dismissed'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _DisputeList(
                          disputes: _filter(DisputeStatus.pending),
                          emptyLabel: 'No pending disputes',
                          admin: widget.user,
                          repo: _repo,
                          showActions: true,
                        ),
                        _DisputeList(
                          disputes: _filter(DisputeStatus.resolved),
                          emptyLabel: 'No resolved disputes',
                          admin: widget.user,
                          repo: _repo,
                          showActions: false,
                        ),
                        _DisputeList(
                          disputes: _filter(DisputeStatus.dismissed),
                          emptyLabel: 'No dismissed disputes',
                          admin: widget.user,
                          repo: _repo,
                          showActions: false,
                        ),
                      ],
                    ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _DisputeList extends StatelessWidget {
  const _DisputeList({
    required this.disputes,
    required this.emptyLabel,
    required this.admin,
    required this.repo,
    required this.showActions,
  });

  final List<SaleDispute> disputes;
  final String emptyLabel;
  final AppUser admin;
  final DisputesRepository repo;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    if (disputes.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: disputes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = disputes[index];
        return _DisputeCard(
          dispute: d,
          admin: admin,
          repo: repo,
          showActions: showActions,
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.admin,
    required this.repo,
    required this.showActions,
  });

  final SaleDispute dispute;
  final AppUser admin;
  final DisputesRepository repo;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = switch (dispute.status) {
      DisputeStatus.pending => Colors.orange,
      DisputeStatus.resolved => Colors.green,
      DisputeStatus.dismissed => Colors.grey,
    };

    final typeColor = switch (dispute.type) {
      DisputeType.requestEdit => Colors.blue,
      DisputeType.requestDelete => Colors.red,
      DisputeType.report => Colors.orange,
    };

    final typeIcon = switch (dispute.type) {
      DisputeType.requestEdit => Icons.edit_outlined,
      DisputeType.requestDelete => Icons.delete_outline_rounded,
      DisputeType.report => Icons.report_outlined,
    };

    final dateStr = dispute.createdAt != null
        ? _formatDate(dispute.createdAt!)
        : 'Unknown time';

    final changes = dispute.proposedChanges;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(typeIcon, color: typeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dispute.type.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                      Text(
                        'by ${dispute.reportedByName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dispute.status.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Sale info
            Text(
              'Sale: ${dispute.saleDay}  (ID: ${dispute.saleId.substring(0, 8.clamp(0, dispute.saleId.length))}...)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),

            // Reason
            if (dispute.reason.isNotEmpty && dispute.type == DisputeType.report)
              Text(dispute.reason, style: theme.textTheme.bodyMedium),

            // Proposed changes for edit requests
            if (dispute.type == DisputeType.requestEdit && changes != null && changes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Proposed changes:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (changes['price'] != null)
                      Text('Price: ₱${(changes['price'] as num).toStringAsFixed(0)}', style: theme.textTheme.bodySmall),
                    if (changes['payment_method'] != null)
                      Text('Payment: ${changes['payment_method']}', style: theme.textTheme.bodySmall),
                    if (changes['notes'] != null && (changes['notes'] as String).isNotEmpty)
                      Text('Notes: ${changes['notes']}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],

            // Delete reason
            if (dispute.type == DisputeType.requestDelete && dispute.reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Reason: ${dispute.reason}', style: theme.textTheme.bodyMedium),
            ],

            const SizedBox(height: 6),

            // Date
            Text(
              dateStr,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),

            // Admin notes (if resolved/dismissed)
            if (dispute.adminNotes != null && dispute.adminNotes!.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'Admin: ${dispute.adminNotes}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (dispute.resolvedByName != null)
                Text(
                  '— ${dispute.resolvedByName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],

            // Action buttons
            if (showActions) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _showResolveDialog(
                      context,
                      DisputeStatus.dismissed,
                      'Dismiss',
                    ),
                    child: const Text('Dismiss'),
                  ),
                  // For edit/delete requests: "Approve" applies the change
                  if (dispute.type == DisputeType.requestEdit ||
                      dispute.type == DisputeType.requestDelete)
                    FilledButton.icon(
                      onPressed: () => _approveRequest(context),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                    )
                  else
                    FilledButton(
                      onPressed: () => _showResolveDialog(
                        context,
                        DisputeStatus.resolved,
                        'Resolve',
                      ),
                      child: const Text('Resolve'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(BuildContext context) async {
    final salesRepo = context.read<SalesRepository>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          dispute.type == DisputeType.requestDelete
              ? 'Approve delete?'
              : 'Approve edit?',
        ),
        content: Text(
          dispute.type == DisputeType.requestDelete
              ? 'This will permanently delete the sale.'
              : 'This will apply the proposed changes to the sale.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      if (dispute.type == DisputeType.requestDelete) {
        await salesRepo.deleteSale(dispute.saleId);
      } else if (dispute.type == DisputeType.requestEdit) {
        final changes = dispute.proposedChanges ?? {};
        await salesRepo.updateSaleFields(
          saleId: dispute.saleId,
          price: (changes['price'] as num?)?.toDouble() ?? 0,
          paymentMethodName: changes['payment_method'] as String?,
          notes: changes['notes'] as String?,
        );
      }

      // Mark dispute as resolved
      await repo.resolve(
        disputeId: dispute.id,
        newStatus: DisputeStatus.resolved,
        adminUid: admin.uid,
        adminName: admin.displayName,
        adminNotes: 'Approved',
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${dispute.type.label} approved.')),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to apply. Try again.')),
      );
    }
  }

  void _showResolveDialog(
    BuildContext context,
    DisputeStatus newStatus,
    String actionLabel,
  ) {
    showDialog(
      context: context,
      builder: (_) => _ResolveDialog(
        dispute: dispute,
        newStatus: newStatus,
        actionLabel: actionLabel,
        admin: admin,
        repo: repo,
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[dt.month - 1];
    final d = dt.day;
    final y = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final min = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$m $d, $y  $hour:$min $amPm';
  }
}

// ═════════════════════════════════════════════════════════════════════════════

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({
    required this.dispute,
    required this.newStatus,
    required this.actionLabel,
    required this.admin,
    required this.repo,
  });

  final SaleDispute dispute;
  final DisputeStatus newStatus;
  final String actionLabel;
  final AppUser admin;
  final DisputesRepository repo;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  static const _resolveTemplates = [
    'Price corrected',
    'Barber updated',
    'Service updated',
    'Duplicate deleted',
    'Payment method fixed',
    'Promo adjusted',
    'Sale voided',
  ];

  static const _dismissTemplates = [
    'No issue found',
    'Already handled',
    'Not actionable',
    'Duplicate report',
  ];

  final _notesCtrl = TextEditingController();
  String? _selectedTemplate;
  bool _busy = false;
  String? _error;

  List<String> get _templates =>
      widget.newStatus == DisputeStatus.resolved
          ? _resolveTemplates
          : _dismissTemplates;

  String? get _finalNotes {
    final parts = <String>[];
    if (_selectedTemplate != null) parts.add(_selectedTemplate!);
    final extra = _notesCtrl.text.trim();
    if (extra.isNotEmpty) parts.add(extra);
    return parts.isEmpty ? null : parts.join(' — ');
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repo.resolve(
        disputeId: widget.dispute.id,
        newStatus: widget.newStatus,
        adminUid: widget.admin.uid,
        adminName: widget.admin.displayName,
        adminNotes: _finalNotes,
      );
      if (mounted) Navigator.of(context).pop();
    } on Object {
      setState(() => _error = 'Failed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text('${widget.actionLabel} dispute'),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
              ],
              Text('Quick response', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _templates.map((t) {
                  final selected = _selectedTemplate == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (val) {
                      setState(() => _selectedTemplate = val ? t : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Additional notes (optional)',
                  hintText: 'Add more details...',
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.actionLabel),
        ),
      ],
    );
  }
}
