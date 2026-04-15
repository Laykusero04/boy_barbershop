import 'package:equatable/equatable.dart';

sealed class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched once at startup (session check, Firebase init hooks, etc.).
final class AppStarted extends AppEvent {
  const AppStarted();
}

final class AppLoginRequested extends AppEvent {
  const AppLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

final class AppLogoutRequested extends AppEvent {
  const AppLogoutRequested();
}

/// Re-fetches the user profile (e.g. after email change).
final class AppProfileRefreshRequested extends AppEvent {
  const AppProfileRefreshRequested();
}
