import 'package:flutter/material.dart';

import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/presentation/screens/dashboard_screen.dart';
import 'package:boy_barbershop/presentation/screens/add_sale_screen.dart';
import 'package:boy_barbershop/presentation/screens/activity_by_hour_screen.dart';
import 'package:boy_barbershop/presentation/screens/barbers_screen.dart';
import 'package:boy_barbershop/presentation/screens/cashflow_screen.dart';
import 'package:boy_barbershop/presentation/screens/expenses_screen.dart';
import 'package:boy_barbershop/presentation/screens/investments_screen.dart';
import 'package:boy_barbershop/presentation/screens/inventory_screen.dart';
import 'package:boy_barbershop/presentation/screens/owner_pay_screen.dart';
import 'package:boy_barbershop/presentation/screens/payment_methods_screen.dart';
import 'package:boy_barbershop/presentation/screens/peak_and_daily_target_screen.dart';
import 'package:boy_barbershop/presentation/screens/profile_screen.dart';
import 'package:boy_barbershop/presentation/screens/promos_screen.dart';
import 'package:boy_barbershop/presentation/screens/reports_screen.dart';
import 'package:boy_barbershop/presentation/screens/sales_intelligence_screen.dart';
import 'package:boy_barbershop/presentation/screens/services_screen.dart';
import 'package:boy_barbershop/presentation/screens/settings_screen.dart';

enum AppDestinationGroup { operations, money, insights, stock, account }

typedef DestinationBuilder = Widget Function(BuildContext context, AppUser user);

class AppDestination {
  const AppDestination({
    required this.id,
    required this.title,
    required this.icon,
    required this.group,
    required this.builder,
  });

  final String id;
  final String title;
  final IconData icon;
  final AppDestinationGroup group;
  final DestinationBuilder builder;
}

final List<AppDestination> appDestinations = [
  AppDestination(
    id: 'dashboard',
    title: 'Dashboard',
    icon: Icons.home_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user) => DashboardScreen(user: user),
  ),
  AppDestination(
    id: 'add_sale',
    title: 'Add sale',
    icon: Icons.add_circle_outline_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user) => AddSaleScreen(user: user),
  ),
  AppDestination(
    id: 'barbers',
    title: 'Barbers',
    icon: Icons.badge_outlined,
    group: AppDestinationGroup.operations,
    builder: (context, user) => const BarbersScreen(),
  ),
  AppDestination(
    id: 'services',
    title: 'Services',
    icon: Icons.content_cut_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user) => const ServicesScreen(),
  ),
  AppDestination(
    id: 'payment_methods',
    title: 'Payment methods',
    icon: Icons.credit_card_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user) => const PaymentMethodsScreen(),
  ),
  AppDestination(
    id: 'promos',
    title: 'Promos',
    icon: Icons.local_offer_outlined,
    group: AppDestinationGroup.operations,
    builder: (context, user) => const PromosScreen(),
  ),
  AppDestination(
    id: 'cash_flow',
    title: 'Cash flow',
    icon: Icons.payments_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user) => CashflowScreen(user: user),
  ),
  AppDestination(
    id: 'expenses',
    title: 'Expenses',
    icon: Icons.receipt_long_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user) => ExpensesScreen(user: user),
  ),
  AppDestination(
    id: 'investments',
    title: 'Investments',
    icon: Icons.savings_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user) => InvestmentsScreen(user: user),
  ),
  AppDestination(
    id: 'reports',
    title: 'Reports',
    icon: Icons.description_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user) => ReportsScreen(user: user),
  ),
  AppDestination(
    id: 'sales_intelligence',
    title: 'Sales Intelligence',
    icon: Icons.show_chart_rounded,
    group: AppDestinationGroup.insights,
    builder: (context, user) => SalesIntelligenceScreen(user: user),
  ),
  AppDestination(
    id: 'owner_pay',
    title: 'Owner pay & insights',
    icon: Icons.account_balance_wallet_outlined,
    group: AppDestinationGroup.insights,
    builder: (context, user) => OwnerPayScreen(user: user),
  ),
  AppDestination(
    id: 'activity_by_hour',
    title: 'Activity (by hour)',
    icon: Icons.schedule_outlined,
    group: AppDestinationGroup.insights,
    builder: (context, user) => ActivityByHourScreen(user: user),
  ),
  AppDestination(
    id: 'peak_and_daily_target',
    title: 'Peak & Daily Target',
    icon: Icons.trending_up_rounded,
    group: AppDestinationGroup.insights,
    builder: (context, user) => PeakAndDailyTargetScreen(user: user),
  ),
  AppDestination(
    id: 'inventory',
    title: 'Inventory',
    icon: Icons.inventory_2_outlined,
    group: AppDestinationGroup.stock,
    builder: (context, user) => const InventoryScreen(),
  ),
  AppDestination(
    id: 'profile',
    title: 'Profile',
    icon: Icons.person_outline_rounded,
    group: AppDestinationGroup.account,
    builder: (context, user) => ProfileScreen(user: user),
  ),
  AppDestination(
    id: 'settings',
    title: 'Settings',
    icon: Icons.settings_outlined,
    group: AppDestinationGroup.account,
    builder: (context, user) => const SettingsScreen(),
  ),
];

AppDestination destinationById(String id) {
  return appDestinations.firstWhere((d) => d.id == id);
}

