import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/expenses_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/data/settings_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class OwnerPayScreen extends StatefulWidget {
  const OwnerPayScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<OwnerPayScreen> createState() => _OwnerPayScreenState();
}

class _OwnerPayScreenState extends State<OwnerPayScreen> {
  static const _bufferKey = 'minimum_cash_buffer';
  static const _defaultBuffer = 2000.0;
  static const _matchTolerance = 0.01; // pesos

  final _settings = SettingsRepository();
  final _cashflow = CashflowRepository();
  final _sales = SalesRepository();
  final _expenses = ExpensesRepository();

  late String _day;
  late String _viewDay;

  late String _weekAnyDay;
  late String _weekViewDay;
  int _weekReload = 0;

  final _actualCashController = TextEditingController();
  final _bufferController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
    _viewDay = _day;
    _weekAnyDay = _day;
    _weekViewDay = _weekAnyDay;
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _bufferController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Owner pay & insights', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          StreamBuilder<double>(
            stream: _settings.watchDouble(_bufferKey, defaultValue: _defaultBuffer),
            builder: (context, snap) {
              final buffer = (snap.data ?? _defaultBuffer);
              if (_bufferController.text.trim().isEmpty) {
                _bufferController.text = _formatMoney(buffer);
              }
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Minimum cash buffer', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Keep a target minimum cash in the drawer for change/operations.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bufferController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Buffer amount',
                          prefixText: '₱',
                          hintText: '2000',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _saveBuffer(context),
                          child: const Text('Save buffer'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily owner pay (cash drawer method)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Reconcile first. If actual cash matches expected cash, you can withdraw up to: actual − buffer.',
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
          StreamBuilder<double>(
            stream: _settings.watchDouble(_bufferKey, defaultValue: _defaultBuffer),
            builder: (context, bufferSnap) {
              final buffer = bufferSnap.data ?? _defaultBuffer;
              return StreamBuilder<List<CashflowEntry>>(
                stream: _cashflow.watchEntriesForDay(_viewDay, limit: 2000),
                builder: (context, cashSnap) {
                  if (cashSnap.hasError) {
                    return _ErrorCard(title: 'Could not load cashflow', error: cashSnap.error);
                  }
                  final cash = cashSnap.data ?? const <CashflowEntry>[];
                  if (cashSnap.connectionState == ConnectionState.waiting && cash.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final opening = _openingCash(cash);
                  final totals = _cashTotals(cash);
                  final expectedClose = opening + totals.net;

                  final actual = _parseMoney(_actualCashController.text);
                  final diff = (actual == null) ? null : (actual - expectedClose);
                  final reconciled = diff != null && diff.abs() <= _matchTolerance;

                  final maxWithdraw = reconciled ? math.max(0.0, actual! - buffer) : null;

                  final ownerWithdrawals = cash
                      .where((e) => e.type == CashflowType.cashOut && _isOwnerWithdrawal(e.category))
                      .fold<double>(0, (s, e) => s + e.amount);

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
                                    child: Text(
                                      'Daily summary',
                                      style: theme.textTheme.titleMedium,
                                    ),
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
                              _kv(theme, 'Opening cash', opening),
                              _kv(theme, 'Cash-in total', totals.cashIn),
                              _kv(theme, 'Cash-out total', totals.cashOut),
                              const Divider(height: 20),
                              _kv(theme, 'Expected closing cash', expectedClose, bold: true),
                              _kv(theme, 'Buffer', buffer),
                              _kv(theme, 'Owner withdrawals (recorded)', ownerWithdrawals),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _actualCashController,
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
                                    color: reconciled
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.error,
                                  ),
                                ),
                              const SizedBox(height: 10),
                              if (maxWithdraw != null)
                                Text(
                                  'Max withdrawal today: ₱${_formatMoney(maxWithdraw)}',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                )
                              else
                                Text(
                                  'Tip: Enter actual cash and reconcile first to get a safe withdrawal limit.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed: maxWithdraw == null
                                      ? null
                                      : () => _recordOwnerWithdrawal(
                                            context,
                                            day: _viewDay,
                                            suggestedAmount: maxWithdraw,
                                          ),
                                  child: const Text('Record owner withdrawal'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly owner pay (profit estimate method)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Profit estimate = Sales − Expenses. Use this as a guide, not a guarantee of cash on hand.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Pick any day in week',
                          value: _weekAnyDay,
                          onPick: () async {
                            final picked = await _pickDay(context, initial: _weekAnyDay);
                            if (picked == null) return;
                            setState(() => _weekAnyDay = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => setState(() {
                          _weekViewDay = _weekAnyDay;
                          _weekReload++;
                        }),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Week: ${_weekRange(_weekViewDay).start} to ${_weekRange(_weekViewDay).end}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_WeekData>(
            key: ValueKey('week:$_weekViewDay:$_weekReload'),
            future: _fetchWeekData(_weekViewDay),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorCard(title: 'Could not load weekly insights', error: snap.error);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data!;
              final salesTotal = data.sales.fold<double>(0, (s, e) => s + e.price);
              final expensesTotal = data.expenses.fold<double>(0, (s, e) => s + e.amount);
              final profit = salesTotal - expensesTotal;

              final ownerDeposits = data.cashflow
                  .where((e) => e.type == CashflowType.cashIn && _isOwnerDeposit(e.category))
                  .fold<double>(0, (s, e) => s + e.amount);
              final ownerWithdrawals = data.cashflow
                  .where((e) => e.type == CashflowType.cashOut && _isOwnerWithdrawal(e.category))
                  .fold<double>(0, (s, e) => s + e.amount);
              final overShortCount = data.cashflow
                  .where((e) => e.category.toLowerCase().contains('over/short'))
                  .length;

              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly summary', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _kv(theme, 'Sales', salesTotal),
                      _kv(theme, 'Expenses', expensesTotal),
                      _kv(theme, 'Profit estimate (Sales − Expenses)', profit, bold: true),
                      const Divider(height: 20),
                      _kv(theme, 'Owner deposits', ownerDeposits),
                      _kv(theme, 'Owner withdrawals', ownerWithdrawals),
                      _kv(theme, 'Net owner movement', ownerDeposits - ownerWithdrawals, bold: true),
                      const SizedBox(height: 8),
                      Text(
                        'Over/short adjustments this week: $overShortCount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveBuffer(BuildContext context) async {
    final parsed = _parseMoney(_bufferController.text);
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid buffer amount (0 or more).')),
      );
      return;
    }
    try {
      await _settings.setDouble(_bufferKey, parsed);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Buffer saved.')),
      );
    } on SettingsWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _recordOwnerWithdrawal(
    BuildContext context, {
    required String day,
    required double suggestedAmount,
  }) async {
    final result = await showDialog<_OwnerWithdrawalResult>(
      context: context,
      builder: (context) => _OwnerWithdrawalDialog(
        day: day,
        suggestedAmount: suggestedAmount,
      ),
    );
    if (!context.mounted || result == null) return;

    try {
      await _cashflow.createEntry(
        occurredAtUtc: result.occurredAtUtc,
        occurredDayManila: result.dayManila,
        type: CashflowType.cashOut,
        category: 'Owner withdrawal',
        amount: result.amount,
        paymentMethod: result.paymentMethod,
        referenceSaleId: null,
        referenceExpenseId: null,
        notes: result.notes,
        createdByUid: widget.user.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner withdrawal saved.')),
      );
      setState(() {
        _day = result.dayManila;
        _viewDay = result.dayManila;
      });
    } on CashflowWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<_WeekData> _fetchWeekData(String anyDay) async {
    final range = _weekRange(anyDay);
    final days = _daysBetweenInclusive(range.start, range.end);
    final results = await Future.wait([
      _sales.fetchSalesForDays(days),
      _expenses.fetchExpensesForDays(days),
      _cashflow.fetchEntriesForDays(days),
    ]);
    return _WeekData(
      sales: results[0] as List<Sale>,
      expenses: results[1] as List<Expense>,
      cashflow: results[2] as List<CashflowEntry>,
    );
  }
}

class _WeekData {
  const _WeekData({
    required this.sales,
    required this.expenses,
    required this.cashflow,
  });
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<CashflowEntry> cashflow;
}

class _Range {
  const _Range({required this.start, required this.end});
  final String start;
  final String end;
}

_Range _weekRange(String anyDay) {
  final d = parseYyyyMmDd(anyDay) ?? nowManila();
  final dayOnly = DateTime(d.year, d.month, d.day);
  final diffFromMonday = dayOnly.weekday - DateTime.monday;
  final start = dayOnly.subtract(Duration(days: diffFromMonday));
  final end = start.add(const Duration(days: 6));
  return _Range(start: yyyyMmDd(start), end: yyyyMmDd(end));
}

List<String> _daysBetweenInclusive(String startDay, String endDay) {
  final start = parseYyyyMmDd(startDay);
  final end = parseYyyyMmDd(endDay);
  if (start == null || end == null) return const <String>[];
  final out = <String>[];
  var cursor = DateTime(start.year, start.month, start.day);
  final last = DateTime(end.year, end.month, end.day);
  while (!cursor.isAfter(last)) {
    out.add(yyyyMmDd(cursor));
    cursor = cursor.add(const Duration(days: 1));
  }
  return out;
}

class _CashTotals {
  const _CashTotals({required this.cashIn, required this.cashOut, required this.net});
  final double cashIn;
  final double cashOut;
  final double net;
}

_CashTotals _cashTotals(List<CashflowEntry> items) {
  final cashIn = items
      .where((e) => e.type == CashflowType.cashIn)
      .fold<double>(0, (sum, e) => sum + e.amount);
  final cashOut = items
      .where((e) => e.type == CashflowType.cashOut)
      .fold<double>(0, (sum, e) => sum + e.amount);
  return _CashTotals(cashIn: cashIn, cashOut: cashOut, net: cashIn - cashOut);
}

double _openingCash(List<CashflowEntry> items) {
  final candidates = items.where((e) {
    final c = e.category.trim().toLowerCase();
    return c == 'opening cash' || c.contains('opening cash') || c.contains('float');
  });
  return candidates.fold<double>(0, (sum, e) => sum + e.signedAmount);
}

bool _isOwnerDeposit(String category) => category.trim().toLowerCase() == 'owner deposit';
bool _isOwnerWithdrawal(String category) => category.trim().toLowerCase() == 'owner withdrawal';

Widget _kv(ThemeData theme, String label, double value, {bool bold = false}) {
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

class _OwnerWithdrawalResult {
  const _OwnerWithdrawalResult({
    required this.occurredAtUtc,
    required this.dayManila,
    required this.amount,
    required this.paymentMethod,
    required this.notes,
  });

  final DateTime occurredAtUtc;
  final String dayManila;
  final double amount;
  final String? paymentMethod;
  final String? notes;
}

class _OwnerWithdrawalDialog extends StatefulWidget {
  const _OwnerWithdrawalDialog({
    required this.day,
    required this.suggestedAmount,
  });

  final String day;
  final double suggestedAmount;

  @override
  State<_OwnerWithdrawalDialog> createState() => _OwnerWithdrawalDialogState();
}

class _OwnerWithdrawalDialogState extends State<_OwnerWithdrawalDialog> {
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
    _amountController.text = _formatMoney(widget.suggestedAmount);
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
    return AlertDialog(
      title: const Text('Owner withdrawal'),
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
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
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

    Navigator.of(context).pop(
      _OwnerWithdrawalResult(
        occurredAtUtc: dtUtc,
        dayManila: dayManila,
        amount: amount,
        paymentMethod: _paymentController.text.trim().isEmpty ? null : _paymentController.text,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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

