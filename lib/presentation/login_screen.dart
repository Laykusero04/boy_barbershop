import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/app_bloc.dart';
import 'package:boy_barbershop/bloc/app_event.dart';
import 'package:boy_barbershop/bloc/app_state.dart';
import 'package:boy_barbershop/components/login_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      buildWhen: (previous, current) =>
          current is AppLoading ||
          current is AppUnauthenticated ||
          current is AppInitial,
      builder: (context, state) {
        final isLoading = state is AppLoading;
        final errorText =
            state is AppUnauthenticated ? state.loginError : null;

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Image.asset(
                        'images/boy_logo.png',
                        width: 140,
                        height: 140,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Login',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    LoginForm(
                      isLoading: isLoading,
                      errorText: errorText,
                      onSubmit: ({required email, required password}) async {
                        context.read<AppBloc>().add(
                              AppLoginRequested(
                                email: email,
                                password: password,
                              ),
                            );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
