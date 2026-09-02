import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show AuthException;
import 'package:finora/core/error/exceptions.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';

/// Thin wrapper over Supabase Auth. Throws typed [AppException]s that the
/// repository maps to [Failure]s. A null client means Supabase isn't
/// configured (placeholder .env) — every call then fails cleanly.
abstract interface class AuthRemoteSource {
  Future<({AuthUserModel user, Session session})> signIn({
    required String email,
    required String password,
  });

  Future<({AuthUserModel user, Session? session})> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();

  Future<Session?> restoreFromRefreshToken(String refreshToken);

  Session? get currentSession;
  AuthUserModel? get currentUser;

  Future<void> sendPasswordReset(String email);
  Future<void> updatePassword(String newPassword);
  Future<void> resendVerification(String email);
  Future<AuthUserModel?> refreshUser();

  Stream<AuthUserModel?> authStateChanges();
}

class AuthRemoteSourceImpl implements AuthRemoteSource {
  AuthRemoteSourceImpl(this._client);

  final SupabaseClient? _client;

  GoTrueClient get _auth {
    final c = _client;
    if (c == null) {
      throw const NetworkException(
        'Authentication service is not configured',
        code: 'SUPABASE_NOT_CONFIGURED',
      );
    }
    return c.auth;
  }

  @override
  Future<({AuthUserModel user, Session session})> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signInWithPassword(email: email, password: password);
      final session = res.session;
      final user = res.user;
      if (session == null || user == null) {
        throw const AuthException('Sign-in failed', code: 'NO_SESSION');
      }
      return (user: AuthUserModel.fromSupabase(user), session: session);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Future<({AuthUserModel user, Session? session})> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': displayName.trim()},
      );
      final user = res.user;
      if (user == null) {
        throw const AuthException('Sign-up failed', code: 'NO_USER');
      }
      return (user: AuthUserModel.fromSupabase(user), session: res.session);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Future<Session?> restoreFromRefreshToken(String refreshToken) async {
    try {
      final res = await _auth.setSession(refreshToken);
      return res.session;
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Session? get currentSession => _client?.auth.currentSession;

  @override
  AuthUserModel? get currentUser {
    final u = _client?.auth.currentUser;
    return u == null ? null : AuthUserModel.fromSupabase(u);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Future<void> resendVerification(String email) async {
    try {
      await _auth.resend(type: OtpType.signup, email: email.trim());
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Future<AuthUserModel?> refreshUser() async {
    try {
      final res = await _auth.getUser();
      final u = res.user;
      return u == null ? null : AuthUserModel.fromSupabase(u);
    } on sb.AuthException catch (e) {
      throw AuthException(e.message, code: e.code ?? e.statusCode);
    }
  }

  @override
  Stream<AuthUserModel?> authStateChanges() {
    final c = _client;
    if (c == null) return const Stream.empty();
    return c.auth.onAuthStateChange.map((event) {
      final u = event.session?.user;
      return u == null ? null : AuthUserModel.fromSupabase(u);
    });
  }
}
