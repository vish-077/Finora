import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/entities/auth_session.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';

/// Contract for all authentication operations.
/// Implemented in the data layer over Firebase Authentication + secure local storage.
abstract interface class AuthRepository {
  /// Email/password sign-in. Persists the session securely on success.
  Future<Either<Failure, AuthSession>> signIn({
    required String email,
    required String password,
  });

  /// Registers a new account. Firebase sends a verification email.
  Future<Either<Failure, AuthUser>> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  /// Signs out remotely and wipes all local session material.
  Future<Either<Failure, Unit>> signOut();

  /// Attempts to restore a persisted session (auto-login on cold start).
  /// Returns Right(null) when there is nothing to restore.
  Future<Either<Failure, AuthSession?>> restoreSession();

  /// Sends a password-reset email.
  Future<Either<Failure, Unit>> sendPasswordReset(String email);

  /// Updates the current user's password (used on the reset screen).
  Future<Either<Failure, Unit>> updatePassword(String newPassword);

  /// Re-sends the email-verification message.
  Future<Either<Failure, Unit>> resendVerificationEmail(String email);

  /// Reloads the current user from the server (e.g. to re-check verification).
  Future<Either<Failure, AuthUser?>> refreshUser();

  /// The currently cached user, or null. Synchronous-friendly for guards.
  AuthUser? get currentUser;

  /// Emits on every auth state change (sign-in, sign-out, token refresh).
  Stream<AuthUser?> authStateChanges();

  // ── Biometric preference (per-device) ─────────────────────────────────────
  Future<Either<Failure, Unit>> setBiometricEnabled({required bool enabled});
  Future<bool> isBiometricEnabled();
}
