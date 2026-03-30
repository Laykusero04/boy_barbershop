import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/day_range.dart';
import 'package:boy_barbershop/utils/hourly_activity.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class ActivityByHourScreen extends StatefulWidget {
  const ActivityByHourScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ActivityByHourScreen> createState() => _ActivityByHourScreenState();
}

class _ActivityByHourScreenState extends State<ActivityByHourScreen> {
  final _salesRepo = SalesRepository();

  late String _startDay;
  late String _endDay;
  late String _viewStart;
  late String _viewEnd;
  HourBucketMode _mode = HourBucketMode.hourly;

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
    final days = daysBetweenInclusive(_viewStart, _viewEnd);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Activity (by hour)', style: theme.textTheme.headlineSmall),
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
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<HourBucketMode>(
                          segments: const [
                            ButtonSegment(
                              value: HourBucketMode.hourly,
                              label: Text('Hourly'),
                              icon: Icon(Icons.schedule_outlined),
                            ),
                            ButtonSegment(
                              value: HourBucketMode.blocks,
                              label: Text('Blocks'),
                              icon: Icon(Icons.view_week_outlined),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: (v) =>
                              setState(() => _mode = v.firstOrNull ?? HourBucketMode.hourly),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
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
                    ],
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
          FutureBuilder<List<Sale>>(
            key: ValueKey('activity:$_viewStart:$_viewEnd:${_mode.name}'),
            future: _salesRepo.fetchSalesForDaysSafe(days),
            builder: (context, snap) {
              if (snap.hasError) {
                return _ErrorCard(title: 'Could not load sales', error: snap.error);
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final sales = snap.data ?? const <Sale>[];
              if (sales.isEmpty) {
                return _EmptyStateCard(
                  title: 'No sales in this range.',
                  subtitle: 'Try another date range.',
                );
              }

              final summary = computeHourlyActivity(sales, mode: _mode);
              final totalSales = sales.fold<double>(0, (s, e) => s + e.price);
              final totalCount = sales.length;
              final avg = totalCount <= 0 ? 0.0 : totalSales / totalCount;

              return Column(
                children: [
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 10,
                        children: [
                          _pill(theme, 'Services', '$totalCount', theme.colorScheme.secondary),
                          _pill(theme, 'Sales', '₱${_formatMoney(totalSales)}', theme.colorScheme.secondary),
                          _pill(theme, 'Avg ticket', '₱${_formatMoney(avg)}', theme.colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (summary.peakTraffic != null || summary.peakRevenue != null)
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Peak time', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 12),
                            if (summary.peakTraffic != null)
                              _peakRow(
                                theme,
                                'Peak by traffic',
                                summary.peakTraffic!.label,
                                '${summary.peakTraffic!.servicesCount} services',
                              ),
                            if (summary.peakRevenue != null)
                              _peakRow(
                                theme,
                                'Peak by revenue',
                                summary.peakRevenue!.label,
                                '₱${_formatMoney(summary.peakRevenue!.salesTotal)}',
                              ),
                          ],
                        ),
                      ),
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
                          Text('Hourly activity', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 12),
                          _tableHeader(theme),
                          const SizedBox(height: 8),
                          for (final r in summary.rows) ...[
                            _tableRow(theme, r),
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
      ),
    );
  }
}

Widget _pill(ThemeData theme, String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      '$label: $value',
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: color,
      ),
    ),
  );
}

Widget _peakRow(ThemeData theme, String label, String bucket, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
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
        Text(bucket, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

Widget _tableHeader(ThemeData theme) {
  return Row(
    children: [
      Expanded(
        flex: 3,
        child: Text(
          'Hour',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(
        flex: 2,
        child: Text(
          'Services',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          'Sales',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          'Avg',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

Widget _tableRow(ThemeData theme, HourBucketRow r) {
  return Row(
    children: [
      Expanded(flex: 3, child: Text(r.label)),
      Expanded(
        flex: 2,
        child: Text(
          '${r.servicesCount}',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          '₱${_formatMoney(r.salesTotal)}',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      Expanded(
        flex: 3,
        child: Text(
          '₱${_formatMoney(r.averageTicket)}',
          textAlign: TextAlign.right,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
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

extension<T> on Set<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

