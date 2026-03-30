import 'package:flutter/material.dart';

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
  final _salesRepo = SalesRepository();
  final _catalog = CatalogRepository();

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Sales Intelligence', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Date range', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Start',
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
                          label: 'End',
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
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
                      },
                      child: const Text('View'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Showing: $_viewStart to $_viewEnd',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Sale>>(
            stream: _salesRepo.watchSalesForRangeUtc(
              startUtcInclusive: utcStartOfManilaDay(_viewStart),
              endUtcExclusive: utcExclusiveEndOfManilaDay(_viewEnd),
              limit: 20000,
            ),
            builder: (context, salesSnap) {
              if (salesSnap.hasError) {
                return _ErrorCard(title: 'Could not load sales', error: salesSnap.error);
              }
              final sales = salesSnap.data ?? const <Sale>[];
              if (salesSnap.connectionState == ConnectionState.waiting && sales.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (sales.isEmpty) {
                return _EmptyStateCard(
                  title: 'No sales in this range.',
                  subtitle: 'Try another date range.',
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
                        children: [
                          _KpiGrid(
                            totalSales: kpis.totalSales,
                            serviceCount: kpis.serviceCount,
                            averageTicket: kpis.averageTicket,
                            discounts: kpis.totalDiscounts,
                            promoRate: kpis.promoUsageRate,
                          ),
                          const SizedBox(height: 12),
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
        final wide = c.maxWidth >= 520;
        final children = [
          _KpiCard(title: 'Total sales', value: '₱${_formatMoney(totalSales)}', bold: true),
          _KpiCard(title: 'Service count', value: '$serviceCount'),
          _KpiCard(title: 'Avg ticket', value: '₱${_formatMoney(averageTicket)}'),
          _KpiCard(title: 'Discounts', value: '₱${_formatMoney(discounts)}'),
          _KpiCard(title: 'Promo usage', value: '${(promoRate * 100).toStringAsFixed(0)}%'),
        ];

        if (!wide) {
          return Column(
            children: [
              for (final w in children) ...[
                w,
                const SizedBox(height: 12),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final w in children)
              SizedBox(
                width: (c.maxWidth - 12) / 2,
                child: w,
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.title, required this.value, this.bold = false});

  final String title;
  final String value;
  final bool bold;

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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: bold ? FontWeight.w900 : FontWeight.w800,
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
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final r in rows) ...[
              Row(
                children: [
                  Expanded(child: Text(r.label)),
                  Text(
                    r.isMoney ? '₱${_formatMoney(r.value)}' : r.value.toStringAsFixed(0),
                    style: (r.bold ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                        ?.copyWith(fontWeight: r.bold ? FontWeight.w900 : null),
                  ),
                ],
              ),
              if ((r.trailingNote ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  r.trailingNote!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
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
  return '$display$suffix';
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

String _formatMoney(double value) {
  final fixed = value.toStringAsFixed(2);
  if (fixed.endsWith('.00')) return fixed.substring(0, fixed.length - 3);
  return fixed;
}

