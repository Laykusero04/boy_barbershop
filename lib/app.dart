import 'package:flutter/material.dart';
import 'package:boy_barbershop/presentation/login_screen.dart';
import 'package:boy_barbershop/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boy Barbershop',
      theme: AppTheme.light,
      home: const LoginScreen(),
    );
  }
}