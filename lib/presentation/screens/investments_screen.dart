import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class InvestmentsScreen extends StatefulWidget {
  const InvestmentsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<InvestmentsScreen> createState() => _InvestmentsScreenState();
}

class _InvestmentsScreenState extends State<InvestmentsScreen> {
  final _cashflow = CashflowRepository();
  late String _day;

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Investments', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Owner deposits and withdrawals. These are recorded inside Cash flow for proper reconciliation.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add owner transaction', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _DateField(
                    label: 'Date',
                    value: _day,
                    onPick: () async {
                      final picked = await _pickDay(context, initial: _day);
                      if (picked == null) return;
                      setState(() => _day = picked);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openDialog(context, type: _OwnerTxnType.deposit),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Owner deposit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _openDialog(context, type: _OwnerTxnType.withdrawal),
                          icon: const Icon(Icons.remove_rounded),
                          label: const Text('Owner withdrawal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<CashflowEntry>>(
            stream: _cashflow.watchEntriesForDay(_day, limit: 500),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorCard(title: 'Could not load entries', error: snap.error);
              }
              final items = (snap.data ?? const <CashflowEntry>[])
                  .where((e) => _isOwnerCategory(e.category))
                  .toList(growable: false);

              if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return _EmptyStateCard(
                  title: 'No owner transactions for this day.',
                  subtitle: 'Record deposits and withdrawals here.',
                );
              }

              final deposits = items
                  .where((e) => e.type == CashflowType.cashIn)
                  .fold<double>(0, (s, e) => s + e.amount);
              final withdrawals = items
                  .where((e) => e.type == CashflowType.cashOut)
                  .fold<double>(0, (s, e) => s + e.amount);

              return Column(
                children: [
                  _TotalsCard(deposits: deposits, withdrawals: withdrawals),
                  const SizedBox(height: 12),
                  for (final e in items) ...[
                    _OwnerTxnTile(entry: e, onDelete: () => _confirmDelete(context, e)),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openDialog(BuildContext context, {required _OwnerTxnType type}) async {
    final result = await showDialog<_OwnerTxnResult>(
      context: context,
      builder: (context) => _OwnerTxnDialog(day: _day, type: type),
    );
    if (!context.mounted || result == null) return;

    try {
      await _cashflow.createEntry(
        occurredAtUtc: result.occurredAtUtc,
        occurredDayManila: result.dayManila,
        type: result.cashflowType,
        category: result.category,
        amount: result.amount,
        paymentMethod: result.paymentMethod,
        referenceSaleId: null,
        referenceExpenseId: null,
        notes: result.notes,
        createdByUid: widget.user.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner transaction saved.')),
      );
      setState(() => _day = result.dayManila);
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, CashflowEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!context.mounted || ok != true) return;

    try {
      await _cashflow.deleteEntry(entry.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction deleted.')),
      );
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

enum _OwnerTxnType { deposit, withdrawal }

class _OwnerTxnResult {
  const _OwnerTxnResult({
    required this.occurredAtUtc,
    required this.dayManila,
    required this.cashflowType,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
  });

  final DateTime occurredAtUtc;
  final String dayManila;
  final CashflowType cashflowType;
  final String category;
  final double amount;
  final String? paymentMethod;
  final String? notes;
}

class _OwnerTxnDialog extends StatefulWidget {
  const _OwnerTxnDialog({required this.day, required this.type});

  final String day;
  final _OwnerTxnType type;

  @override
  State<_OwnerTxnDialog> createState() => _OwnerTxnDialogState();
}

class _OwnerTxnDialogState extends State<_OwnerTxnDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _day;
  late TimeOfDay _time;
  final _amountController = TextEditingController();
  final _paymentController = TextEditingController(text: 'Cash');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = parseYyyyMmDd(widget.day) ?? parseYyyyMmDd(todayManilaDay()) ?? DateTime.now();
    final now = nowManila();
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == _OwnerTxnType.deposit ? 'Owner deposit' : 'Owner withdrawal';
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DateField(
                  label: 'Date',
                  value: yyyyMmDd(_day),
                  onPick: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked == null) return;
                    setState(() => _day = DateTime(picked.year, picked.month, picked.day));
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _time);
                    if (picked == null) return;
                    setState(() => _time = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      suffixIcon: Icon(Icons.schedule_outlined),
                    ),
                    child: Text(_time.format(context)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount', hintText: '0.00'),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final parsed = _parseMoney(v);
                    if (parsed == null) return 'Enter a valid amount.';
                    if (parsed <= 0) return 'Amount must be greater than 0.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _paymentController,
                  decoration: const InputDecoration(
                    labelText: 'Payment method (optional)',
                    hintText: 'Cash / GCash / Bank',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (recommended)',
                  ),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _submit() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    final amount = _parseMoney(_amountController.text);
    if (amount == null) return;

    final dtUtc = utcFromManilaParts(
      year: _day.year,
      month: _day.month,
      day: _day.day,
      hour: _time.hour,
      minute: _time.minute,
    );
    final dayManila = yyyyMmDd(_day);

    final cashflowType =
        widget.type == _OwnerTxnType.deposit ? CashflowType.cashIn : CashflowType.cashOut;
    final category =
        widget.type == _OwnerTxnType.deposit ? 'Owner deposit' : 'Owner withdrawal';

    Navigator.of(context).pop(
      _OwnerTxnResult(
        occurredAtUtc: dtUtc,
        dayManila: dayManila,
        cashflowType: cashflowType,
        category: category,
        amount: amount,
        paymentMethod: _paymentController.text.trim().isEmpty ? null : _paymentController.text,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text,
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.deposits,
    required this.withdrawals,
  });

  final double deposits;
  final double withdrawals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _pill(context, 'Deposits', deposits, theme.colorScheme.secondary),
            _pill(context, 'Withdrawals', withdrawals, theme.colorScheme.error),
            _pill(
              context,
              'Net',
              deposits - withdrawals,
              (deposits - withdrawals) < 0
                  ? theme.colorScheme.error
                  : theme.colorScheme.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String label, double value, Color color) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: ₱${_formatMoney(value)}',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _OwnerTxnTile extends StatelessWidget {
  const _OwnerTxnTile({required this.entry, required this.onDelete});

  final CashflowEntry entry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = entry.type == CashflowType.cashIn;
    final color = isIn ? theme.colorScheme.secondary : theme.colorScheme.error;
    final dt = entry.occurredAt;
    final time = dt == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(dt.toLocal()),
            alwaysUse24HourFormat: false,
          );

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.category,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${isIn ? '+' : '-'}₱${_formatMoney(entry.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                Text(
                  'Time: $time',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if ((entry.paymentMethod ?? '').trim().isNotEmpty)
                  Text(
                    'Method: ${entry.paymentMethod}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if ((entry.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                entry.notes!.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Delete'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final String value; // YYYY-MM-DD
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value),
      ),
    );
  }
}

Future<String?> _pickDay(BuildContext context, {required String initial}) async {
  final parsed = parseYyyyMmDd(initial);
  final now = DateTime.now();
  final initialDate = parsed ?? DateTime(now.year, now.month, now.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  if (picked == null) return null;
  return yyyyMmDd(picked);
}

bool _isOwnerCategory(String category) {
  final c = category.trim().toLowerCase();
  return c == 'owner deposit' || c == 'owner withdrawal';
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.title, required this.error});

  final String title;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error: ${error ?? 'Unknown'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double? _parseMoney(String? raw) {
  final cleaned = (raw ?? '').trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}

