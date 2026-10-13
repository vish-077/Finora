import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:finora/core/error/exceptions.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';

/// A signed-in Firebase session, in the shape the rest of the app expects.
class RemoteSession {
  const RemoteSession({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  /// Firebase ID token (empty when it could not be fetched, e.g. offline).
  final String accessToken;

  /// Firebase does not expose refresh tokens on native platforms, so this is
  /// usually empty; it only serves as a "has signed in on this device" marker.
  final String? refreshToken;

  final DateTime? expiresAt;
}

/// Thin wrapper over Firebase Auth. Throws typed [AppException]s that the
/// repository maps to [Failure]s. A null client means Firebase isn't
/// configured (no `google-services.json`) — every call then fails cleanly.
abstract interface class AuthRemoteSource {
  Future<({AuthUserModel user, RemoteSession session})> signIn({
    required String email,
    required String password,
  });

  Future<({AuthUserModel user, RemoteSession? session})> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  /// The session Firebase restored from disk on launch, or null if signed out.
  Future<RemoteSession?> restoreSession();

  AuthUserModel? get currentUser;

  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> resendVerification(String email);
  Future<AuthUserModel?> refreshUser();

  Stream<AuthUserModel?> authStateChanges();
}

class AuthRemoteSourceImpl implements AuthRemoteSource {
  AuthRemoteSourceImpl(this._client);

  final fb.FirebaseAuth? _client;

  fb.FirebaseAuth get _auth {
    final c = _client;
    if (c == null) {
      throw const NetworkException(
        'Authentication service is not configured',
        code: 'FIREBASE_NOT_CONFIGURED',
      );
    }
    return c;
  }

  @override
  Future<({AuthUserModel user, RemoteSession session})> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthException('Sign-in failed', code: 'NO_SESSION');
      }
      return (
        user: AuthUserModel.fromFirebase(user),
        session: await _sessionFor(user),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Future<({AuthUserModel user, RemoteSession? session})> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthException('Sign-up failed', code: 'NO_USER');
      }
      await user.updateDisplayName(displayName.trim());
      try {
        await user.sendEmailVerification();
      } on fb.FirebaseAuthException {
        // The account exists; the user can resend from the verification page.
      }
      await user.reload();
      final fresh = _auth.currentUser ?? user;
      return (
        user: AuthUserModel.fromFirebase(fresh),
        session: await _sessionFor(fresh),
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Future<RemoteSession?> restoreSession() async {
    final user = _client?.currentUser;
    if (user == null) return null;
    return _sessionFor(user);
  }

  @override
  AuthUserModel? get currentUser {
    final u = _client?.currentUser;
    return u == null ? null : AuthUserModel.fromFirebase(u);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException(
        'Sign in again to change your password',
        code: 'requires_recent_login',
      );
    }
    try {
      await user.updatePassword(newPassword);
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('Sign in to resend the verification email',
          code: 'no_current_user');
    }
    try {
      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Future<AuthUserModel?> refreshUser() async {
    final user = _client?.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      final fresh = _auth.currentUser;
      return fresh == null ? null : AuthUserModel.fromFirebase(fresh);
    } on fb.FirebaseAuthException catch (e) {
      throw _toAuthException(e);
    }
  }

  @override
  Stream<AuthUserModel?> authStateChanges() {
    final c = _client;
    if (c == null) return const Stream.empty();
    return c.userChanges().map(
          (u) => u == null ? null : AuthUserModel.fromFirebase(u),
        );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<RemoteSession> _sessionFor(fb.User user) async {
    try {
      final token = await user.getIdTokenResult();
      return RemoteSession(
        accessToken: token.token ?? '',
        refreshToken: user.refreshToken ?? '',
        expiresAt: token.expirationTime,
      );
    } on fb.FirebaseAuthException {
      // Offline with an expired token: the user object is still valid locally.
      return RemoteSession(
        accessToken: '',
        refreshToken: user.refreshToken ?? '',
      );
    }
  }

  /// Firebase codes use dashes (`wrong-password`); they are normalised to
  /// underscores so the repository's mapper can match them by substring.
  AuthException _toAuthException(fb.FirebaseAuthException e) => AuthException(
        e.message ?? 'Authentication failed',
        code: e.code.replaceAll('-', '_'),
      );
}
