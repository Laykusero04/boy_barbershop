import 'package:boy_barbershop/models/user_role.dart';

/// Defines which destination IDs each role can access.
///
/// Admin  – full access to everything.
/// Cashier – daily operations + own profile.
/// Barber  – minimal view (dashboard, add sale, profile).
abstract final class RoleGuard {
  RoleGuard._();

  /// Destination IDs available to [role].
  static Set<String> allowedDestinations(UserRole role) {
    return switch (role) {
      UserRole.admin => _adminDestinations,
      UserRole.cashier => _cashierDestinations,
      UserRole.barber => _barberDestinations,
    };
  }

  /// Returns `true` when [role] may view [destinationId].
  static bool canAccess(UserRole role, String destinationId) {
    return allowedDestinations(role).contains(destinationId);
  }

  // ── Admin: everything ──────────────────────────────────────────────
  static const _adminDestinations = <String>{
    // operations
    'dashboard',
    'add_sale',
    'barbers',
    'services',
    'payment_methods',
    'promos',
    // money
    'cash_flow',
    'expenses',
    'investments',
    'reports',
    // insights
    'sales_intelligence',
    'owner_pay',
    'activity_by_hour',
    'peak_and_daily_target',
    // stock
    'inventory',
    // account
    'profile',
    'settings',
    // admin-only
    'users_management',
    'sale_disputes',
    'audit_log',
  };

  // ── Cashier: add sales + dashboard overview ─────────────────────────
  static const _cashierDestinations = <String>{
    'dashboard',
    'add_sale',
    'profile',
  };

  // ── Barber: dashboard only ─────────────────────────────────────────
  static const _barberDestinations = <String>{
    'dashboard',
    'profile',
  };
}
