import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class CashflowScreen extends StatefulWidget {
  const CashflowScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<CashflowScreen> createState() => _CashflowScreenState();
}

class _CashflowScreenState extends State<CashflowScreen> {
  late String _day;

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Ledger'),
                      Tab(text: 'Daily summary'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _CashflowLedgerTab(
                    user: widget.user,
                    initialDay: _day,
                    onDayChanged: (v) => setState(() => _day = v),
                  ),
                  _CashflowDailySummaryTab(
                    user: widget.user,
                    initialDay: _day,
                    onDayChanged: (v) => setState(() => _day = v),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashflowLedgerTab extends StatefulWidget {
  const _CashflowLedgerTab({
    required this.user,
    required this.initialDay,
    required this.onDayChanged,
  });

  final AppUser user;
  final String initialDay;
  final ValueChanged<String> onDayChanged;

  @override
  State<_CashflowLedgerTab> createState() => _CashflowLedgerTabState();
}

class _CashflowLedgerTabState extends State<_CashflowLedgerTab> {
  late String _day;
  late String _viewDay;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    _viewDay = _day;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CashflowRepository>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ledger', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Date',
                        value: _day,
                        onPick: () async {
                          final picked = await _pickDay(context, initial: _day);
                          if (picked == null) return;
                          setState(() => _day = picked);
                          widget.onDayChanged(picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => setState(() => _viewDay = _day),
                      child: const Text('View'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openAddEntry(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add entry'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<CashflowEntry>>(
          stream: repo.watchEntriesForDay(_viewDay, limit: 500),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(title: 'Could not load cashflow', error: snap.error);
            }
            final items = snap.data ?? const <CashflowEntry>[];
            if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return _EmptyStateCard(
                title: 'No entries for this day.',
                subtitle: 'Add opening cash, expenses, withdrawals, and adjustments.',
              );
            }

            final totals = _totals(items);
            return Column(
              children: [
                _TotalsCard(
                  cashIn: totals.cashIn,
                  cashOut: totals.cashOut,
                  net: totals.net,
                ),
                const SizedBox(height: 12),
                for (final e in items) ...[
                  _CashflowTile(
                    entry: e,
                    onDelete: () => _confirmDelete(context, e),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openAddEntry(BuildContext context) async {
    final result = await showDialog<_AddEntryResult>(
      context: context,
      builder: (context) => _AddEntryDialog(initialDay: _viewDay),
    );
    if (!context.mounted || result == null) return;

    final repo = context.read<CashflowRepository>();
    try {
      final dt = utcFromManilaParts(
        year: result.day.year,
        month: result.day.month,
        day: result.day.day,
        hour: result.time.hour,
        minute: result.time.minute,
      );
      final dayManila = yyyyMmDd(result.day);
      await repo.createEntry(
        occurredAtUtc: dt,
        occurredDayManila: dayManila,
        type: result.type,
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
        const SnackBar(content: Text('Cashflow entry saved.')),
      );
      setState(() {
        _day = dayManila;
        _viewDay = dayManila;
      });
      widget.onDayChanged(dayManila);
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, CashflowEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
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

    final repo = context.read<CashflowRepository>();
    try {
      await repo.deleteEntry(entry.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted.')),
      );
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _CashflowDailySummaryTab extends StatefulWidget {
  const _CashflowDailySummaryTab({
    required this.user,
    required this.initialDay,
    required this.onDayChanged,
  });

  final AppUser user;
  final String initialDay;
  final ValueChanged<String> onDayChanged;

  @override
  State<_CashflowDailySummaryTab> createState() => _CashflowDailySummaryTabState();
}

class _CashflowDailySummaryTabState extends State<_CashflowDailySummaryTab> {
  late String _day;
  late String _viewDay;

  final _actualController = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    _viewDay = _day;
  }

  @override
  void dispose() {
    _actualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CashflowRepository>();
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily reconciliation', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Expected cash = Opening + Cash-in − Cash-out. If actual differs, record an Over/short adjustment.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Date',
                        value: _day,
                        onPick: () async {
                          final picked = await _pickDay(context, initial: _day);
                          if (picked == null) return;
                          setState(() => _day = picked);
                          widget.onDayChanged(picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => setState(() => _viewDay = _day),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<CashflowEntry>>(
          stream: repo.watchEntriesForDay(_viewDay, limit: 1000),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(title: 'Could not load summary', error: snap.error);
            }
            final items = snap.data ?? const <CashflowEntry>[];
            if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final opening = _openingCash(items);
            final totals = _totals(items);
            final expected = opening + totals.net;
            final actual = _parseMoney(_actualController.text);
            final diff = (actual == null) ? null : (actual - expected);

            final byCategory = _byCategory(items);

            return Column(
              children: [
                Card(
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
                              child: Text('Summary', style: theme.textTheme.titleMedium),
                            ),
                            Text(
                              _viewDay,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _kv('Opening cash', opening),
                        _kv('Cash-in total', totals.cashIn),
                        _kv('Cash-out total', totals.cashOut),
                        const Divider(height: 20),
                        _kv('Expected closing cash', expected, bold: true),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _actualController,
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Actual cash count (optional)',
                            hintText: '0.00',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        if (diff != null)
                          Text(
                            'Difference: ₱${_formatMoney(diff)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: diff == 0
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (required for adjustment)',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonal(
                            onPressed: diff == null || diff == 0
                                ? null
                                : () => _recordAdjustment(
                                      context,
                                      day: _viewDay,
                                      diff: diff,
                                    ),
                            child: const Text('Record over/short adjustment'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _TotalsCard(cashIn: totals.cashIn, cashOut: totals.cashOut, net: totals.net),
                const SizedBox(height: 12),
                if (byCategory.isNotEmpty)
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('By category', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (final row in byCategory) ...[
                            Row(
                              children: [
                                Expanded(child: Text(row.category)),
                                Text(
                                  '₱${_formatMoney(row.net)}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: row.net < 0
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _kv(String label, double value, {bool bold = false}) {
    final theme = Theme.of(context);
    final style = (bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)?.copyWith(
      fontWeight: bold ? FontWeight.w900 : null,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text('₱${_formatMoney(value)}', style: style),
        ],
      ),
    );
  }

  Future<void> _recordAdjustment(
    BuildContext context, {
    required String day,
    required double diff,
  }) async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes are required for adjustments.')),
      );
      return;
    }

    final parsedDay = parseYyyyMmDd(day);
    if (parsedDay == null) return;

    final type = diff > 0 ? CashflowType.cashIn : CashflowType.cashOut;
    final amount = diff.abs();
    final now = nowManila();
    final dtUtc = utcFromManilaParts(
      year: parsedDay.year,
      month: parsedDay.month,
      day: parsedDay.day,
      hour: now.hour,
      minute: now.minute,
    );

    final repo = context.read<CashflowRepository>();
    try {
      await repo.createEntry(
        occurredAtUtc: dtUtc,
        occurredDayManila: day,
        type: type,
        category: 'Over/short adjustment',
        amount: amount,
        paymentMethod: 'Cash',
        referenceSaleId: null,
        referenceExpenseId: null,
        notes: notes,
        createdByUid: widget.user.uid,
      );
      if (!context.mounted) return;
      _notesController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustment recorded.')),
      );
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Totals {
  const _Totals({required this.cashIn, required this.cashOut, required this.net});
  final double cashIn;
  final double cashOut;
  final double net;
}

_Totals _totals(List<CashflowEntry> items) {
  final cashIn = items
      .where((e) => e.type == CashflowType.cashIn)
      .fold<double>(0, (sum, e) => sum + e.amount);
  final cashOut = items
      .where((e) => e.type == CashflowType.cashOut)
      .fold<double>(0, (sum, e) => sum + e.amount);
  return _Totals(cashIn: cashIn, cashOut: cashOut, net: cashIn - cashOut);
}

double _openingCash(List<CashflowEntry> items) {
  final candidates = items.where((e) {
    final c = e.category.trim().toLowerCase();
    return c == 'opening cash' || c.contains('opening cash') || c.contains('float');
  });
  return candidates.fold<double>(0, (sum, e) => sum + e.signedAmount);
}

class _CategoryRow {
  const _CategoryRow({required this.category, required this.net});
  final String category;
  final double net;
}

List<_CategoryRow> _byCategory(List<CashflowEntry> items) {
  final map = <String, double>{};
  for (final e in items) {
    final key = e.category.trim().isEmpty ? 'Uncategorized' : e.category.trim();
    map[key] = (map[key] ?? 0) + e.signedAmount;
  }
  final out = map.entries
      .map((e) => _CategoryRow(category: e.key, net: e.value))
      .toList(growable: false);
  out.sort((a, b) => b.net.abs().compareTo(a.net.abs()));
  return out;
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.cashIn,
    required this.cashOut,
    required this.net,
  });

  final double cashIn;
  final double cashOut;
  final double net;

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
            _pill(context, 'Cash-in', cashIn, theme.colorScheme.secondary),
            _pill(context, 'Cash-out', cashOut, theme.colorScheme.error),
            _pill(
              context,
              'Net',
              net,
              net < 0 ? theme.colorScheme.error : theme.colorScheme.secondary,
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

class _CashflowTile extends StatelessWidget {
  const _CashflowTile({
    required this.entry,
    required this.onDelete,
  });

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
    final category = entry.category.trim().isEmpty ? '—' : entry.category.trim();

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
                    category,
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
                Text(
                  'Type: ${isIn ? 'Cash-in' : 'Cash-out'}',
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
                if ((entry.referenceSaleId ?? '').trim().isNotEmpty)
                  Text(
                    'Sale: #${entry.referenceSaleId}',
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

class _AddEntryResult {
  const _AddEntryResult({
    required this.type,
    required this.category,
    required this.amount,
    required this.day,
    required this.time,
    required this.paymentMethod,
    required this.notes,
  });

  final CashflowType type;
  final String category;
  final double amount;
  final DateTime day;
  final TimeOfDay time;
  final String? paymentMethod;
  final String? notes;
}

class _AddEntryDialog extends StatefulWidget {
  const _AddEntryDialog({required this.initialDay});

  final String initialDay;

  @override
  State<_AddEntryDialog> createState() => _AddEntryDialogState();
}

class _AddEntryDialogState extends State<_AddEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  CashflowType _type = CashflowType.cashOut;
  late DateTime _day;
  late TimeOfDay _time;

  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentController = TextEditingController(text: 'Cash');
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = parseYyyyMmDd(widget.initialDay) ?? parseYyyyMmDd(todayManilaDay()) ?? DateTime.now();
    final now = nowManila();
    _time = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _amountController.dispose();
    _paymentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add cashflow entry'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<CashflowType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: CashflowType.cashIn,
                      child: Text('Cash-in'),
                    ),
                    DropdownMenuItem(
                      value: CashflowType.cashOut,
                      child: Text('Cash-out'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? CashflowType.cashOut),
                ),
                const SizedBox(height: 12),
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
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time,
                    );
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
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    hintText: 'Supplies / consumables',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Category is required.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: false,
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                  ),
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
                    hintText: 'Cash / GCash',
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
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

    Navigator.of(context).pop(
      _AddEntryResult(
        type: _type,
        category: _categoryController.text,
        amount: amount,
        day: _day,
        time: _time,
        paymentMethod: _paymentController.text.trim().isEmpty ? null : _paymentController.text,
        notes: _notesController.text,
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
