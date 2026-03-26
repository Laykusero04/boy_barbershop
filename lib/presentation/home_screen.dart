import 'package:flutter/material.dart';

import 'package:boy_barbershop/models/app_user.dart';
import 'package:boy_barbershop/presentation/screens/dashboard_screen.dart';

/// Kept for backward-compatibility; use [DashboardScreen] in the authenticated shell.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return DashboardScreen(user: user);
  }
}
