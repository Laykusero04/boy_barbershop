import 'package:flutter/material.dart';

import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/presentation/screens/dashboard_screen.dart';

/// Kept for backward-compatibility; use [DashboardScreen] in the authenticated shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user, required this.goToDestination});

  final AppUser user;
  final void Function(String destinationId) goToDestination;

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(user: user, goToDestination: goToDestination);
  }
}
