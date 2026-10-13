import 'dart:convert';
import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/security/secure_key_service.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';

/// Persists session material (secure storage) and the cached user profile
/// (Hive). Session tokens NEVER touch Hive — only flutter_secure_storage.
abstract interface class AuthLocalSource {
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  });
  Future<String?> readRefreshToken();
  Future<String?> readAccessToken();
  Future<void> clearSession();

  Future<void> cacheUser(AuthUserModel user);
  AuthUserModel? readCachedUser();
  Future<void> clearCachedUser();

  Future<void> saveRegisteredUser(AuthUserModel user);
  AuthUserModel? readRegisteredUser(String email);

  Future<void> setBiometricEnabled({required bool enabled});
  Future<bool> isBiometricEnabled();
  Future<void> clearAllUserData();
}

class AuthLocalSourceImpl implements AuthLocalSource {
  AuthLocalSourceImpl(this._userBox);

  final SqlBox _userBox;
  static const String _cachedUserKey = 'cached_auth_user';

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
  }) =>
      Future.wait([
        SecureKeyService.saveSessionToken(accessToken),
        SecureKeyService.saveRefreshToken(refreshToken),
      ]);

  @override
  Future<String?> readRefreshToken() => SecureKeyService.readRefreshToken();

  @override
  Future<String?> readAccessToken() => SecureKeyService.readSessionToken();

  @override
  Future<void> clearSession() => Future.wait([
        SecureKeyService.clearSessionToken(),
        SecureKeyService.clearRefreshToken(),
      ]);

  @override
  Future<void> cacheUser(AuthUserModel user) =>
      _userBox.put(_cachedUserKey, jsonEncode(user.toCache()));

  @override
  AuthUserModel? readCachedUser() {
    final raw = _userBox.get(_cachedUserKey) as String?;
    if (raw == null) return null;
    try {
      return AuthUserModel.fromCache(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> clearCachedUser() => _userBox.delete(_cachedUserKey);

  static String _registeredUserKey(String email) =>
      'registered_user_${email.trim().toLowerCase()}';

  @override
  Future<void> saveRegisteredUser(AuthUserModel user) async {
    await _userBox.put(
      _registeredUserKey(user.email),
      jsonEncode(user.toCache()),
    );
  }

  @override
  AuthUserModel? readRegisteredUser(String email) {
    final raw = _userBox.get(_registeredUserKey(email)) as String?;
    if (raw == null) return null;
    try {
      return AuthUserModel.fromCache(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setBiometricEnabled({required bool enabled}) =>
      SecureKeyService.setBiometricEnabled(enabled: enabled);

  @override
  Future<bool> isBiometricEnabled() => SecureKeyService.isBiometricEnabled();

  @override
  Future<void> clearAllUserData() async {
    // The synced tables (transactions, categories, budgets, wallets, goals)
    // and the outbox are deliberately NOT touched here.
    //
    // SyncEngine.handleSignOut owns them: it flushes what it can, then keeps
    // anything unsent so it uploads on the next sign-in. This method used to
    // clear the syncQueue and the data boxes as well, which destroyed exactly
    // that pending work — on a device that had never reached the server, every
    // expense the user had entered was gone for good and the account read zero
    // after signing back in.
    await Future.wait([
      // aiHistory is also left alone: threads are keyed by user id and must
      // survive sign-out. Clearing them is done from the AI Box itself.
      AppDatabase.box(StorageBoxes.notifications).clear(),
      AppDatabase.box(StorageBoxes.receipts).clear(),
      AppDatabase.box(StorageBoxes.reports).clear(),
    ]);
  }
}
