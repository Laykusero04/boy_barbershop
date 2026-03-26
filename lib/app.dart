import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/app_bloc.dart';
import 'package:boy_barbershop/bloc/app_event.dart';
import 'package:boy_barbershop/bloc/app_state.dart';
import 'package:boy_barbershop/presentation/app_shell.dart';
import 'package:boy_barbershop/presentation/login_screen.dart';
import 'package:boy_barbershop/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppBloc()..add(const AppStarted()),
      child: MaterialApp(
        title: 'Boy Barbershop',
        theme: AppTheme.light,
        home: BlocBuilder<AppBloc, AppState>(
          builder: (context, state) {
            return switch (state) {
              AppAuthenticated(:final user) => AppShell(user: user),
              AppInitial() ||
              AppLoading() ||
              AppUnauthenticated() =>
                const LoginScreen(),
            };
          },
        ),
      ),
    );
  }
}
