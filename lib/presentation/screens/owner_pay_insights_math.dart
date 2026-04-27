import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/barber_shift.dart';
import 'package:boy_barbershop/models/expense.dart';
import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/presentation/screens/dashboard/dashboard_logic.dart';

/// One calendar month (yyyy-mm) aggregates for owner-pay math.
class MonthlyProfitRow {
  const MonthlyProfitRow({
    required this.yearMonth,
    required this.salesTotal,
    required this.barberShare,
    required this.expensesTotal,
  });

  final String yearMonth;
  final double salesTotal;
  final double barberShare;
  final double expensesTotal;

  double get netProfit => salesTotal - barberShare - expensesTotal;
}

/// Builds per-month sales, barber share, and expenses (Manila `sale_day` / `occurred_day`).
List<MonthlyProfitRow> buildMonthlyProfitRows({
  required List<Sale> sales,
  required List<Expense> expenses,
  required Map<String, Barber> barberById,
  required List<BarberShift> shifts,
  required double halfDayMultiplier,
}) {
  final byMonthSales = <String, List<Sale>>{};
  for (final s in sales) {
    final day = s.saleDay.trim();
    if (day.length < 7) continue;
    final ym = day.substring(0, 7);
    byMonthSales.putIfAbsent(ym, () => []).add(s);
  }

  final byMonthShifts = <String, List<BarberShift>>{};
  for (final s in shifts) {
    final day = s.occurredDay.trim();
    if (day.length < 7) continue;
    final ym = day.substring(0, 7);
    byMonthShifts.putIfAbsent(ym, () => []).add(s);
  }

  final byMonthExpenses = <String, double>{};
  for (final e in expenses) {
    final day = e.occurredDay.trim();
    if (day.length < 7) continue;
    final ym = day.substring(0, 7);
    byMonthExpenses[ym] = (byMonthExpenses[ym] ?? 0) + e.amount;
  }

  final months = {
    ...byMonthSales.keys,
    ...byMonthExpenses.keys,
    ...byMonthShifts.keys,
  }.toList()
    ..sort();
  final rows = <MonthlyProfitRow>[];
  for (final ym in months) {
    final monthSales = byMonthSales[ym] ?? const <Sale>[];
    final monthShifts = byMonthShifts[ym] ?? const <BarberShift>[];
    final salesTotal = monthSales.fold<double>(0, (a, s) => a + s.price);
    final share = computeBarberShareTotal(
      sales: monthSales,
      barberById: barberById,
      shifts: monthShifts,
      halfDayMultiplier: halfDayMultiplier,
    );
    final exp = byMonthExpenses[ym] ?? 0;
    rows.add(
      MonthlyProfitRow(
        yearMonth: ym,
        salesTotal: salesTotal,
        barberShare: share,
        expensesTotal: exp,
      ),
    );
  }
  return rows;
}

double sumMonthlyNet(List<MonthlyProfitRow> rows) =>
    rows.fold<double>(0, (a, r) => a + r.netProfit);

double averageMonthlyNet(List<MonthlyProfitRow> rows) {
  if (rows.isEmpty) return 0;
  return sumMonthlyNet(rows) / rows.length;
}

double averageMonthlySales(List<MonthlyProfitRow> rows) {
  if (rows.isEmpty) return 0;
  final t = rows.fold<double>(0, (a, r) => a + r.salesTotal);
  return t / rows.length;
}

/// Suggested monthly sales to hit [requiredMonthlyNetProfit] given historic margin.
double? requiredMonthlySalesForTarget({
  required double requiredMonthlyNetProfit,
  required double avgMonthlyNet,
  required double avgMonthlySales,
}) {
  if (requiredMonthlyNetProfit <= 0) return null;
  if (avgMonthlyNet <= 0 || avgMonthlySales <= 0) return null;
  final margin = avgMonthlyNet / avgMonthlySales;
  if (margin <= 0) return null;
  return requiredMonthlyNetProfit / margin;
}
