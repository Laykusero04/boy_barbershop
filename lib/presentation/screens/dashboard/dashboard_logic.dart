import 'package:boy_barbershop/models/barber.dart';
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

double computeBarberShareTotal({
  required List<Sale> sales,
  required Map<String, Barber> barberById,
}) {
  var total = 0.0;
  final dailyBarberDays = <String>{};
  // For guaranteedBase barbers, accumulate commission per barber per day
  // then compare with daily rate.
  final gbCommission = <String, double>{}; // key: barberId|day
  final gbBarbers = <String, Barber>{};

  for (final s in sales) {
    final b = barberById[s.barberId];
    if (b == null) continue;

    if (b.compensationType == BarberCompensationType.dailyRate) {
      final day = s.saleDay.trim();
      if (day.isEmpty) continue;
      final key = '${s.barberId}|$day';
      if (dailyBarberDays.add(key)) {
        total += b.dailyRate;
      }
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

  // For guaranteedBase: pay whichever is higher per day — commission or daily rate.
  for (final entry in gbCommission.entries) {
    final barberId = entry.key.split('|').first;
    final b = gbBarbers[barberId];
    if (b == null) continue;
    final commission = entry.value;
    total += commission > b.dailyRate ? commission : b.dailyRate;
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
}) {
  final salesTotal = sumSales(sales);
  final shareTotal = computeBarberShareTotal(sales: sales, barberById: barberById);
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

  final active = barbers.where((b) => b.isActive).toList(growable: false);
  final rows = <BarberEarningsRow>[];
  for (final b in active) {
    final totalSales = totals[b.id] ?? 0.0;
    final barberSales = sales.where((s) => s.barberId == b.id).toList();
    final double earnings;
    if (b.compensationType == BarberCompensationType.dailyRate) {
      final days = barberSales.map((s) => s.saleDay).where((d) => d.trim().isNotEmpty).toSet();
      earnings = barberSales.isEmpty ? 0.0 : b.dailyRate * days.length;
    } else if (b.compensationType == BarberCompensationType.guaranteedBase) {
      // Group sales by day, compute commission per day, take max(commission, dailyRate).
      final dayTotals = <String, double>{};
      for (final s in barberSales) {
        final day = s.saleDay.trim();
        if (day.isEmpty) continue;
        final base = s.ownerCoversDiscount ? (s.originalPrice ?? s.price) : s.price;
        dayTotals[day] = (dayTotals[day] ?? 0) + base * (b.percentageShare / 100.0);
      }
      var sum = 0.0;
      for (final commission in dayTotals.values) {
        sum += commission > b.dailyRate ? commission : b.dailyRate;
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
