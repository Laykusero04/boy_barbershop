import 'package:flutter/material.dart';
import 'package:boy_barbershop/components/login_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorText;

  Future<void> _login({required String email, required String password}) async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // Hook your auth here (Firebase Auth, API, etc).
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in as $email')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorText = 'Login failed. Try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  isLoading: _isLoading,
                  errorText: _errorText,
                  onSubmit: ({required email, required password}) =>
                      _login(email: email, password: password),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
