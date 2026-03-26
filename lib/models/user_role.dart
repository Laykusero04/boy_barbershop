/// Firestore `users.role` integer mapping.
enum UserRole {
  admin,
  cashier,
  barber;

  String get label => switch (this) {
        UserRole.admin => 'Admin',
        UserRole.cashier => 'Cashier',
        UserRole.barber => 'Barber',
      };

  /// Returns null if [value] is not a known role (fail closed).
  static UserRole? fromInt(int? value) {
    switch (value) {
      case 1:
        return UserRole.admin;
      case 2:
        return UserRole.cashier;
      case 3:
        return UserRole.barber;
      default:
        return null;
    }
  }
}
