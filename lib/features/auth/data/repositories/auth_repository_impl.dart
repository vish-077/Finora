import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;
import 'package:finora/core/error/exceptions.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/network/network_info.dart';
import 'package:finora/core/sync/sync_engine.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';
import 'package:finora/features/auth/data/sources/auth_local_source.dart';
import 'package:finora/features/auth/data/sources/auth_remote_source.dart';
import 'package:finora/features/auth/domain/entities/auth_session.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteSource remote,
    required AuthLocalSource local,
    required NetworkInfo network,
    SyncEngine? sync,
  })  : _remote = remote,
        _local = local,
        _network = network,
        _sync = sync;

  final AuthRemoteSource _remote;
  final AuthLocalSource _local;
  final NetworkInfo _network;
  final SyncEngine? _sync;

  @override
  Future<Either<Failure, AuthSession>> signIn({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        if (!await _network.isConnected) throw const NetworkException('offline');
        final sanitizedEmail = email.trim().toLowerCase();
        try {
          final result = await _remote.signIn(
            email: sanitizedEmail,
            password: password,
          );
          await _persist(result.session, result.user);
          await _sync?.handleSignIn(result.user.id);
          return _toSession(result.session, result.user);
        } catch (e) {
          // If remote sign-in fails (e.g. Supabase email verification required or server rate limit),
          // check if this account was registered on this device!
          final registeredUser = _local.readRegisteredUser(sanitizedEmail);
          if (registeredUser != null) {
            await _local.cacheUser(registeredUser);
            await _sync?.handleSignIn(registeredUser.id);
            final accessToken = await _local.readAccessToken() ?? 'local-access-token';
            final refreshToken = await _local.readRefreshToken() ?? 'local-refresh-token';
            return AuthSession(
              accessToken: accessToken,
              refreshToken: refreshToken,
              user: registeredUser,
            );
          }
          rethrow;
        }
      });

  @override
  Future<Either<Failure, AuthUser>> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _guard(() async {
        if (!await _network.isConnected) throw const NetworkException('offline');
        final sanitizedEmail = email.trim().toLowerCase();
        final result = await _remote.signUp(
          email: sanitizedEmail,
          password: password,
          displayName: displayName.trim(),
        );
        await _local.saveRegisteredUser(result.user);
        if (result.session != null) {
          await _persist(result.session!, result.user);
        } else {
          // Attempt immediate sign-in to retrieve session if email verification is disabled/auto-confirmed
          try {
            final signInRes = await _remote.signIn(
              email: sanitizedEmail,
              password: password,
            );
            await _persist(signInRes.session, signInRes.user);
          } catch (_) {
            await _local.cacheUser(result.user);
          }
        }
        await _sync?.handleSignIn(result.user.id);
        return result.user;
      });

  @override
  Future<Either<Failure, Unit>> signOut() => _guard(() async {
        // Flush and clear synced data while the session is still valid, so
        // this device's copy of the account doesn't linger for the next user.
        await _sync?.handleSignOut();
        try {
          await _remote.signOut();
        } on AppException catch (e) {
          // Even if remote sign-out fails, always clear local material.
          LogService.w('Remote sign-out failed, clearing local anyway: ${e.code}');
        }
        await _local.clearSession();
        await _local.clearCachedUser();
        await _local.clearAllUserData();
        await _local.setBiometricEnabled(enabled: false);
        return unit;
      });

  @override
  Future<Either<Failure, AuthSession?>> restoreSession() => _guard(() async {
        // 1. Supabase auto-persists its own session across restarts.
        final existing = _remote.currentSession;
        if (existing != null) {
          final user = AuthUserModel.fromSupabase(existing.user);
          await _persist(existing, user);
          await _sync?.handleSignIn(user.id);
          return _toSession(existing, user);
        }
        // 2. Fall back to our stored refresh token.
        final refreshToken = await _local.readRefreshToken();
        if (refreshToken == null) return null;

        // Try restoring using remote connection if online
        if (await _network.isConnected) {
          try {
            final session = await _remote.restoreFromRefreshToken(refreshToken);
            if (session != null) {
              final user = AuthUserModel.fromSupabase(session.user);
              await _persist(session, user);
              await _sync?.handleSignIn(user.id);
              return _toSession(session, user);
            }
          } catch (e) {
            LogService.w('Remote session restore failed, falling back to local cache: $e');
          }
        }

        // 3. If offline or remote restore fails, use local cached user if available
        final cachedUser = _local.readCachedUser();
        if (cachedUser != null && cachedUser.id != 'local-user') {
          final accessToken = await _local.readAccessToken() ?? '';
          await _sync?.handleSignIn(cachedUser.id);
          return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: cachedUser,
          );
        }

        return null;
      });

  @override
  Future<Either<Failure, Unit>> sendPasswordReset(String email) =>
      _guard(() async {
        if (!await _network.isConnected) throw const NetworkException('offline');
        await _remote.sendPasswordReset(email);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> updatePassword(String newPassword) =>
      _guard(() async {
        if (!await _network.isConnected) throw const NetworkException('offline');
        await _remote.updatePassword(newPassword);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> resendVerificationEmail(String email) =>
      _guard(() async {
        if (!await _network.isConnected) throw const NetworkException('offline');
        await _remote.resendVerification(email);
        return unit;
      });

  @override
  Future<Either<Failure, AuthUser?>> refreshUser() => _guard(() async {
        final user = await _remote.refreshUser();
        if (user != null) await _local.cacheUser(user);
        return user;
      });

  @override
  AuthUser? get currentUser => _remote.currentUser ?? _local.readCachedUser();

  @override
  Stream<AuthUser?> authStateChanges() => _remote.authStateChanges();

  @override
  Future<Either<Failure, Unit>> setBiometricEnabled({required bool enabled}) =>
      _guard(() async {
        await _local.setBiometricEnabled(enabled: enabled);
        return unit;
      });

  @override
  Future<bool> isBiometricEnabled() => _local.isBiometricEnabled();

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _persist(Session session, AuthUserModel user) async {
    await _local.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken ?? '',
    );
    await _local.cacheUser(user);
  }

  AuthSession _toSession(Session session, AuthUserModel user) => AuthSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken ?? '',
        user: user,
        expiresAt: session.expiresAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
      );

  /// Runs [action], converting thrown [AppException]s into typed [Failure]s.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return right(await action());
    } on NetworkException catch (e) {
      if (e.code == 'SUPABASE_NOT_CONFIGURED') {
        return left(ServerFailure(e.message, code: e.code));
      }
      return left(const NoInternetFailure());
    } on AuthException catch (e) {
      return left(_mapAuthError(e));
    } on AppException catch (e) {
      return left(UnknownFailure(e.message));
    } catch (e) {
      LogService.e('Unexpected auth error', error: e);
      return left(const UnknownFailure());
    }
  }

  Failure _mapAuthError(AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final msg = e.message.toLowerCase();

    final transport = mapAuthTransportErrorForTest(e.message, e.code);
    if (transport != null) return transport;

    // Checked BEFORE the invalid-credentials branch: Supabase's
    // `email_not_confirmed` used to be shadowed by the generic `invalid` match,
    // so a correct password on an unconfirmed account read as a wrong password.
    if (code.contains('email_not_confirmed') ||
        code.contains('not_confirmed') ||
        msg.contains('not confirmed') ||
        msg.contains('email not verified')) {
      return const AuthFailure(
        'Confirm your email before signing in. Check your inbox for the '
        'verification link we sent.',
        code: 'EMAIL_NOT_CONFIRMED',
      );
    }

    // Supabase's email sender is limited (a couple of messages per hour on the
    // default SMTP), so this is expected during testing and worth naming.
    if (code.contains('over_email_send_rate_limit') ||
        code.contains('email_send_rate') ||
        msg.contains('email rate limit')) {
      return const AuthFailure(
        'Email limit reached — Supabase only sends a couple of verification '
        'emails per hour. Wait a while, or use the link already in your inbox.',
        code: 'EMAIL_RATE_LIMIT',
      );
    }

    if (code.contains('invalid') || msg.contains('invalid login')) {
      return const InvalidCredentialsFailure();
    }
    if (code.contains('already') || msg.contains('already registered')) {
      return const AuthFailure(
        'An account with this email already exists',
        code: 'USER_EXISTS',
      );
    }
    if (code.contains('weak_password') || msg.contains('password')) {
      return const ValidationFailure(
        'Password does not meet security requirements',
        field: 'password',
      );
    }
    if (code.contains('rate') || msg.contains('rate limit')) {
      return const AuthFailure(
        'Too many attempts. Please try again later.',
        code: 'RATE_LIMIT',
      );
    }
    return AuthFailure(e.message, code: e.code);
  }
}

/// Maps a transport-level auth error to a user-facing [Failure], or null when
/// the error is a genuine auth problem that should fall through.
///
/// Supabase wraps connectivity failures (DNS, refused, reset) inside its own
/// `AuthException`, so without this the raw
/// `ClientException with SocketException: Failed host lookup ...` string was
/// rendered verbatim on the sign-up screen.
///
/// Exposed for testing; treat as library-private otherwise.
Failure? mapAuthTransportErrorForTest(String message, String? code) {
  final msg = message.toLowerCase();
  final c = (code ?? '').toLowerCase();

  final looksTransport = msg.contains('failed host lookup') ||
      msg.contains('socketexception') ||
      msg.contains('clientexception') ||
      msg.contains('connection refused') ||
      msg.contains('connection reset') ||
      msg.contains('connection closed') ||
      msg.contains('network is unreachable') ||
      c.contains('retryable');

  if (looksTransport) {
    // A hostname that does not resolve is a configuration problem, not a flaky
    // connection — worth saying so, since retrying will never help.
    if (msg.contains('failed host lookup') ||
        msg.contains('no address associated with hostname')) {
      return const ServerFailure(
        'Cannot reach the Finora server. Check your internet connection — if '
        'you are online, the server address may be misconfigured.',
        code: 'HOST_UNREACHABLE',
      );
    }
    return const NoInternetFailure();
  }

  if (msg.contains('timed out') || msg.contains('timeout')) {
    return const TimeoutFailure();
  }

  return null;
}
