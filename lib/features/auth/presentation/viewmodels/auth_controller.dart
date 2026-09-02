import 'package:equatable/equatable.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/sync/sync_providers.dart';
import 'package:finora/core/sync/sync_scope.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';

part 'auth_controller.g.dart';

enum AuthStatus { unknown, authenticated, unverified, unauthenticated }

class AuthState extends Equatable {
  const AuthState(this.status, {this.user});

  const AuthState.unknown() : this(AuthStatus.unknown);

  final AuthStatus status;
  final AuthUser? user;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnverified => status == AuthStatus.unverified;
  bool get isResolved => status != AuthStatus.unknown;

  @override
  List<Object?> get props => [status, user];
}

/// Global authentication state. Drives GoRouter redirects and auto-login.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthState build() {
    // Kick off session restore (auto-login) without blocking first frame.
    Future.microtask(restoreSession);
    return const AuthState.unknown();
  }

  /// Auto-login on cold start.
  Future<void> restoreSession() async {
    final result = await ref.read(restoreSessionUseCaseProvider)();
    state = result.match(
      (_) => const AuthState(AuthStatus.unauthenticated),
      (session) => session == null
          ? const AuthState(AuthStatus.unauthenticated)
          : AuthState(AuthStatus.authenticated, user: session.user),
    );
  }

  /// Called after a successful sign-in / biometric unlock.
  void onAuthenticated(AuthUser user) =>
      state = AuthState(AuthStatus.authenticated, user: user);

  /// Called after registration. Bypasses verification block and authenticates user directly.
  void onRegistered(AuthUser user) => state = AuthState(
        AuthStatus.authenticated,
        user: user,
      );

  Future<void> continueAsGuest() async {
    // Hand the local boxes to the guest scope *before* showing any screen:
    // otherwise guest would render whatever the last signed-in account left
    // behind. The previous owner's rows are stashed, not deleted.
    await ref.read(syncEngineProvider)?.enterGuestMode();

    const guestUser = AuthUserModel(
      id: SyncScope.guest,
      email: 'guest@finora.local',
      displayName: 'Guest User',
      isEmailVerified: true,
    );
    await ref.read(authLocalSourceProvider).saveSession(
          accessToken: 'local-guest-token',
          refreshToken: 'local-guest-refresh-token',
        );
    await ref.read(authLocalSourceProvider).cacheUser(guestUser);
    state = const AuthState(AuthStatus.authenticated, user: guestUser);
  }

  Future<void> signOut() async {
    await ref.read(signOutUseCaseProvider)();
    state = const AuthState(AuthStatus.unauthenticated);
  }

  /// Re-checks verification status (e.g. after user taps the email link).
  Future<void> refreshUser() async {
    final result = await ref.read(authRepositoryProvider).refreshUser();
    result.match((_) {}, (user) {
      if (user != null) {
        state = AuthState(
          user.isEmailVerified
              ? AuthStatus.authenticated
              : AuthStatus.unverified,
          user: user,
        );
      }
    });
  }
}
