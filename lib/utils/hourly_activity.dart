import 'dart:math' as math;

import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

enum HourBucketMode { hourly, blocks }

class HourBucketRow {
  const HourBucketRow({
    required this.label,
    required this.startHourInclusive,
    required this.endHourExclusive,
    required this.servicesCount,
    required this.salesTotal,
  });

  final String label;
  final int startHourInclusive;
  final int endHourExclusive;
  final int servicesCount;
  final double salesTotal;

  double get averageTicket => servicesCount <= 0 ? 0 : salesTotal / servicesCount;
}

class HourlyActivitySummary {
  const HourlyActivitySummary({
    required this.rows,
    required this.peakTraffic,
    required this.peakRevenue,
  });

  final List<HourBucketRow> rows;
  final HourBucketRow? peakTraffic;
  final HourBucketRow? peakRevenue;
}

HourlyActivitySummary computeHourlyActivity(
  List<Sale> sales, {
  required HourBucketMode mode,
}) {
  final buckets = (mode == HourBucketMode.hourly)
      ? _hourlyBuckets()
      : _blockBuckets();

  final countByHour = List<int>.filled(24, 0);
  final totalByHour = List<double>.filled(24, 0.0);
  for (final s in sales) {
    final dt = s.saleDateTime;
    if (dt == null) continue;
    final h = manilaHourOfInstant(dt);
    if (h < 0 || h > 23) continue;
    countByHour[h] += 1;
    totalByHour[h] += s.price;
  }

  final rows = <HourBucketRow>[];
  for (final b in buckets) {
    var count = 0;
    var total = 0.0;
    for (var h = b.startHourInclusive; h < b.endHourExclusive; h++) {
      final hour = h % 24;
      count += countByHour[hour];
      total += totalByHour[hour];
    }
    rows.add(
      HourBucketRow(
        label: b.label,
        startHourInclusive: b.startHourInclusive,
        endHourExclusive: b.endHourExclusive,
        servicesCount: count,
        salesTotal: total,
      ),
    );
  }

  HourBucketRow? peakTraffic;
  HourBucketRow? peakRevenue;
  for (final r in rows) {
    if (peakTraffic == null ||
        r.servicesCount > peakTraffic.servicesCount ||
        (r.servicesCount == peakTraffic.servicesCount && r.salesTotal > peakTraffic.salesTotal)) {
      peakTraffic = r;
    }
    if (peakRevenue == null ||
        r.salesTotal > peakRevenue.salesTotal ||
        (r.salesTotal == peakRevenue.salesTotal && r.servicesCount > peakRevenue.servicesCount)) {
      peakRevenue = r;
    }
  }

  return HourlyActivitySummary(
    rows: rows,
    peakTraffic: peakTraffic,
    peakRevenue: peakRevenue,
  );
}

class _BucketSpec {
  const _BucketSpec({
    required this.label,
    required this.startHourInclusive,
    required this.endHourExclusive,
  });

  final String label;
  final int startHourInclusive;
  final int endHourExclusive;
}

List<_BucketSpec> _hourlyBuckets() {
  return [
    for (var h = 0; h < 24; h++)
      _BucketSpec(
        label: _hourLabel(h),
        startHourInclusive: h,
        endHourExclusive: h + 1,
      ),
  ];
}

List<_BucketSpec> _blockBuckets() {
  // Common shop blocks; no overlap, full day coverage.
  return const [
    _BucketSpec(label: '12AM–9AM', startHourInclusive: 0, endHourExclusive: 9),
    _BucketSpec(label: '9AM–12PM', startHourInclusive: 9, endHourExclusive: 12),
    _BucketSpec(label: '12PM–3PM', startHourInclusive: 12, endHourExclusive: 15),
    _BucketSpec(label: '3PM–6PM', startHourInclusive: 15, endHourExclusive: 18),
    _BucketSpec(label: '6PM–9PM', startHourInclusive: 18, endHourExclusive: 21),
    _BucketSpec(label: '9PM–12AM', startHourInclusive: 21, endHourExclusive: 24),
  ];
}

String _hourLabel(int hour0To23) {
  final h = hour0To23 % 24;
  final isPm = h >= 12;
  final display = (h == 0) ? 12 : (h > 12 ? h - 12 : h);
  final suffix = isPm ? 'PM' : 'AM';
  return '$display$suffix';
}

double clampNonNegative(double v) => math.max(0.0, v);

