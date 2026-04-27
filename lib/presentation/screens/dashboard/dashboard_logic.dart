import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/barber_shift.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/models/inventory_item.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/presentation/screens/dashboard/dashboard_models.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

double sumSales(List<Sale> sales) => sales.fold<double>(0, (s, e) => s + e.price);

double sumExpenses(List<Expense> expenses) =>
    expenses.fold<double>(0, (s, e) => s + e.amount);

Map<String, Barber> mapBarbersById(List<Barber> barbers) {
  return {for (final b in barbers) b.id: b};
}

/// Returns a multiplier per (barberId, day) key derived from shift records.
///
/// - Closed full-day shift → 1.0
/// - Closed half-day shift → [halfDayMultiplier]
/// - Open shift (still on duty) → 1.0 (projected full day until closed)
/// - No shift for that (barberId, day) → key absent
Map<String, double> shiftMultipliersByBarberDay({
  required List<BarberShift> shifts,
  required double halfDayMultiplier,
}) {
  final out = <String, double>{};
  for (final s in shifts) {
    final day = s.occurredDay.trim();
    if (day.isEmpty || s.barberId.isEmpty) continue;
    final key = '${s.barberId}|$day';
    final double m;
    if (s.dayClassification == DayClassification.half) {
      m = halfDayMultiplier;
    } else {
      m = 1.0;
    }
    final existing = out[key];
    if (existing == null || m > existing) out[key] = m;
  }
  return out;
}

double computeBarberShareTotal({
  required List<Sale> sales,
  required Map<String, Barber> barberById,
  required List<BarberShift> shifts,
  required double halfDayMultiplier,
}) {
  var total = 0.0;
  final multipliers = shiftMultipliersByBarberDay(
    shifts: shifts,
    halfDayMultiplier: halfDayMultiplier,
  );
  // For guaranteedBase barbers, accumulate commission per barber per day
  // then compare with daily rate * multiplier (only for days with a shift).
  final gbCommission = <String, double>{}; // key: barberId|day
  final gbBarbers = <String, Barber>{};

  for (final s in sales) {
    final b = barberById[s.barberId];
    if (b == null) continue;

    if (b.compensationType == BarberCompensationType.dailyRate) {
      // Daily-rate cost is added below from shifts, not from sales presence.
      continue;
    } else if (b.compensationType == BarberCompensationType.guaranteedBase) {
      final day = s.saleDay.trim();
      if (day.isEmpty) continue;
      final base = s.ownerCoversDiscount ? (s.originalPrice ?? s.price) : s.price;
      final key = '${s.barberId}|$day';
      gbCommission[key] = (gbCommission[key] ?? 0) + base * (b.percentageShare / 100.0);
      gbBarbers[s.barberId] = b;
    } else {
      final base = s.ownerCoversDiscount ? (s.originalPrice ?? s.price) : s.price;
      total += base * (b.percentageShare / 100.0);
    }
  }

  // Daily-rate barbers: charge dailyRate * multiplier per shift day.
  multipliers.forEach((key, m) {
    final barberId = key.split('|').first;
    final b = barberById[barberId];
    if (b == null) return;
    if (b.compensationType == BarberCompensationType.dailyRate) {
      total += b.dailyRate * m;
    }
  });

  // Guaranteed-base: union of (days with a shift) and (days with commission).
  // - Day with shift: pay max(commission, dailyRate * multiplier).
  // - Day with sales but no shift: pay commission only (no daily-rate floor).
  final gbDayKeys = <String>{...gbCommission.keys};
  multipliers.forEach((key, _) {
    final barberId = key.split('|').first;
    final b = barberById[barberId];
    if (b?.compensationType == BarberCompensationType.guaranteedBase) {
      gbDayKeys.add(key);
      gbBarbers[barberId] = b!;
    }
  });
  for (final key in gbDayKeys) {
    final barberId = key.split('|').first;
    final b = gbBarbers[barberId];
    if (b == null) continue;
    final commission = gbCommission[key] ?? 0.0;
    final m = multipliers[key];
    if (m != null) {
      final floor = b.dailyRate * m;
      total += commission > floor ? commission : floor;
    } else {
      total += commission;
    }
  }

  return total;
}

({String? barberId, double sales}) computeTopBarber({
  required List<Sale> sales,
}) {
  if (sales.isEmpty) return (barberId: null, sales: 0.0);
  final totals = <String, double>{};
  for (final s in sales) {
    final id = s.barberId.trim();
    if (id.isEmpty) continue;
    totals[id] = (totals[id] ?? 0) + s.price;
  }
  String? bestId;
  var bestSales = 0.0;
  totals.forEach((id, total) {
    if (bestId == null || total > bestSales) {
      bestId = id;
      bestSales = total;
    }
  });
  return (barberId: bestId, sales: bestSales);
}

DashboardKpis computeKpis({
  required List<Sale> sales,
  required double expensesTotal,
  required Map<String, Barber> barberById,
  required List<BarberShift> shifts,
  required double halfDayMultiplier,
}) {
  final salesTotal = sumSales(sales);
  final shareTotal = computeBarberShareTotal(
    sales: sales,
    barberById: barberById,
    shifts: shifts,
    halfDayMultiplier: halfDayMultiplier,
  );
  final top = computeTopBarber(sales: sales);
  final net = salesTotal - shareTotal - expensesTotal;
  return DashboardKpis(
    customers: sales.length,
    sales: salesTotal,
    barberShare: shareTotal,
    expenses: expensesTotal,
    netProfitEstimate: net,
    topBarberId: top.barberId,
    topBarberSales: top.sales,
  );
}

List<BarberEarningsRow> computeEarningsRows({
  required List<Sale> sales,
  required List<Barber> barbers,
  required List<BarberShift> shifts,
  required double halfDayMultiplier,
}) {
  final totals = <String, double>{};
  final counts = <String, int>{};
  for (final s in sales) {
    final id = s.barberId.trim();
    if (id.isEmpty) continue;
    final earningsBase = s.ownerCoversDiscount ? (s.originalPrice ?? s.price) : s.price;
    totals[id] = (totals[id] ?? 0) + earningsBase;
    counts[id] = (counts[id] ?? 0) + 1;
  }

  final multipliers = shiftMultipliersByBarberDay(
    shifts: shifts,
    halfDayMultiplier: halfDayMultiplier,
  );

  final active = barbers.where((b) => b.isActive).toList(growable: false);
  final rows = <BarberEarningsRow>[];
  for (final b in active) {
    final totalSales = totals[b.id] ?? 0.0;
    final barberSales = sales.where((s) => s.barberId == b.id).toList();

    // Pre-compute multiplier sum for this barber across shift days.
    var dayCountWeighted = 0.0;
    multipliers.forEach((key, m) {
      if (key.startsWith('${b.id}|')) dayCountWeighted += m;
    });

    final double earnings;
    if (b.compensationType == BarberCompensationType.dailyRate) {
      earnings = b.dailyRate * dayCountWeighted;
    } else if (b.compensationType == BarberCompensationType.guaranteedBase) {
      // Group sales by day, compute commission per day, take max(commission, dailyRate * multiplier).
      // Days with a shift but no sales contribute dailyRate * multiplier.
      final dayCommission = <String, double>{};
      for (final s in barberSales) {
        final day = s.saleDay.trim();
        if (day.isEmpty) continue;
        final base = s.ownerCoversDiscount ? (s.originalPrice ?? s.price) : s.price;
        dayCommission[day] = (dayCommission[day] ?? 0) + base * (b.percentageShare / 100.0);
      }
      final dayKeys = <String>{...dayCommission.keys};
      multipliers.forEach((key, _) {
        if (key.startsWith('${b.id}|')) {
          dayKeys.add(key.substring(b.id.length + 1));
        }
      });
      var sum = 0.0;
      for (final day in dayKeys) {
        final commission = dayCommission[day] ?? 0.0;
        final m = multipliers['${b.id}|$day'];
        if (m != null) {
          final floor = b.dailyRate * m;
          sum += commission > floor ? commission : floor;
        } else {
          sum += commission;
        }
      }
      earnings = sum;
    } else {
      earnings = totalSales * (b.percentageShare / 100.0);
    }
    rows.add(
      BarberEarningsRow(
        barber: b,
        totalSales: totalSales,
        earnings: earnings,
        servicesCount: counts[b.id] ?? 0,
      ),
    );
  }
  rows.sort((a, b) => b.totalSales.compareTo(a.totalSales));
  return rows;
}

List<InventoryItem> lowStockItems(List<InventoryItem> items) {
  final out = items.where((i) => i.isLowStock).toList(growable: false);
  out.sort((a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
  return out;
}

List<DashboardAlert> buildAlerts({
  required String todayManilaDay,
  required double? dailyTargetSalesAmount,
  required double todaySalesTotal,
  required List<InventoryItem> lowStock,
}) {
  final alerts = <DashboardAlert>[];
  final target = dailyTargetSalesAmount;
  if (target != null && target > 0 && todaySalesTotal < target) {
    final remaining = (target - todaySalesTotal).clamp(0.0, 999999999.0);
    alerts.add(
      DashboardAlert(
        type: DashboardAlertType.belowDailyTarget,
        title: 'Below daily target',
        subtitle: '$todayManilaDay • Remaining ₱${formatMoney(remaining)}',
      ),
    );
  }

  if (lowStock.isNotEmpty) {
    alerts.add(
      DashboardAlert(
        type: DashboardAlertType.lowInventory,
        title: 'Low inventory',
        subtitle: '${lowStock.length} item(s) at/below threshold',
      ),
    );
  }

  return alerts;
}

/// Manila month range (inclusive) as YYYY-MM-DD strings.
({String startDay, String endDay}) manilaMonthRangeFromDay(String anyDayManila) {
  final d = parseYyyyMmDd(anyDayManila) ?? nowManila();
  final start = DateTime(d.year, d.month, 1);
  final nextMonth = (d.month == 12) ? DateTime(d.year + 1, 1, 1) : DateTime(d.year, d.month + 1, 1);
  final end = nextMonth.subtract(const Duration(days: 1));
  return (startDay: yyyyMmDd(start), endDay: yyyyMmDd(end));
}
