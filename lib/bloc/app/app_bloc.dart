import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:boy_barbershop/bloc/app/app_event.dart';
import 'package:boy_barbershop/bloc/app/app_state.dart';
import 'package:boy_barbershop/data/user_profile_repository.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppLoading()) {
    on<AppStarted>(_onStarted);
    on<AppLoginRequested>(_onLoginRequested);
    on<AppLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onStarted(AppStarted event, Emitter<AppState> emit) async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current == null) {
      emit(const AppUnauthenticated());
      return;
    }
    try {
      final profile = await fetchUserProfile(current.uid);
      if (profile == null) {
        await auth.signOut();
        emit(
          const AppUnauthenticated(
            loginError:
                'Account profile not found. Contact an administrator.',
          ),
        );
        return;
      }
      emit(AppAuthenticated(user: profile));
    } on UserProfileLoadException catch (e) {
      await auth.signOut();
      emit(AppUnauthenticated(loginError: e.message));
    } on Object {
      await auth.signOut();
      emit(
        const AppUnauthenticated(
          loginError: 'Could not load your profile. Try again.',
        ),
      );
    }
  }

  Future<void> _onLoginRequested(
    AppLoginRequested event,
    Emitter<AppState> emit,
  ) async {
    emit(const AppLoading());
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: event.email.trim(),
        password: event.password,
      );
      final uid = cred.user?.uid;
      if (uid == null) {
        emit(const AppUnauthenticated(loginError: 'Login failed. Try again.'));
        return;
      }
      final profile = await fetchUserProfile(uid);
      if (profile == null) {
        await FirebaseAuth.instance.signOut();
        emit(
          const AppUnauthenticated(
            loginError:
                'Account profile not found. Contact an administrator.',
          ),
        );
        return;
      }
      emit(AppAuthenticated(user: profile));
    } on FirebaseAuthException catch (e) {
      emit(AppUnauthenticated(loginError: _authErrorMessage(e)));
    } on UserProfileLoadException catch (e) {
      await FirebaseAuth.instance.signOut();
      emit(AppUnauthenticated(loginError: e.message));
    } on Object {
      emit(
        const AppUnauthenticated(
          loginError: 'Could not load your profile. Try again.',
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    AppLogoutRequested event,
    Emitter<AppState> emit,
  ) async {
    await FirebaseAuth.instance.signOut();
    emit(const AppUnauthenticated());
  }

  static String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      default:
        return 'Login failed. Try again.';
    }
  }
}
