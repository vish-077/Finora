import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/config/app_config.dart';
import 'package:finora/core/constants/app_constants.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';

part 'auth_form_controllers.g.dart';

/// Each controller exposes an `AsyncValue<void>` operation state
/// (idle = AsyncData(null), loading = AsyncLoading, failed = AsyncError)
/// and a `submit`-style method returning `true` on success so the page
/// can navigate.

@riverpod
class LoginController extends _$LoginController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();

    // ── Dev test account bypass (debug builds only) ─────────────────────────
    // Signs in instantly without Firebase / email verification.
    if (AppConfig.isDevelopment &&
        email.trim().toLowerCase() == AppConstants.devTestEmail &&
        password == AppConstants.devTestPassword) {
      const user = AuthUserModel(
        id: 'dev-test-user',
        email: AppConstants.devTestEmail,
        displayName: 'Test User',
        isEmailVerified: true,
      );
      await ref.read(authLocalSourceProvider).saveSession(
            accessToken: 'dev-test-token',
            refreshToken: 'dev-test-refresh-token',
          );
      await ref.read(authLocalSourceProvider).cacheUser(user);
      ref.read(authControllerProvider.notifier).onAuthenticated(user);
      state = const AsyncData(null);
      return true;
    }

    final result = await ref.read(signInUseCaseProvider)(
      email: email,
      password: password,
    );
    return result.match(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (session) {
        ref.read(authControllerProvider.notifier).onAuthenticated(session.user);
        state = const AsyncData(null);
        return true;
      },
    );
  }

  /// Biometric unlock → restore the persisted session.
  Future<bool> loginWithBiometrics() async {
    state = const AsyncLoading();
    final result = await ref.read(authenticateBiometricUseCaseProvider)(
      reason: 'Unlock FINORA',
    );
    return result.match(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return Future.value(false);
      },
      (ok) async {
        if (!ok) {
          state = const AsyncData(null);
          return false;
        }
        await ref.read(authControllerProvider.notifier).restoreSession();
        state = const AsyncData(null);
        return ref.read(authControllerProvider).isAuthenticated;
      },
    );
  }
}

@riverpod
class RegisterController extends _$RegisterController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    final result = await ref.read(signUpUseCaseProvider)(
      email: email,
      password: password,
      displayName: displayName,
    );
    return result.match(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (user) {
        ref.read(authControllerProvider.notifier).onRegistered(user);
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

@riverpod
class ForgotPasswordController extends _$ForgotPasswordController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(String email) async {
    state = const AsyncLoading();
    final result = await ref.read(sendPasswordResetUseCaseProvider)(email);
    return result.match(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

@riverpod
class ResetPasswordController extends _$ResetPasswordController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(String newPassword) async {
    state = const AsyncLoading();
    final result = await ref.read(updatePasswordUseCaseProvider)(newPassword);
    return result.match(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}

@riverpod
class ResendVerificationController extends _$ResendVerificationController {
  @override
  FutureOr<void> build() {}

  Future<bool> submit(String email) async {
    state = const AsyncLoading();
    final result = await ref.read(resendVerificationUseCaseProvider)(email);
    return result.match(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncData(null);
        return true;
      },
    );
  }
}
