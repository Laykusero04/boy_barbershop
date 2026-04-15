import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/barbers/barbers_cubit.dart';
import 'package:boy_barbershop/bloc/inventory/inventory_cubit.dart';
import 'package:boy_barbershop/bloc/payment_methods/payment_methods_cubit.dart';
import 'package:boy_barbershop/bloc/promos/promos_cubit.dart';
import 'package:boy_barbershop/bloc/services/services_cubit.dart';
import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/data/inventory_repository.dart';
import 'package:boy_barbershop/data/payment_methods_repository.dart';
import 'package:boy_barbershop/data/promos_repository.dart';
import 'package:boy_barbershop/data/services_repository.dart';
import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/models/user_role.dart';
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
import 'package:boy_barbershop/presentation/admin/users_management_screen.dart';
import 'package:boy_barbershop/presentation/admin/audit_log_screen.dart';
import 'package:boy_barbershop/presentation/admin/sale_disputes_screen.dart';
import 'package:boy_barbershop/utils/role_guard.dart';

enum AppDestinationGroup { operations, money, insights, stock, account, admin }

typedef DestinationBuilder = Widget Function(
  BuildContext context,
  AppUser user,
  void Function(String destinationId) goToDestination,
);

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
    builder: (context, user, goToDestination) =>
        DashboardScreen(user: user, goToDestination: goToDestination),
  ),
  AppDestination(
    id: 'add_sale',
    title: 'Add sale',
    icon: Icons.add_circle_outline_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user, _) => AddSaleScreen(user: user),
  ),
  AppDestination(
    id: 'barbers',
    title: 'Barbers',
    icon: Icons.badge_outlined,
    group: AppDestinationGroup.operations,
    builder: (context, user, _) => BlocProvider(
      create: (ctx) =>
          BarbersCubit(ctx.read<BarbersRepository>())..watch(),
      child: const BarbersScreen(),
    ),
  ),
  AppDestination(
    id: 'services',
    title: 'Services',
    icon: Icons.content_cut_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user, _) => BlocProvider(
      create: (ctx) =>
          ServicesCubit(ctx.read<ServicesRepository>())..watch(),
      child: const ServicesScreen(),
    ),
  ),
  AppDestination(
    id: 'payment_methods',
    title: 'Payment methods',
    icon: Icons.credit_card_rounded,
    group: AppDestinationGroup.operations,
    builder: (context, user, _) => BlocProvider(
      create: (ctx) =>
          PaymentMethodsCubit(ctx.read<PaymentMethodsRepository>())..watch(),
      child: const PaymentMethodsScreen(),
    ),
  ),
  AppDestination(
    id: 'promos',
    title: 'Promos',
    icon: Icons.local_offer_outlined,
    group: AppDestinationGroup.operations,
    builder: (context, user, _) => BlocProvider(
      create: (ctx) =>
          PromosCubit(ctx.read<PromosRepository>())..watch(),
      child: const PromosScreen(),
    ),
  ),
  AppDestination(
    id: 'cash_flow',
    title: 'Cash flow',
    icon: Icons.payments_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user, _) => CashflowScreen(user: user),
  ),
  AppDestination(
    id: 'expenses',
    title: 'Expenses',
    icon: Icons.receipt_long_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user, _) => ExpensesScreen(user: user),
  ),
  AppDestination(
    id: 'investments',
    title: 'Investments',
    icon: Icons.savings_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user, _) => InvestmentsScreen(user: user),
  ),
  AppDestination(
    id: 'reports',
    title: 'Reports',
    icon: Icons.description_outlined,
    group: AppDestinationGroup.money,
    builder: (context, user, _) => ReportsScreen(user: user),
  ),
  AppDestination(
    id: 'sales_intelligence',
    title: 'Sales Intelligence',
    icon: Icons.show_chart_rounded,
    group: AppDestinationGroup.insights,
    builder: (context, user, _) => SalesIntelligenceScreen(user: user),
  ),
  AppDestination(
    id: 'owner_pay',
    title: 'Owner pay & insights',
    icon: Icons.account_balance_wallet_outlined,
    group: AppDestinationGroup.insights,
    builder: (context, user, goToDestination) =>
        OwnerPayScreen(user: user, onNavigateToDestination: goToDestination),
  ),
  AppDestination(
    id: 'activity_by_hour',
    title: 'Activity (by hour)',
    icon: Icons.schedule_outlined,
    group: AppDestinationGroup.insights,
    builder: (context, user, _) => ActivityByHourScreen(user: user),
  ),
  AppDestination(
    id: 'peak_and_daily_target',
    title: 'Peak & Daily Target',
    icon: Icons.trending_up_rounded,
    group: AppDestinationGroup.insights,
    builder: (context, user, _) => PeakAndDailyTargetScreen(user: user),
  ),
  AppDestination(
    id: 'inventory',
    title: 'Inventory',
    icon: Icons.inventory_2_outlined,
    group: AppDestinationGroup.stock,
    builder: (context, user, _) => BlocProvider(
      create: (ctx) =>
          InventoryCubit(ctx.read<InventoryRepository>())..watch(),
      child: const InventoryScreen(),
    ),
  ),
  AppDestination(
    id: 'profile',
    title: 'Profile',
    icon: Icons.person_outline_rounded,
    group: AppDestinationGroup.account,
    builder: (context, user, _) => ProfileScreen(user: user),
  ),
  AppDestination(
    id: 'settings',
    title: 'Settings',
    icon: Icons.settings_outlined,
    group: AppDestinationGroup.account,
    builder: (context, user, _) => const SettingsScreen(),
  ),

  // ── Admin-only ─────────────────────────────────────────────────────
  AppDestination(
    id: 'users_management',
    title: 'Manage users',
    icon: Icons.supervised_user_circle_outlined,
    group: AppDestinationGroup.admin,
    builder: (context, user, _) => UsersManagementScreen(user: user),
  ),
  AppDestination(
    id: 'sale_disputes',
    title: 'Sale disputes',
    icon: Icons.report_outlined,
    group: AppDestinationGroup.admin,
    builder: (context, user, _) => SaleDisputesScreen(user: user),
  ),
  AppDestination(
    id: 'audit_log',
    title: 'Audit log',
    icon: Icons.history_outlined,
    group: AppDestinationGroup.admin,
    builder: (context, user, _) => AuditLogScreen(user: user),
  ),
];

/// Returns the full destination list filtered for [role].
List<AppDestination> destinationsForRole(UserRole role) {
  final allowed = RoleGuard.allowedDestinations(role);
  return appDestinations.where((d) => allowed.contains(d.id)).toList();
}

AppDestination destinationById(String id) {
  return appDestinations.firstWhere((d) => d.id == id);
}
