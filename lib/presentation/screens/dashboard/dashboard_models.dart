import 'package:boy_barbershop/models/barber.dart';
import 'package:boy_barbershop/models/inventory_item.dart';
import 'package:boy_barbershop/models/sale.dart';

enum DashboardAlertType {
  belowDailyTarget,
  lowInventory,
}

class DashboardAlert {
  const DashboardAlert({
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final DashboardAlertType type;
  final String title;
  final String subtitle;
}

class DashboardKpis {
  const DashboardKpis({
    required this.customers,
    required this.sales,
    required this.barberShare,
    required this.expenses,
    required this.netProfitEstimate,
    required this.topBarberId,
    required this.topBarberSales,
  });

  final int customers;
  final double sales;
  final double barberShare;
  final double expenses;
  final double netProfitEstimate;
  final String? topBarberId;
  final double topBarberSales;
}

class BarberEarningsRow {
  const BarberEarningsRow({
    required this.barber,
    required this.totalSales,
    required this.earnings,
    required this.servicesCount,
  });

  final Barber barber;
  final double totalSales;
  final double earnings;
  final int servicesCount;
}

class DashboardTodayData {
  const DashboardTodayData({
    required this.dayManila,
    required this.sales,
    required this.expensesTotal,
    required this.kpis,
    required this.earningsRows,
    required this.lowStockItems,
  });

  final String dayManila;
  final List<Sale> sales;
  final double expensesTotal;
  final DashboardKpis kpis;
  final List<BarberEarningsRow> earningsRows;
  final List<InventoryItem> lowStockItems;
}

