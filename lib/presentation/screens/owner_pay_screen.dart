import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/expenses_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/data/settings_repository.dart';
import 'package:boy_barbershop/presentation/screens/dashboard/dashboard_logic.dart';
import 'package:boy_barbershop/presentation/screens/owner_pay_insights_math.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/cashflow_entry.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class OwnerPayScreen extends StatefulWidget {
  const OwnerPayScreen({
    super.key,
    required this.user,
    this.onNavigateToDestination,
  });

  final AppUser user;
  final void Function(String destinationId)? onNavigateToDestination;

  @override
  State<OwnerPayScreen> createState() => _OwnerPayScreenState();
}

class _OwnerPayScreenState extends State<OwnerPayScreen> {
  /// Fixed amount left in the drawer when suggesting max withdrawal (no settings UI).
  static const _drawerReservePesos = 2000.0;
  static const _matchTolerance = 0.01; // pesos
  static const _insightOwnerPayPctKey = 'insight_owner_pay_percent';
  static const _insightTargetYearsKey = 'insight_target_years';

  late final SettingsRepository _settings;
  late final CashflowRepository _cashflow;
  late final SalesRepository _sales;
  late final ExpensesRepository _expenses;
  late final BarbersRepository _barbers;
  bool _depsInit = false;

  late String _day;
  late String _viewDay;

  late String _weekAnyDay;
  late String _weekViewDay;

  final _actualCashController = TextEditingController();
  final _insightPayPctController = TextEditingController();
  final _insightYearsController = TextEditingController();

  Future<_ProfitInsightBundle>? _profitInsightsFuture;
  Future<_WeekData>? _weekDataFuture;

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
    _viewDay = _day;
    _weekAnyDay = _day;
    _weekViewDay = _weekAnyDay;
    WidgetsBinding.instance.addPostFrameCallback((_) => _primeInsightFieldDefaults());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInit) {
      _depsInit = true;
      _settings = context.read<SettingsRepository>();
      _cashflow = context.read<CashflowRepository>();
      _sales = context.read<SalesRepository>();
      _expenses = context.read<ExpensesRepository>();
      _barbers = context.read<BarbersRepository>();
      _profitInsightsFuture ??= _loadProfitInsightBundle();
      _weekDataFuture ??= _fetchWeekData(_weekViewDay);
    }
  }

  @override
  void dispose() {
    _actualCashController.dispose();
    _insightPayPctController.dispose();
    _insightYearsController.dispose();
    super.dispose();
  }

  Future<void> _primeInsightFieldDefaults() async {
    if (!mounted) return;
    final p = await _settings.fetchDouble(_insightOwnerPayPctKey, defaultValue: 70);
    final y = await _settings.fetchDouble(_insightTargetYearsKey, defaultValue: 0);
    if (!mounted) return;
    if (_insightPayPctController.text.trim().isEmpty) {
      _insightPayPctController.text = p.clamp(0, 100).toStringAsFixed(0);
    }
    if (_insightYearsController.text.trim().isEmpty) {
      _insightYearsController.text = y == 0 ? '0' : y.toStringAsFixed(0);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.account_balance_wallet_outlined, color: scheme.onPrimaryContainer, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drawer & weekly profit',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Daily: safe owner withdrawal from counted cash. Weekly: sales vs expenses snapshot (not the same as cash on hand).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'How owner pay works',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => _showOwnerPayHelpDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'Profit-based insights'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Uses the last ~12 months of sales & expenses (Manila dates), barber shares, and owner deposits recorded in Cash flow. Matches the old PHP owner_insights logic without Cloud Functions.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          FutureBuilder<_ProfitInsightBundle>(
            future: _profitInsightsFuture,
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorCard(title: 'Could not load profit insights', error: snap.error);
              }
              if (_profitInsightsFuture == null ||
                  (snap.connectionState == ConnectionState.waiting && !snap.hasData)) {
                return _InlineSectionLoader(
                  scheme: scheme,
                  message: 'Loading profit insights…',
                );
              }
              if (!snap.hasData) {
                return _InlineSectionLoader(scheme: scheme, message: 'Loading profit insights…');
              }
              final b = snap.data!;
              final ownerFrac = b.ownerPayPercent / 100.0;
              final suggMonthly = b.avgMonthlyNet * ownerFrac;
              final suggDaily = suggMonthly / 30.0;
              final bizFrac = (100.0 - b.ownerPayPercent) / 100.0;
              final bizMonthly = b.avgMonthlyNet * bizFrac;
              final bizDaily = bizMonthly / 30.0;
              final roiPct = b.totalOwnerDeposits > 0
                  ? (b.trailingNetProfit / b.totalOwnerDeposits) * 100.0
                  : null;
              final paybackMonths =
                  b.avgMonthlyNet > 0 && b.totalOwnerDeposits > 0
                      ? b.totalOwnerDeposits / b.avgMonthlyNet
                      : null;
              double? reqProfitMonth;
              double? reqSalesMonth;
              if (b.targetYears >= 1 && b.totalOwnerDeposits > 0) {
                reqProfitMonth = b.totalOwnerDeposits / (b.targetYears * 12);
                reqSalesMonth = requiredMonthlySalesForTarget(
                  requiredMonthlyNetProfit: reqProfitMonth,
                  avgMonthlyNet: b.avgMonthlyNet,
                  avgMonthlySales: b.avgMonthlySales,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.savings_outlined, color: scheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Capital you put in',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Total owner deposits (same as the Investments screen).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Total owner deposits',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '₱${_formatMoney(b.totalOwnerDeposits)}',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: widget.onNavigateToDestination == null
                                ? null
                                : () => widget.onNavigateToDestination!.call('investments'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add or view investments'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.account_balance_outlined, color: scheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Save for the business',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'After barber share and expenses, this is the slice to keep as business money using your owner-pay % setting.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Business savings (from avg monthly profit)',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    '₱${_formatMoney(bizMonthly)} / mo',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(100 - b.ownerPayPercent).toStringAsFixed(0)}% of average monthly net × ₱${_formatMoney(b.avgMonthlyNet)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _insightMiniMetric(
                                  theme,
                                  scheme,
                                  'Per day (guide)',
                                  '₱${_formatMoney(bizDaily)}',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _insightMiniMetric(
                                  theme,
                                  scheme,
                                  'Per month',
                                  '₱${_formatMoney(bizMonthly)}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Basis: ${b.ownerPayPercent.toStringAsFixed(0)}% suggested for owner pay → ${(100 - b.ownerPayPercent).toStringAsFixed(0)}% for the business. Averages use months that had sales or expenses in the window.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payments_outlined, color: scheme.secondary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Suggested owner pay',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'From average monthly net profit × your owner pay % (same as PHP index / owner_insights).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Monthly',
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: scheme.onSecondaryContainer,
                                          ),
                                        ),
                                        Text(
                                          '₱${_formatMoney(suggMonthly)}',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: scheme.onSecondaryContainer,
                                          ),
                                        ),
                                        Text(
                                          '${b.ownerPayPercent.toStringAsFixed(0)}% × avg net',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onSecondaryContainer.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.primaryContainer.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Daily (÷30)',
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Text(
                                          '₱${_formatMoney(suggDaily)}',
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        ),
                                        Text(
                                          'Planning guide only',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.trending_up_outlined, color: scheme.tertiary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Recover investment',
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (b.totalOwnerDeposits <= 0 && b.monthlyRows.isEmpty)
                            Text(
                              'Add owner deposits under Investments and build sales history to see ROI and payback here.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            )
                          else ...[
                            Text(
                              'Trailing net profit (same window): ₱${_formatMoney(b.trailingNetProfit)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            if (roiPct != null)
                              Text(
                                'ROI vs deposits: ${roiPct.toStringAsFixed(1)}%',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            if (paybackMonths != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Payback at avg pace: ~${_formatPaybackMonths(paybackMonths)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              'ROI uses net profit for the loaded window; deposits are all-time owner deposits from Cash flow.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.3,
                              ),
                            ),
                          ],
                          if (b.targetYears >= 1 && reqProfitMonth != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Payback goal (${b.targetYears.toStringAsFixed(0)} yr)',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Need ~₱${_formatMoney(reqProfitMonth)} net profit / month to recover ₱${_formatMoney(b.totalOwnerDeposits)} in that time.',
                              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                            ),
                            if (reqSalesMonth != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Implied sales at your margin: ~₱${_formatMoney(reqSalesMonth)} / month (rough guide).',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.tune_rounded, color: scheme.primary),
                              const SizedBox(width: 10),
                              Text('Customize', style: theme.textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Saved in Firestore settings (insight_owner_pay_percent, insight_target_years). Reloads the numbers above.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _insightPayPctController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Owner pay suggestion',
                              suffixText: '% of avg monthly net',
                              hintText: '70',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _insightYearsController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Goal: recover investment in',
                              suffixText: 'years (0 = hide)',
                              hintText: '0',
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => _saveInsightSettings(context),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Save'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Daily — cash drawer'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Owner pay from drawer', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Count the drawer, enter actual cash, and reconcile. If it matches expected closing, you can record a withdrawal up to the suggested limit.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'Day to load',
                    value: _day,
                    onPick: () async {
                      final picked = await _pickDay(context, initial: _day);
                      if (picked == null) return;
                      setState(() => _day = picked);
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => setState(() => _viewDay = _day),
                      child: const Text('Load this day'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing drawer math for: $_viewDay',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
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
            stream: _cashflow.watchEntriesForDay(_viewDay, limit: 2000),
            builder: (context, cashSnap) {
              if (cashSnap.hasError) {
                return _ErrorCard(title: 'Could not load cashflow', error: cashSnap.error);
              }
              final cash = cashSnap.data ?? const <CashflowEntry>[];
              if (cashSnap.connectionState == ConnectionState.waiting && cash.isEmpty) {
                return _InlineSectionLoader(
                  scheme: scheme,
                  message: 'Loading drawer for $_viewDay…',
                );
              }

              const buffer = _drawerReservePesos;
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Drawer summary',
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
                              const SizedBox(height: 14),
                              _kv(theme, 'Opening cash', opening),
                              _kv(theme, 'Cash-in total', totals.cashIn),
                              _kv(theme, 'Cash-out total', totals.cashOut),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Divider(
                                  height: 1,
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                ),
                              ),
                              _kv(theme, 'Expected closing cash', expectedClose, bold: true),
                              _kv(theme, 'Owner withdrawals (already recorded)', ownerWithdrawals),
                              const SizedBox(height: 14),
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
                              if (diff != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  reconciled ? 'Reconciled' : 'Not reconciled',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: reconciled ? scheme.secondary : scheme.error,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Difference vs expected: ₱${_formatMoney(diff)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),
                              if (maxWithdraw != null)
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: scheme.secondaryContainer.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        Icon(Icons.payments_outlined, color: scheme.onSecondaryContainer),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Suggested max withdrawal',
                                                style: theme.textTheme.labelLarge?.copyWith(
                                                  color: scheme.onSecondaryContainer,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                '₱${_formatMoney(maxWithdraw)}',
                                                style: theme.textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: scheme.onSecondaryContainer,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Assumes ₱${_formatMoney(buffer)} stays in the drawer for change.',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: scheme.onSecondaryContainer.withValues(alpha: 0.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'Enter actual cash count. When it matches expected closing, you will see a safe withdrawal limit.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
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
          ),
          const SizedBox(height: 20),
          _sectionLabel(context, 'Weekly — profit snapshot'),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sales vs expenses (Mon–Sun)', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Totals for the Manila week that contains the day you pick. This is a profit-style estimate, not your physical cash balance.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'Any day in the week',
                    value: _weekAnyDay,
                    onPick: () async {
                      final picked = await _pickDay(context, initial: _weekAnyDay);
                      if (picked == null) return;
                      setState(() => _weekAnyDay = picked);
                    },
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => setState(() {
                        _weekViewDay = _weekAnyDay;
                        _weekDataFuture = _fetchWeekData(_weekViewDay);
                      }),
                      child: const Text('Load this week'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.date_range_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_weekRange(_weekViewDay).start} → ${_weekRange(_weekViewDay).end}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_WeekData>(
            future: _weekDataFuture,
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorCard(title: 'Could not load weekly insights', error: snap.error);
              }
              if (_weekDataFuture == null ||
                  (snap.connectionState == ConnectionState.waiting && !snap.hasData)) {
                return _InlineSectionLoader(
                  scheme: scheme,
                  message: 'Loading week ${_weekRange(_weekViewDay).start} → ${_weekRange(_weekViewDay).end}…',
                );
              }
              if (!snap.hasData) {
                return _InlineSectionLoader(scheme: scheme, message: 'Loading week…');
              }
              final data = snap.data!;
              final salesTotal = data.sales.fold<double>(0, (s, e) => s + e.price);
              final expensesTotal = data.expenses.fold<double>(0, (s, e) => s + e.amount);
              final profit = salesTotal - expensesTotal;
              final profitColor = profit >= 0 ? scheme.secondary : scheme.error;

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: scheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Week at a glance', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 14),
                      _kv(theme, 'Sales', salesTotal),
                      _kv(theme, 'Expenses', expensesTotal),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(
                          height: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      _kv(
                        theme,
                        'Profit estimate (sales − expenses)',
                        profit,
                        bold: true,
                        valueColor: profitColor,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Owner movement (from Cash flow)',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _kv(theme, 'Deposits', ownerDeposits),
                      _kv(theme, 'Withdrawals', ownerWithdrawals),
                      _kv(theme, 'Net (deposits − withdrawals)', ownerDeposits - ownerWithdrawals, bold: true),
                      const SizedBox(height: 12),
                      Text(
                        'Over/short adjustment entries this week: $overShortCount',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.35,
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

  Future<_ProfitInsightBundle> _loadProfitInsightBundle() async {
    final endDay = todayManilaDay();
    final endParsed = parseYyyyMmDd(endDay) ?? nowManila();
    final startParsed = DateTime(endParsed.year, endParsed.month, endParsed.day)
        .subtract(const Duration(days: 364));
    final startDay = yyyyMmDd(startParsed);
    final days = _daysBetweenInclusive(startDay, endDay);
    final sales = await _sales.fetchSalesForDaysSafe(days);
    final expenses = await _expenses.fetchExpensesForDays(days);
    final barbers = await _barbers.watchAllBarbers().first;
    final barberById = mapBarbersById(barbers);
    final rows = buildMonthlyProfitRows(
      sales: sales,
      expenses: expenses,
      barberById: barberById,
    );
    final deposits = await _cashflow.sumOwnerDepositsSinceDay('2020-01-01');
    final ownerPayPct =
        (await _settings.fetchDouble(_insightOwnerPayPctKey, defaultValue: 70)).clamp(0.0, 100.0);
    final targetYears =
        (await _settings.fetchDouble(_insightTargetYearsKey, defaultValue: 0)).clamp(0.0, 100.0);
    return _ProfitInsightBundle(
      monthlyRows: rows,
      avgMonthlyNet: averageMonthlyNet(rows),
      avgMonthlySales: averageMonthlySales(rows),
      trailingNetProfit: sumMonthlyNet(rows),
      totalOwnerDeposits: deposits,
      ownerPayPercent: ownerPayPct,
      targetYears: targetYears,
    );
  }

  Future<void> _saveInsightSettings(BuildContext context) async {
    final pctParsed = double.tryParse(_insightPayPctController.text.trim());
    final yearsParsed = double.tryParse(_insightYearsController.text.trim());
    if (pctParsed == null || pctParsed < 0 || pctParsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Owner pay % must be between 0 and 100.')),
      );
      return;
    }
    if (yearsParsed == null || yearsParsed < 0 || yearsParsed > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target years must be between 0 and 80.')),
      );
      return;
    }
    try {
      await _settings.setDouble(_insightOwnerPayPctKey, pctParsed);
      await _settings.setDouble(_insightTargetYearsKey, yearsParsed);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insight settings saved.')),
      );
      _profitInsightsFuture = _loadProfitInsightBundle();
      setState(() {});
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

class _ProfitInsightBundle {
  const _ProfitInsightBundle({
    required this.monthlyRows,
    required this.avgMonthlyNet,
    required this.avgMonthlySales,
    required this.trailingNetProfit,
    required this.totalOwnerDeposits,
    required this.ownerPayPercent,
    required this.targetYears,
  });

  final List<MonthlyProfitRow> monthlyRows;
  final double avgMonthlyNet;
  final double avgMonthlySales;
  final double trailingNetProfit;
  final double totalOwnerDeposits;
  final double ownerPayPercent;
  final double targetYears;
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

class _InlineSectionLoader extends StatelessWidget {
  const _InlineSectionLoader({
    required this.scheme,
    required this.message,
  });

  final ColorScheme scheme;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _insightMiniMetric(ThemeData theme, ColorScheme scheme, String label, String value) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

String _formatPaybackMonths(double months) {
  if (months.isNaN || months.isInfinite || months <= 0) return '—';
  final y = (months / 12).floor();
  final m = (months % 12).round();
  if (y <= 0) return '$m mo';
  return '${y}y ${m}mo';
}

Widget _sectionLabel(BuildContext context, String text) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
    child: Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

Widget _kv(
  ThemeData theme,
  String label,
  double value, {
  bool bold = false,
  Color? valueColor,
}) {
  final base = bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium;
  final style = valueColor != null
      ? base?.copyWith(fontWeight: bold ? FontWeight.w900 : null, color: valueColor)
      : base?.copyWith(fontWeight: bold ? FontWeight.w900 : null);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

void _showOwnerPayHelpDialog(BuildContext context) {
  final theme = Theme.of(context);
  final muted = theme.colorScheme.onSurfaceVariant;
  final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.45);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('About Owner pay & insights'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This screen combines two different ideas: paying yourself from the physical drawer (daily) and reading a weekly profit-style summary.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),
              Text('Drawer reserve', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Max withdrawal suggestions assume ₱2000 stays in the drawer for change, after your counted cash matches expected closing.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Daily — drawer', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Uses Cash flow for the selected day (opening, cash in/out, expected closing). Enter your actual count to reconcile; then you can record an owner withdrawal up to the suggested limit.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Weekly — profit snapshot', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Picks the Monday–Sunday week in Manila that contains the date you choose. Sales minus expenses is an estimate of profit for the week—not the same as how much cash is in the drawer.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Profit-based insights', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Uses ~12 months of data: monthly net = sales − barber share − expenses, then averages. Suggested owner pay and business savings follow your % and match the old PHP owner_insights formulas. Owner deposits are summed from Cash flow.',
                style: bodyStyle?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
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
