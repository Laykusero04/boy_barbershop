import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/data/catalog_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/models/service_item.dart';
import 'package:boy_barbershop/utils/sales_intelligence.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class SalesIntelligenceScreen extends StatefulWidget {
  const SalesIntelligenceScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<SalesIntelligenceScreen> createState() => _SalesIntelligenceScreenState();
}

class _SalesIntelligenceScreenState extends State<SalesIntelligenceScreen> {
  late final SalesRepository _salesRepo;
  late final CatalogRepository _catalog;
  bool _depsInit = false;

  late String _startDay;
  late String _endDay;
  late String _viewStart;
  late String _viewEnd;

  @override
  void initState() {
    super.initState();
    final today = todayManilaDay();
    final todayParsed = parseYyyyMmDd(today) ?? DateTime.now();
    final start = todayParsed.subtract(const Duration(days: 6));
    _startDay = yyyyMmDd(start);
    _endDay = today;
    _viewStart = _startDay;
    _viewEnd = _endDay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsInit) {
      _depsInit = true;
      _salesRepo = context.read<SalesRepository>();
      _catalog = context.read<CatalogRepository>();
    }
  }

  void _applyViewRange() {
    var start = _startDay.trim();
    var end = _endDay.trim();
    if (!isValidYyyyMmDd(start) || !isValidYyyyMmDd(end)) return;
    if (start.compareTo(end) > 0) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    setState(() {
      _viewStart = start;
      _viewEnd = end;
      _startDay = start;
      _endDay = end;
    });
  }

  void _presetLastDays(int inclusiveDays) {
    final todayStr = todayManilaDay();
    final todayParsed = parseYyyyMmDd(todayStr);
    if (todayParsed == null) return;
    final start = todayParsed.subtract(Duration(days: inclusiveDays - 1));
    setState(() {
      _startDay = yyyyMmDd(start);
      _endDay = todayStr;
      _viewStart = _startDay;
      _viewEnd = _endDay;
    });
  }

  void _presetThisMonth() {
    final todayStr = todayManilaDay();
    final p = parseYyyyMmDd(todayStr);
    if (p == null) return;
    final first = DateTime(p.year, p.month, 1);
    setState(() {
      _startDay = yyyyMmDd(first);
      _endDay = todayStr;
      _viewStart = _startDay;
      _viewEnd = _endDay;
    });
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
                  child: Icon(Icons.insights_outlined, color: scheme.onPrimaryContainer, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales insights',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Totals and breakdowns from recorded sales. Dates use the shop day (Manila).',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'What is Sales Intelligence?',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: () => _showSalesIntelligenceHelpDialog(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date range', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Pick dates, then load. Quick presets apply immediately.',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Last 7 days'),
                        onPressed: () => _presetLastDays(7),
                      ),
                      ActionChip(
                        label: const Text('Last 30 days'),
                        onPressed: () => _presetLastDays(30),
                      ),
                      ActionChip(
                        label: const Text('This month'),
                        onPressed: _presetThisMonth,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'From',
                          value: _startDay,
                          onPick: () async {
                            final picked = await _pickDay(context, initial: _startDay);
                            if (picked == null) return;
                            setState(() => _startDay = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateField(
                          label: 'To',
                          value: _endDay,
                          onPick: () async {
                            final picked = await _pickDay(context, initial: _endDay);
                            if (picked == null) return;
                            setState(() => _endDay = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _applyViewRange,
                      child: const Text('Load report'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.date_range_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Active range: $_viewStart → $_viewEnd',
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
          const SizedBox(height: 8),
          StreamBuilder<List<Sale>>(
            stream: _salesRepo.watchSalesForRangeUtc(
              startUtcInclusive: utcStartOfManilaDay(_viewStart),
              endUtcExclusive: utcExclusiveEndOfManilaDay(_viewEnd),
              // Firestore max per query is 10,000 documents.
              limit: 10000,
            ),
            builder: (context, salesSnap) {
              if (salesSnap.hasError) {
                return _ErrorCard(title: 'Could not load sales', error: salesSnap.error);
              }
              final sales = salesSnap.data ?? const <Sale>[];
              if (salesSnap.connectionState == ConnectionState.waiting && sales.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (sales.isEmpty) {
                return _EmptyStateCard(
                  icon: Icons.analytics_outlined,
                  title: 'No sales in this range',
                  subtitle: 'Widen the dates, tap a preset, or record sales for those days.',
                );
              }

              final kpis = computeSalesKpis(sales);
              final byService = groupSalesByServiceId(sales);
              final byBarber = groupSalesByBarberId(sales);
              final byPm = groupSalesByPaymentMethod(sales);
              final promoImpact = computePromoImpact(sales);
              final byHourTotals = groupSalesByManilaHourTotals(sales);
              final byWeekday = groupSalesByWeekdayFromSaleDay(sales);

              return StreamBuilder<List<Barber>>(
                stream: _catalog.watchActiveBarbers(),
                builder: (context, barbersSnap) {
                  final barberMap = {
                    for (final b in (barbersSnap.data ?? const <Barber>[])) b.id: b.name,
                  };
                  return StreamBuilder<List<ServiceItem>>(
                    stream: _catalog.watchActiveServices(),
                    builder: (context, servicesSnap) {
                      final serviceMap = {
                        for (final s in (servicesSnap.data ?? const <ServiceItem>[])) s.id: s.name,
                      };

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                            child: Text(
                              'Overview',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _KpiGrid(
                            totalSales: kpis.totalSales,
                            serviceCount: kpis.serviceCount,
                            averageTicket: kpis.averageTicket,
                            discounts: kpis.totalDiscounts,
                            promoRate: kpis.promoUsageRate,
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                            child: Text(
                              'Breakdowns',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _SectionCard(
                            title: 'Sales by service',
                            subtitle: 'Revenue + count + average ticket',
                            rows: _labelRowsFromMoneyCount(
                              byService,
                              labelOf: (id) => serviceMap[id] ?? _unknownLabel('Service', id),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Sales by barber',
                            subtitle: 'Revenue + count + average ticket',
                            rows: _labelRowsFromMoneyCount(
                              byBarber,
                              labelOf: (id) => barberMap[id] ?? _unknownLabel('Barber', id),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Sales by payment method',
                            subtitle: 'Revenue + count',
                            rows: _labelRowsFromMoneyCount(
                              byPm,
                              labelOf: (k) => k,
                              showAverage: false,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Promo impact',
                            subtitle: 'Average ticket with promo vs without promo',
                            rows: [
                              _RowTextMoney(
                                'With promo (${promoImpact.withPromoCount})',
                                promoImpact.avgWithPromo,
                                isMoney: true,
                                bold: true,
                              ),
                              _RowTextMoney(
                                'Without promo (${promoImpact.withoutPromoCount})',
                                promoImpact.avgWithoutPromo,
                                isMoney: true,
                                bold: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Peak time (by hour, Manila)',
                            subtitle: 'Total sales by hour of day',
                            rows: _rowsFromHours(byHourTotals),
                          ),
                          const SizedBox(height: 12),
                          _SectionCard(
                            title: 'Busiest day of week',
                            subtitle: 'Total sales by weekday (from sale day)',
                            rows: _rowsFromWeekdayTotals(byWeekday),
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
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.totalSales,
    required this.serviceCount,
    required this.averageTicket,
    required this.discounts,
    required this.promoRate,
  });

  final double totalSales;
  final int serviceCount;
  final double averageTicket;
  final double discounts;
  final double promoRate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final scheme = Theme.of(context).colorScheme;
        const gap = 10.0;
        final w = c.maxWidth;
        final cellW = (w - gap) / 2;
        final promoPct = (promoRate * 100).toStringAsFixed(0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _KpiTotalStrip(
              value: '₱${_formatMoney(totalSales)}',
              colorScheme: scheme,
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: cellW,
                  child: _KpiMiniTile(
                    icon: Icons.content_cut_outlined,
                    label: 'Services',
                    value: '$serviceCount',
                    colorScheme: scheme,
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: cellW,
                  child: _KpiMiniTile(
                    icon: Icons.local_atm_outlined,
                    label: 'Avg ticket',
                    value: '₱${_formatMoney(averageTicket)}',
                    colorScheme: scheme,
                  ),
                ),
              ],
            ),
            SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: cellW,
                  child: _KpiMiniTile(
                    icon: Icons.money_off_outlined,
                    label: 'Discounts',
                    value: '₱${_formatMoney(discounts)}',
                    colorScheme: scheme,
                    accent: scheme.error,
                  ),
                ),
                SizedBox(width: gap),
                SizedBox(
                  width: cellW,
                  child: _KpiMiniTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Promo usage',
                    value: '$promoPct%',
                    colorScheme: scheme,
                    accent: scheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Full-width headline metric: label + value uses horizontal space (no odd single “different” card color).
class _KpiTotalStrip extends StatelessWidget {
  const _KpiTotalStrip({
    required this.value,
    required this.colorScheme,
  });

  final String value;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.payments_outlined, color: colorScheme.primary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Total sales',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiMiniTile extends StatelessWidget {
  const _KpiMiniTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = accent ?? colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: a.withValues(alpha: 0.9)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.rows,
  });

  final String title;
  final String subtitle;
  final List<_RowTextMoney> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < rows.length; i++) ...[
              _SectionMetricRow(row: rows[i], theme: theme),
              if (i < rows.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionMetricRow extends StatelessWidget {
  const _SectionMetricRow({required this.row, required this.theme});

  final _RowTextMoney row;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final valueText =
        row.isMoney ? '₱${_formatMoney(row.value)}' : row.value.toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                row.label,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              valueText,
              textAlign: TextAlign.end,
              style: (row.bold ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)?.copyWith(
                fontWeight: row.bold ? FontWeight.w900 : FontWeight.w700,
                color: row.bold ? scheme.primary : null,
              ),
            ),
          ],
        ),
        if ((row.trailingNote ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            row.trailingNote!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _RowTextMoney {
  const _RowTextMoney(
    this.label,
    this.value, {
    required this.isMoney,
    this.bold = false,
    this.trailingNote,
  });

  final String label;
  final double value;
  final bool isMoney;
  final bool bold;
  final String? trailingNote;
}

List<_RowTextMoney> _labelRowsFromMoneyCount(
  List<MoneyCountRow> rows, {
  required String Function(String key) labelOf,
  bool showAverage = true,
}) {
  return [
    for (final r in rows)
      _RowTextMoney(
        '${labelOf(r.key)}  (${r.count})',
        r.total,
        isMoney: true,
        bold: false,
        trailingNote: showAverage ? 'Avg: ₱${_formatMoney(r.average)}' : null,
      ),
  ];
}

List<_RowTextMoney> _rowsFromHours(List<double> totalsByHour) {
  final indexed = <MapEntry<int, double>>[];
  for (var i = 0; i < totalsByHour.length; i++) {
    indexed.add(MapEntry(i, totalsByHour[i]));
  }
  indexed.sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in indexed)
      _RowTextMoney(
        _hourLabel(e.key),
        e.value,
        isMoney: true,
      ),
  ];
}

String _hourLabel(int hour0To23) {
  final h = hour0To23 % 24;
  final isPm = h >= 12;
  final display = (h == 0) ? 12 : (h > 12 ? h - 12 : h);
  final suffix = isPm ? 'PM' : 'AM';
  return '$display $suffix';
}

List<_RowTextMoney> _rowsFromWeekdayTotals(Map<int, double> totals) {
  final entries = totals.entries.toList(growable: false);
  entries.sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entries)
      _RowTextMoney(
        _weekdayLabel(e.key),
        e.value,
        isMoney: true,
      ),
  ];
}

String _weekdayLabel(int weekday1To7) {
  switch (weekday1To7) {
    case DateTime.monday:
      return 'Monday';
    case DateTime.tuesday:
      return 'Tuesday';
    case DateTime.wednesday:
      return 'Wednesday';
    case DateTime.thursday:
      return 'Thursday';
    case DateTime.friday:
      return 'Friday';
    case DateTime.saturday:
      return 'Saturday';
    case DateTime.sunday:
      return 'Sunday';
    default:
      return 'Weekday $weekday1To7';
  }
}

String _unknownLabel(String type, String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty || trimmed == 'Unknown') return 'Unknown $type';
  return 'Unknown $type ($trimmed)';
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
    this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData? icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 44, color: scheme.outline),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
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

void _showSalesIntelligenceHelpDialog(BuildContext context) {
  final theme = Theme.of(context);
  final muted = theme.colorScheme.onSurfaceVariant;
  final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.45);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('About Sales Intelligence'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This screen summarizes recorded sales for the date range you choose. Everything uses the shop calendar day in Manila time.',
                style: bodyStyle,
              ),
              const SizedBox(height: 16),
              Text('Overview', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                '• Total sales, how many services sold, average ticket, discounts, and how often promos were used.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Breakdowns', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                '• By service, barber, and payment method.\n'
                '• Promo impact compares average ticket with vs without a promo.\n'
                '• Peak hour and busiest weekday use each sale’s time and day.',
                style: bodyStyle?.copyWith(color: muted),
              ),
              const SizedBox(height: 14),
              Text('Tip', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(
                'Use presets or Load report after changing dates. This is not the same as Cash flow (which tracks physical cash in the drawer).',
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

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}
