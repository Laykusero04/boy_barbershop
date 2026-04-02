import 'package:equatable/equatable.dart';

import 'package:boy_barbershop/models/app_user.dart';

sealed class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

/// First frame before [AppStarted] completes (optional loading splash).
final class AppInitial extends AppState {
  const AppInitial();
}

/// Session resolved: user must sign in.
final class AppUnauthenticated extends AppState {
  const AppUnauthenticated({this.loginError});

  /// Shown on the login form after a failed attempt.
  final String? loginError;

  @override
  List<Object?> get props => [loginError];
}

/// Login (or restore session) in progress.
final class AppLoading extends AppState {
  const AppLoading();
}

/// Signed-in user with Firestore profile and role.
final class AppAuthenticated extends AppState {
  const AppAuthenticated({required this.user});

  final AppUser user;

  @override
  List<Object?> get props => [user];
}
