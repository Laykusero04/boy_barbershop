import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/expenses_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
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
                      Tab(text: 'Summary'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _ExpensesLedgerTab(
                    user: widget.user,
                    initialDay: _day,
                    onDayChanged: (v) => setState(() => _day = v),
                  ),
                  _ExpensesSummaryTab(
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

class _ExpensesLedgerTab extends StatefulWidget {
  const _ExpensesLedgerTab({
    required this.user,
    required this.initialDay,
    required this.onDayChanged,
  });

  final AppUser user;
  final String initialDay;
  final ValueChanged<String> onDayChanged;

  @override
  State<_ExpensesLedgerTab> createState() => _ExpensesLedgerTabState();
}

class _ExpensesLedgerTabState extends State<_ExpensesLedgerTab> {
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
    final repo = context.read<ExpensesRepository>();
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
                Text('Expenses ledger', style: theme.textTheme.titleMedium),
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
                    onPressed: () => _openAddExpense(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add expense'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Expense>>(
          stream: repo.watchExpensesForDay(_viewDay, limit: 500),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(title: 'Could not load expenses', error: snap.error);
            }
            final items = snap.data ?? const <Expense>[];
            if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return _EmptyStateCard(
                title: 'No expenses for this day.',
                subtitle: 'Record supplies, utilities, rent, refunds, etc.',
              );
            }

            final total = items.fold<double>(0, (sum, e) => sum + e.amount);
            return Column(
              children: [
                _TotalCard(total: total),
                const SizedBox(height: 12),
                for (final e in items) ...[
                  _ExpenseTile(
                    expense: e,
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

  Future<void> _openAddExpense(BuildContext context) async {
    final result = await showDialog<_AddExpenseResult>(
      context: context,
      builder: (context) => _AddExpenseDialog(initialDay: _viewDay),
    );
    if (!context.mounted || result == null) return;

    final repo = context.read<ExpensesRepository>();
    try {
      final dtUtc = utcFromManilaParts(
        year: result.day.year,
        month: result.day.month,
        day: result.day.day,
        hour: result.time.hour,
        minute: result.time.minute,
      );
      final dayManila = yyyyMmDd(result.day);
      await repo.createExpense(
        occurredAtUtc: dtUtc,
        occurredDayManila: dayManila,
        category: result.category,
        amount: result.amount,
        paymentMethod: result.paymentMethod,
        vendor: result.vendor,
        receiptNo: result.receiptNo,
        notes: result.notes,
        isRefund: result.isRefund,
        referenceSaleId: result.referenceSaleId,
        createdByUid: widget.user.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved.')),
      );
      setState(() {
        _day = dayManila;
        _viewDay = dayManila;
      });
      widget.onDayChanged(dayManila);
    } on ExpenseWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Expense expense) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
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

    final repo = context.read<ExpensesRepository>();
    try {
      await repo.deleteExpense(expense.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted.')),
      );
    } on ExpenseWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _ExpensesSummaryTab extends StatefulWidget {
  const _ExpensesSummaryTab({
    required this.initialDay,
    required this.onDayChanged,
  });

  final String initialDay;
  final ValueChanged<String> onDayChanged;

  @override
  State<_ExpensesSummaryTab> createState() => _ExpensesSummaryTabState();
}

class _ExpensesSummaryTabState extends State<_ExpensesSummaryTab> {
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
    final repo = context.read<ExpensesRepository>();
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
                Text('Summary', style: theme.textTheme.titleMedium),
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
        StreamBuilder<List<Expense>>(
          stream: repo.watchExpensesForDay(_viewDay, limit: 1000),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(title: 'Could not load summary', error: snap.error);
            }
            final items = snap.data ?? const <Expense>[];
            if (snap.connectionState == ConnectionState.waiting && items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final total = items.fold<double>(0, (sum, e) => sum + e.amount);
            final byCategory = _groupByCategory(items);
            final byMethod = _groupByPaymentMethod(items);

            return Column(
              children: [
                _TotalCard(total: total),
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
                                Expanded(child: Text(row.key)),
                                Text(
                                  '₱${_formatMoney(row.value)}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
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
                if (byCategory.isNotEmpty) const SizedBox(height: 12),
                if (byMethod.isNotEmpty)
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('By payment method', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          for (final row in byMethod) ...[
                            Row(
                              children: [
                                Expanded(child: Text(row.key)),
                                Text(
                                  '₱${_formatMoney(row.value)}',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
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
                if (items.isEmpty)
                  _EmptyStateCard(
                    title: 'No expenses for this day.',
                    subtitle: 'Try another date.',
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddExpenseResult {
  const _AddExpenseResult({
    required this.day,
    required this.time,
    required this.category,
    required this.amount,
    required this.paymentMethod,
    required this.vendor,
    required this.receiptNo,
    required this.notes,
    required this.isRefund,
    required this.referenceSaleId,
  });

  final DateTime day;
  final TimeOfDay time;
  final String category;
  final double amount;
  final String? paymentMethod;
  final String? vendor;
  final String? receiptNo;
  final String? notes;
  final bool isRefund;
  final String? referenceSaleId;
}

class _AddExpenseDialog extends StatefulWidget {
  const _AddExpenseDialog({required this.initialDay});

  final String initialDay;

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _day;
  late TimeOfDay _time;
  bool _isRefund = false;

  final _categoryController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentController = TextEditingController(text: 'Cash');
  final _vendorController = TextEditingController();
  final _receiptController = TextEditingController();
  final _notesController = TextEditingController();
  final _saleRefController = TextEditingController();

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
    _vendorController.dispose();
    _receiptController.dispose();
    _notesController.dispose();
    _saleRefController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add expense'),
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
                  controller: _vendorController,
                  decoration: const InputDecoration(labelText: 'Vendor (optional)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiptController,
                  decoration: const InputDecoration(labelText: 'Receipt no. (optional)'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This is a refund'),
                  subtitle: const Text('Notes are required for refunds.'),
                  value: _isRefund,
                  onChanged: (v) => setState(() => _isRefund = v),
                ),
                if (_isRefund) ...[
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _saleRefController,
                    decoration: const InputDecoration(
                      labelText: 'Reference sale id (optional)',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 2,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if (!_isRefund) return null;
                    return (v == null || v.trim().isEmpty)
                        ? 'Notes are required for refunds.'
                        : null;
                  },
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
      _AddExpenseResult(
        day: _day,
        time: _time,
        category: _categoryController.text,
        amount: amount,
        paymentMethod: _paymentController.text.trim().isEmpty ? null : _paymentController.text,
        vendor: _vendorController.text,
        receiptNo: _receiptController.text,
        notes: _notesController.text,
        isRefund: _isRefund,
        referenceSaleId: _saleRefController.text.trim().isEmpty ? null : _saleRefController.text,
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Total expenses',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              '₱${_formatMoney(total)}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.onDelete,
  });

  final Expense expense;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dt = expense.occurredAt;
    final time = dt == null
        ? '—'
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(dt.toLocal()),
            alwaysUse24HourFormat: false,
          );
    final title = expense.category.trim().isEmpty ? '—' : expense.category.trim();

    final chips = <String>[];
    if ((expense.paymentMethod ?? '').trim().isNotEmpty) chips.add(expense.paymentMethod!.trim());
    if ((expense.vendor ?? '').trim().isNotEmpty) chips.add(expense.vendor!.trim());
    if ((expense.receiptNo ?? '').trim().isNotEmpty) chips.add('#${expense.receiptNo!.trim()}');
    if (expense.isRefund) chips.add('Refund');

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
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                Text(
                  '-₱${_formatMoney(expense.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.error,
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
                for (final c in chips)
                  Text(
                    c,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if ((expense.referenceSaleId ?? '').trim().isNotEmpty)
                  Text(
                    'Sale: #${expense.referenceSaleId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if ((expense.notes ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                expense.notes!.trim(),
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

List<MapEntry<String, double>> _groupByCategory(List<Expense> items) {
  final map = <String, double>{};
  for (final e in items) {
    final key = e.category.trim().isEmpty ? 'Uncategorized' : e.category.trim();
    map[key] = (map[key] ?? 0) + e.amount;
  }
  final out = map.entries.toList(growable: false);
  out.sort((a, b) => b.value.compareTo(a.value));
  return out;
}

List<MapEntry<String, double>> _groupByPaymentMethod(List<Expense> items) {
  final map = <String, double>{};
  for (final e in items) {
    final key = (e.paymentMethod ?? '').trim().isEmpty ? 'Unspecified' : e.paymentMethod!.trim();
    map[key] = (map[key] ?? 0) + e.amount;
  }
  final out = map.entries.toList(growable: false);
  out.sort((a, b) => b.value.compareTo(a.value));
  return out;
}
