import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/data/settings_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/hourly_activity.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class PeakAndDailyTargetScreen extends StatefulWidget {
  const PeakAndDailyTargetScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<PeakAndDailyTargetScreen> createState() => _PeakAndDailyTargetScreenState();
}

class _PeakAndDailyTargetScreenState extends State<PeakAndDailyTargetScreen> {
  static const _targetSalesKey = 'daily_target_sales_amount';
  static const _targetServicesKey = 'daily_target_services_count';

  final _salesRepo = SalesRepository();
  final _settings = SettingsRepository();

  late String _day;
  late String _viewDay;
  int _reload = 0;

  final _targetSalesController = TextEditingController();
  final _targetServicesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _day = todayManilaDay();
    _viewDay = _day;
  }

  @override
  void dispose() {
    _targetSalesController.dispose();
    _targetServicesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Peak & Daily Target', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pick day', style: theme.textTheme.titleMedium),
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
                        onPressed: () => setState(() {
                          _viewDay = _day;
                          _reload++;
                        }),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Showing: $_viewDay',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _TargetSettingsCard(
            settings: _settings,
            targetSalesKey: _targetSalesKey,
            targetServicesKey: _targetServicesKey,
            targetSalesController: _targetSalesController,
            targetServicesController: _targetServicesController,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Sale>>(
            key: ValueKey('day:$_viewDay:$_reload'),
            future: _salesRepo.fetchSalesForDaysSafe([_viewDay]),
            builder: (context, todaySnap) {
              if (todaySnap.hasError) {
                return Column(
                  children: [
                    _ErrorCard(title: 'Could not load sales', error: todaySnap.error),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonal(
                        onPressed: () => setState(() => _reload++),
                        child: const Text('Retry'),
                      ),
                    ),
                  ],
                );
              }
              if (!todaySnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final todaySales = todaySnap.data ?? const <Sale>[];

              final salesTotal = todaySales.fold<double>(0, (s, e) => s + e.price);
              final servicesCount = todaySales.length;
              final hourly = computeHourlyActivity(todaySales, mode: HourBucketMode.hourly);

              return StreamBuilder<double?>(
                stream: _settings.watchOptionalDouble(_targetSalesKey),
                builder: (context, targetSalesSnap) {
                  return StreamBuilder<double?>(
                    stream: _settings.watchOptionalDouble(_targetServicesKey),
                    builder: (context, targetServicesSnap) {
                      final targetSales = targetSalesSnap.data;
                      final targetServices = targetServicesSnap.data?.round();

                      final salesProgress = (targetSales == null || targetSales <= 0)
                          ? null
                          : (salesTotal / targetSales).clamp(0.0, 10.0);
                      final servicesProgress = (targetServices == null || targetServices <= 0)
                          ? null
                          : (servicesCount / targetServices).clamp(0.0, 10.0);

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
                                  Text('Today progress', style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 12),
                                  _progressRow(
                                    theme,
                                    label: 'Sales',
                                    actualLabel: '₱${_formatMoney(salesTotal)}',
                                    targetLabel: (targetSales == null || targetSales <= 0)
                                        ? 'No target'
                                        : '₱${_formatMoney(targetSales)}',
                                    progress: salesProgress,
                                  ),
                                  const SizedBox(height: 12),
                                  _progressRow(
                                    theme,
                                    label: 'Services',
                                    actualLabel: '$servicesCount',
                                    targetLabel: (targetServices == null || targetServices <= 0)
                                        ? 'No target'
                                        : '$targetServices',
                                    progress: servicesProgress,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Remaining sales: ${_remainingMoney(targetSales, salesTotal)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Remaining services: ${_remainingCount(targetServices, servicesCount)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (hourly.peakTraffic != null || hourly.peakRevenue != null)
                            Card(
                              elevation: 0,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Peak hours (today)', style: theme.textTheme.titleMedium),
                                    const SizedBox(height: 12),
                                    if (hourly.peakTraffic != null)
                                      _kvText(
                                        theme,
                                        'Peak by traffic',
                                        '${hourly.peakTraffic!.label}  (${hourly.peakTraffic!.servicesCount} services)',
                                      ),
                                    if (hourly.peakRevenue != null)
                                      _kvText(
                                        theme,
                                        'Peak by revenue',
                                        '${hourly.peakRevenue!.label}  (₱${_formatMoney(hourly.peakRevenue!.salesTotal)})',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          FutureBuilder<_SuggestedTargets>(
                            key: ValueKey('suggested:$_viewDay'),
                            future: _suggestTargets(anyDay: _viewDay),
                            builder: (context, sSnap) {
                              if (sSnap.hasError) {
                                return _ErrorCard(
                                  title: 'Could not compute suggested targets',
                                  error: sSnap.error,
                                );
                              }
                              if (!sSnap.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final s = sSnap.data!;
                              return Card(
                                elevation: 0,
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Suggested targets', style: theme.textTheme.titleMedium),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Based on last ${s.daysCount} days (average).',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _kv(theme, 'Suggested sales/day', s.avgSalesPerDay, isMoney: true),
                                      _kv(theme, 'Suggested services/day', s.avgServicesPerDay.toDouble(),
                                          isMoney: false),
                                    ],
                                  ),
                                ),
                              );
                            },
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

  Future<_SuggestedTargets> _suggestTargets({required String anyDay}) async {
    final d = parseYyyyMmDd(anyDay) ?? nowManila();
    final dayOnly = DateTime(d.year, d.month, d.day);

    // Use last 7 full days before selected day.
    final days = <String>[
      for (var i = 1; i <= 7; i++) yyyyMmDd(dayOnly.subtract(Duration(days: i))),
    ];
    final sales = await _salesRepo.fetchSalesForDaysSafe(days);

    final totalsByDay = <String, double>{};
    final countsByDay = <String, int>{};
    for (final s in sales) {
      final day = s.saleDay.trim();
      if (!isValidYyyyMmDd(day)) continue;
      totalsByDay[day] = (totalsByDay[day] ?? 0.0) + s.price;
      countsByDay[day] = (countsByDay[day] ?? 0) + 1;
    }

    var sumSales = 0.0;
    var sumCount = 0;
    for (final day in days) {
      sumSales += totalsByDay[day] ?? 0.0;
      sumCount += countsByDay[day] ?? 0;
    }
    return _SuggestedTargets(
      daysCount: days.length,
      avgSalesPerDay: sumSales / days.length,
      avgServicesPerDay: (sumCount / days.length).round(),
    );
  }
}

class _SuggestedTargets {
  const _SuggestedTargets({
    required this.daysCount,
    required this.avgSalesPerDay,
    required this.avgServicesPerDay,
  });

  final int daysCount;
  final double avgSalesPerDay;
  final int avgServicesPerDay;
}

class _TargetSettingsCard extends StatelessWidget {
  const _TargetSettingsCard({
    required this.settings,
    required this.targetSalesKey,
    required this.targetServicesKey,
    required this.targetSalesController,
    required this.targetServicesController,
  });

  final SettingsRepository settings;
  final String targetSalesKey;
  final String targetServicesKey;
  final TextEditingController targetSalesController;
  final TextEditingController targetServicesController;

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
            Text('Daily targets', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Set sales and/or services targets. Leave blank to disable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<double?>(
              stream: settings.watchOptionalDouble(targetSalesKey),
              builder: (context, sSnap) {
                final v = sSnap.data;
                if (v != null && targetSalesController.text.trim().isEmpty) {
                  targetSalesController.text = _formatMoney(v);
                }
                return TextFormField(
                  controller: targetSalesController,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Daily sales target (₱)',
                    hintText: '0.00',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            StreamBuilder<double?>(
              stream: settings.watchOptionalDouble(targetServicesKey),
              builder: (context, sSnap) {
                final v = sSnap.data;
                if (v != null && targetServicesController.text.trim().isEmpty) {
                  targetServicesController.text = v.round().toString();
                }
                return TextFormField(
                  controller: targetServicesController,
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  decoration: const InputDecoration(
                    labelText: 'Daily services target (count)',
                    hintText: '0',
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _save(context),
                child: const Text('Save targets'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final sales = _parseMoney(targetSalesController.text);
    final services = int.tryParse(targetServicesController.text.trim());

    try {
      if (sales == null) {
        // If blank or invalid, set to 0 to disable.
        await settings.setDouble(targetSalesKey, 0);
      } else {
        await settings.setDouble(targetSalesKey, math.max(0.0, sales));
      }

      if (services == null) {
        await settings.setDouble(targetServicesKey, 0);
      } else {
        await settings.setDouble(targetServicesKey, math.max(0, services).toDouble());
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Targets saved.')),
      );
      targetSalesController.clear();
      targetServicesController.clear();
    } on SettingsWriteException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

Widget _progressRow(
  ThemeData theme, {
  required String label,
  required String actualLabel,
  required String targetLabel,
  required double? progress,
}) {
  final pct = progress == null ? null : (progress * 100);
  final barValue = progress == null ? 0.0 : progress.clamp(0.0, 1.0);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            '$actualLabel / $targetLabel',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: barValue),
      const SizedBox(height: 6),
      Text(
        pct == null ? 'Progress: —' : 'Progress: ${pct.toStringAsFixed(0)}%',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

String _remainingMoney(double? target, double actual) {
  if (target == null || target <= 0) return '—';
  final rem = math.max(0.0, target - actual);
  return '₱${_formatMoney(rem)}';
}

String _remainingCount(int? target, int actual) {
  if (target == null || target <= 0) return '—';
  final rem = math.max(0, target - actual);
  return '$rem';
}

Widget _kv(ThemeData theme, String label, double value, {required bool isMoney}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Text(
          isMoney ? '₱${_formatMoney(value)}' : value.toStringAsFixed(0),
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

Widget _kvText(ThemeData theme, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900)),
      ],
    ),
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

