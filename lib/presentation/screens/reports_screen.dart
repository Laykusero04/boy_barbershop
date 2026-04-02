import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/expenses_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late String _day;

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                      Tab(text: 'Daily'),
                      Tab(text: 'Weekly'),
                      Tab(text: 'Monthly'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _DailyReportTab(
                    initialDay: _day,
                    onDayChanged: (v) => setState(() => _day = v),
                  ),
                  _WeeklyReportTab(
                    initialDay: _day,
                    onAnyDayChanged: (v) => setState(() => _day = v),
                  ),
                  _MonthlyReportTab(
                    initialDay: _day,
                    onAnyDayChanged: (v) => setState(() => _day = v),
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

class _DailyReportTab extends StatefulWidget {
  const _DailyReportTab({
    required this.initialDay,
    required this.onDayChanged,
  });

  final String initialDay;
  final ValueChanged<String> onDayChanged;

  @override
  State<_DailyReportTab> createState() => _DailyReportTabState();
}

class _DailyReportTabState extends State<_DailyReportTab> {
  late final SalesRepository _sales;
  late final ExpensesRepository _expenses;
  late final CashflowRepository _cashflow;
  bool _depsInit = false;

  late String _day;
  late String _viewDay;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    _viewDay = _day;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInit) {
      _depsInit = true;
      _sales = context.read<SalesRepository>();
      _expenses = context.read<ExpensesRepository>();
      _cashflow = context.read<CashflowRepository>();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Text('Daily report', style: theme.textTheme.titleMedium),
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
        StreamBuilder<List<Sale>>(
          stream: _sales.watchSalesForDay(_viewDay, limit: 2000),
          builder: (context, salesSnap) {
            if (salesSnap.hasError) {
              return _ErrorCard(title: 'Could not load sales', error: salesSnap.error);
            }
            final sales = salesSnap.data ?? const <Sale>[];
            return StreamBuilder<List<Expense>>(
              stream: _expenses.watchExpensesForDay(_viewDay, limit: 2000),
              builder: (context, expSnap) {
                if (expSnap.hasError) {
                  return _ErrorCard(title: 'Could not load expenses', error: expSnap.error);
                }
                final expenses = expSnap.data ?? const <Expense>[];
                return StreamBuilder<List<CashflowEntry>>(
                  stream: _cashflow.watchEntriesForDay(_viewDay, limit: 3000),
                  builder: (context, cashSnap) {
                    if (cashSnap.hasError) {
                      return _ErrorCard(title: 'Could not load cashflow', error: cashSnap.error);
                    }
                    final cash = cashSnap.data ?? const <CashflowEntry>[];
                    if ((salesSnap.connectionState == ConnectionState.waiting ||
                            expSnap.connectionState == ConnectionState.waiting ||
                            cashSnap.connectionState == ConnectionState.waiting) &&
                        sales.isEmpty &&
                        expenses.isEmpty &&
                        cash.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final salesTotal = sales.fold<double>(0, (s, e) => s + e.price);
                    final salesByPm = _groupMoneyBy(
                      sales.map((s) => MapEntry(_pmKey(s.paymentMethod), s.price)),
                    );

                    final expensesTotal = expenses.fold<double>(0, (s, e) => s + e.amount);
                    final expensesByCat = _groupMoneyBy(
                      expenses.map((e) => MapEntry(_catKey(e.category), e.amount)),
                    );

                    final cashTotals = _cashTotals(cash);
                    final openingCash = _openingCash(cash);
                    final expectedClose = openingCash + cashTotals.net;

                    final ownerDeposits = cash
                        .where((e) => e.type == CashflowType.cashIn && _isOwnerDeposit(e.category))
                        .fold<double>(0, (s, e) => s + e.amount);
                    final ownerWithdrawals = cash
                        .where((e) => e.type == CashflowType.cashOut && _isOwnerWithdrawal(e.category))
                        .fold<double>(0, (s, e) => s + e.amount);

                    return Column(
                      children: [
                        _SectionCard(
                          title: 'Sales',
                          rows: [
                            _RowKV('Total sales', salesTotal, bold: true),
                            ..._rowsFromMap(salesByPm, labelPrefix: 'Payment'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Expenses',
                          rows: [
                            _RowKV('Total expenses', expensesTotal, bold: true),
                            ..._rowsFromMap(expensesByCat, labelPrefix: 'Category'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _SectionCard(
                          title: 'Cashflow (drawer / ledger)',
                          rows: [
                            _RowKV('Opening cash', openingCash),
                            _RowKV('Cash-in total', cashTotals.cashIn),
                            _RowKV('Cash-out total', cashTotals.cashOut),
                            _RowKV('Expected closing cash', expectedClose, bold: true),
                            _RowKV('Owner deposits', ownerDeposits),
                            _RowKV('Owner withdrawals', ownerWithdrawals),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _WeeklyReportTab extends StatefulWidget {
  const _WeeklyReportTab({
    required this.initialDay,
    required this.onAnyDayChanged,
  });

  final String initialDay;
  final ValueChanged<String> onAnyDayChanged;

  @override
  State<_WeeklyReportTab> createState() => _WeeklyReportTabState();
}

class _WeeklyReportTabState extends State<_WeeklyReportTab> {
  late final SalesRepository _sales;
  late final ExpensesRepository _expenses;
  late final CashflowRepository _cashflow;
  bool _depsInit = false;

  late String _day;
  late String _viewDay;
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    _viewDay = _day;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInit) {
      _depsInit = true;
      _sales = context.read<SalesRepository>();
      _expenses = context.read<ExpensesRepository>();
      _cashflow = context.read<CashflowRepository>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _weekRange(_viewDay);
    final days = _daysBetweenInclusive(range.start, range.end);
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
                Text('Weekly report', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Week: ${range.start} to ${range.end}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Pick any day in the week',
                        value: _day,
                        onPick: () async {
                          final picked = await _pickDay(context, initial: _day);
                          if (picked == null) return;
                          setState(() => _day = picked);
                          widget.onAnyDayChanged(picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        _viewDay = _day;
                        _reload++;
                      }),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<_ReportData>(
          key: ValueKey('weekly:${range.start}:${range.end}:$_reload'),
          future: _fetchReportData(
            days: days,
            sales: _sales,
            expenses: _expenses,
            cashflow: _cashflow,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(title: 'Could not load report', error: snap.error);
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;

            final salesTotal = data.sales.fold<double>(0, (s, e) => s + e.price);
            final expensesTotal = data.expenses.fold<double>(0, (s, e) => s + e.amount);
            final net = salesTotal - expensesTotal;

            final salesByPm = _groupMoneyBy(
              data.sales.map((s) => MapEntry(_pmKey(s.paymentMethod), s.price)),
            );
            final expensesByCat = _groupMoneyBy(
              data.expenses.map((e) => MapEntry(_catKey(e.category), e.amount)),
            );
            final ownerDeposits = data.cashflow
                .where((e) => e.type == CashflowType.cashIn && _isOwnerDeposit(e.category))
                .fold<double>(0, (s, e) => s + e.amount);
            final ownerWithdrawals = data.cashflow
                .where((e) => e.type == CashflowType.cashOut && _isOwnerWithdrawal(e.category))
                .fold<double>(0, (s, e) => s + e.amount);

            return Column(
              children: [
                _SectionCard(
                  title: 'Totals',
                  rows: [
                    _RowKV('Sales', salesTotal),
                    _RowKV('Expenses', expensesTotal),
                    _RowKV('Net (Sales − Expenses)', net, bold: true),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Sales by payment method',
                  rows: _rowsFromMap(salesByPm, labelPrefix: 'Payment'),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Expenses by category',
                  rows: _rowsFromMap(expensesByCat, labelPrefix: 'Category'),
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Owner transactions (from Cashflow)',
                  rows: [
                    _RowKV('Owner deposits', ownerDeposits),
                    _RowKV('Owner withdrawals', ownerWithdrawals),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MonthlyReportTab extends StatefulWidget {
  const _MonthlyReportTab({
    required this.initialDay,
    required this.onAnyDayChanged,
  });

  final String initialDay;
  final ValueChanged<String> onAnyDayChanged;

  @override
  State<_MonthlyReportTab> createState() => _MonthlyReportTabState();
}

class _MonthlyReportTabState extends State<_MonthlyReportTab> {
  late final SalesRepository _sales;
  late final ExpensesRepository _expenses;
  late final CashflowRepository _cashflow;
  bool _depsInit = false;

  late String _day;
  late String _viewDay;
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDay;
    _viewDay = _day;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInit) {
      _depsInit = true;
      _sales = context.read<SalesRepository>();
      _expenses = context.read<ExpensesRepository>();
      _cashflow = context.read<CashflowRepository>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = _monthRange(_viewDay);
    final days = _daysBetweenInclusive(range.start, range.end);
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
                Text('Monthly report', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Month: ${range.start.substring(0, 7)}  (${range.start} to ${range.end})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Pick any day in the month',
                        value: _day,
                        onPick: () async {
                          final picked = await _pickDay(context, initial: _day);
                          if (picked == null) return;
                          setState(() => _day = picked);
                          widget.onAnyDayChanged(picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        _viewDay = _day;
                        _reload++;
                      }),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<_ReportData>(
          key: ValueKey('monthly:${range.start}:${range.end}:$_reload'),
          future: _fetchReportData(
            days: days,
            sales: _sales,
            expenses: _expenses,
            cashflow: _cashflow,
          ),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorCard(title: 'Could not load report', error: snap.error);
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;

            final salesTotal = data.sales.fold<double>(0, (s, e) => s + e.price);
            final discountsTotal =
                data.sales.fold<double>(0, (s, e) => s + (e.discountAmount ?? 0));
            final expensesTotal = data.expenses.fold<double>(0, (s, e) => s + e.amount);
            final net = salesTotal - expensesTotal;

            final ownerDeposits = data.cashflow
                .where((e) => e.type == CashflowType.cashIn && _isOwnerDeposit(e.category))
                .fold<double>(0, (s, e) => s + e.amount);
            final ownerWithdrawals = data.cashflow
                .where((e) => e.type == CashflowType.cashOut && _isOwnerWithdrawal(e.category))
                .fold<double>(0, (s, e) => s + e.amount);

            return Column(
              children: [
                _SectionCard(
                  title: 'Totals',
                  rows: [
                    _RowKV('Sales', salesTotal),
                    _RowKV('Discounts', discountsTotal),
                    _RowKV('Expenses', expensesTotal),
                    _RowKV('Net profit estimate', net, bold: true),
                  ],
                ),
                const SizedBox(height: 12),
                _SectionCard(
                  title: 'Owner transactions (from Cashflow)',
                  rows: [
                    _RowKV('Owner deposits', ownerDeposits),
                    _RowKV('Owner withdrawals', ownerWithdrawals),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReportData {
  const _ReportData({
    required this.sales,
    required this.expenses,
    required this.cashflow,
  });
  final List<Sale> sales;
  final List<Expense> expenses;
  final List<CashflowEntry> cashflow;
}

Future<_ReportData> _fetchReportData({
  required List<String> days,
  required SalesRepository sales,
  required ExpensesRepository expenses,
  required CashflowRepository cashflow,
}) async {
  final results = await Future.wait([
    sales.fetchSalesForDays(days),
    expenses.fetchExpensesForDays(days),
    cashflow.fetchEntriesForDays(days),
  ]);
  return _ReportData(
    sales: results[0] as List<Sale>,
    expenses: results[1] as List<Expense>,
    cashflow: results[2] as List<CashflowEntry>,
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});

  final String title;
  final List<_RowKV> rows;

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
            const SizedBox(height: 12),
            for (final r in rows) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    '₱${_formatMoney(r.value)}',
                    style: (r.bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                        ?.copyWith(fontWeight: r.bold ? FontWeight.w900 : null),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowKV {
  const _RowKV(this.label, this.value, {this.bold = false});
  final String label;
  final double value;
  final bool bold;
}

class _Range {
  const _Range({required this.start, required this.end});
  final String start;
  final String end;
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

_Range _weekRange(String anyDay) {
  final d = parseYyyyMmDd(anyDay) ?? nowManila();
  final dayOnly = DateTime(d.year, d.month, d.day);
  // Monday=1 ... Sunday=7
  final diffFromMonday = dayOnly.weekday - DateTime.monday;
  final start = dayOnly.subtract(Duration(days: diffFromMonday));
  final end = start.add(const Duration(days: 6));
  return _Range(start: yyyyMmDd(start), end: yyyyMmDd(end));
}

_Range _monthRange(String anyDay) {
  final d = parseYyyyMmDd(anyDay) ?? nowManila();
  final start = DateTime(d.year, d.month, 1);
  final nextMonth = (d.month == 12) ? DateTime(d.year + 1, 1, 1) : DateTime(d.year, d.month + 1, 1);
  final end = nextMonth.subtract(const Duration(days: 1));
  return _Range(start: yyyyMmDd(start), end: yyyyMmDd(end));
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

String _pmKey(String? raw) {
  final s = (raw ?? '').trim();
  return s.isEmpty ? 'Unspecified' : s;
}

String _catKey(String raw) {
  final s = raw.trim();
  return s.isEmpty ? 'Uncategorized' : s;
}

Map<String, double> _groupMoneyBy(Iterable<MapEntry<String, double>> rows) {
  final map = <String, double>{};
  for (final r in rows) {
    map[r.key] = (map[r.key] ?? 0) + r.value;
  }
  return map;
}

List<_RowKV> _rowsFromMap(
  Map<String, double> map, {
  required String labelPrefix,
}) {
  final entries = map.entries.toList(growable: false);
  entries.sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries) _RowKV('$labelPrefix: ${e.key}', e.value),
  ];
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

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}
