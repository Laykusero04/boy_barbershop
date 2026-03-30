import 'package:boy_barbershop/models/sale.dart';
import 'package:boy_barbershop/utils/shop_time.dart';

class SalesKpis {
  const SalesKpis({
    required this.totalSales,
    required this.serviceCount,
    required this.averageTicket,
    required this.totalDiscounts,
    required this.promoCount,
    required this.promoUsageRate,
  });

  final double totalSales;
  final int serviceCount;
  final double averageTicket;
  final double totalDiscounts;
  final int promoCount;
  final double promoUsageRate;
}

class MoneyCountRow {
  const MoneyCountRow({
    required this.key,
    required this.count,
    required this.total,
  });

  final String key;
  final int count;
  final double total;

  double get average => count <= 0 ? 0 : total / count;
}

class PromoImpact {
  const PromoImpact({
    required this.withPromoCount,
    required this.withPromoTotal,
    required this.withoutPromoCount,
    required this.withoutPromoTotal,
  });

  final int withPromoCount;
  final double withPromoTotal;
  final int withoutPromoCount;
  final double withoutPromoTotal;

  double get avgWithPromo => withPromoCount <= 0 ? 0 : withPromoTotal / withPromoCount;
  double get avgWithoutPromo =>
      withoutPromoCount <= 0 ? 0 : withoutPromoTotal / withoutPromoCount;
}

SalesKpis computeSalesKpis(List<Sale> sales) {
  final total = sales.fold<double>(0, (s, e) => s + e.price);
  final count = sales.length;
  final avg = count <= 0 ? 0.0 : total / count;
  final discounts = sales.fold<double>(0, (s, e) => s + (e.discountAmount ?? 0.0));
  final promoCount = sales.where((s) => (s.promoId ?? '').trim().isNotEmpty).length;
  final promoRate = count <= 0 ? 0.0 : promoCount / count;
  return SalesKpis(
    totalSales: total,
    serviceCount: count,
    averageTicket: avg,
    totalDiscounts: discounts,
    promoCount: promoCount,
    promoUsageRate: promoRate,
  );
}

List<MoneyCountRow> groupSalesByServiceId(List<Sale> sales) {
  return _groupSalesByKey(sales, (s) => s.serviceId.trim().isEmpty ? 'Unknown' : s.serviceId.trim());
}

List<MoneyCountRow> groupSalesByBarberId(List<Sale> sales) {
  return _groupSalesByKey(sales, (s) => s.barberId.trim().isEmpty ? 'Unknown' : s.barberId.trim());
}

List<MoneyCountRow> groupSalesByPaymentMethod(List<Sale> sales) {
  return _groupSalesByKey(
    sales,
    (s) {
      final pm = (s.paymentMethod ?? '').trim();
      return pm.isEmpty ? 'Unspecified' : pm;
    },
  );
}

PromoImpact computePromoImpact(List<Sale> sales) {
  var withPromoCount = 0;
  var withPromoTotal = 0.0;
  var withoutPromoCount = 0;
  var withoutPromoTotal = 0.0;
  for (final s in sales) {
    final hasPromo = (s.promoId ?? '').trim().isNotEmpty;
    if (hasPromo) {
      withPromoCount++;
      withPromoTotal += s.price;
    } else {
      withoutPromoCount++;
      withoutPromoTotal += s.price;
    }
  }
  return PromoImpact(
    withPromoCount: withPromoCount,
    withPromoTotal: withPromoTotal,
    withoutPromoCount: withoutPromoCount,
    withoutPromoTotal: withoutPromoTotal,
  );
}

/// Returns a 24-element list (index 0..23), totals in pesos.
List<double> groupSalesByManilaHourTotals(List<Sale> sales) {
  final out = List<double>.filled(24, 0.0);
  for (final s in sales) {
    final dt = s.saleDateTime;
    if (dt == null) continue;
    final h = manilaHourOfInstant(dt);
    if (h < 0 || h > 23) continue;
    out[h] += s.price;
  }
  return out;
}

/// Returns a map weekday(1=Mon..7=Sun) -> totals.
Map<int, double> groupSalesByWeekdayFromSaleDay(List<Sale> sales) {
  final map = <int, double>{};
  for (final s in sales) {
    final d = parseYyyyMmDd(s.saleDay);
    if (d == null) continue;
    final wd = d.weekday; // 1..7
    map[wd] = (map[wd] ?? 0.0) + s.price;
  }
  return map;
}

List<MoneyCountRow> _groupSalesByKey(
  List<Sale> sales,
  String Function(Sale) keyOf,
) {
  final map = <String, MoneyCountRow>{};
  for (final s in sales) {
    final key = keyOf(s);
    final existing = map[key];
    if (existing == null) {
      map[key] = MoneyCountRow(key: key, count: 1, total: s.price);
    } else {
      map[key] = MoneyCountRow(
        key: key,
        count: existing.count + 1,
        total: existing.total + s.price,
      );
    }
  }
  final out = map.values.toList(growable: false);
  out.sort((a, b) => b.total.compareTo(a.total));
  return out;
}

