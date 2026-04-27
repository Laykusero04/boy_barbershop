import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/app/app_bloc.dart';
import 'package:boy_barbershop/bloc/app/app_event.dart';
import 'package:boy_barbershop/bloc/app/app_state.dart';
import 'package:boy_barbershop/data/barbers_repository.dart';
import 'package:boy_barbershop/data/cashflow_repository.dart';
import 'package:boy_barbershop/data/catalog_repository.dart';
import 'package:boy_barbershop/data/expenses_repository.dart';
import 'package:boy_barbershop/data/admin_repository.dart';
import 'package:boy_barbershop/data/barber_shifts_repository.dart';
import 'package:boy_barbershop/data/disputes_repository.dart';
import 'package:boy_barbershop/data/inventory_repository.dart';
import 'package:boy_barbershop/data/payment_methods_repository.dart';
import 'package:boy_barbershop/data/promos_repository.dart';
import 'package:boy_barbershop/data/sales_repository.dart';
import 'package:boy_barbershop/data/services_repository.dart';
import 'package:boy_barbershop/data/settings_repository.dart';
import 'package:boy_barbershop/presentation/app_shell.dart';
import 'package:boy_barbershop/presentation/login_screen.dart';
import 'package:boy_barbershop/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cashflowRepo = CashflowRepository();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => BarbersRepository()),
        RepositoryProvider(create: (_) => ServicesRepository()),
        RepositoryProvider(create: (_) => InventoryRepository()),
        RepositoryProvider(create: (_) => PaymentMethodsRepository()),
        RepositoryProvider(create: (_) => PromosRepository()),
        RepositoryProvider(create: (_) => CatalogRepository()),
        RepositoryProvider(create: (_) => SettingsRepository()),
        RepositoryProvider(create: (_) => cashflowRepo),
        RepositoryProvider(
          create: (_) => SalesRepository(cashflow: cashflowRepo),
        ),
        RepositoryProvider(
          create: (_) => ExpensesRepository(cashflow: cashflowRepo),
        ),
        RepositoryProvider(create: (_) => AdminRepository()),
        RepositoryProvider(create: (_) => DisputesRepository()),
        RepositoryProvider(create: (_) => BarberShiftsRepository()),
      ],
      child: BlocProvider(
        create: (_) => AppBloc()..add(const AppStarted()),
        child: MaterialApp(
          title: 'Boy Barbershop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          themeMode: ThemeMode.light,
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
      ),
    );
  }
}
