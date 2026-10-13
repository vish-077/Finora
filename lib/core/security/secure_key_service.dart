import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyService {
  SecureKeyService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  static const String _sessionTokenKey = 'finora_session_token';
  static const String _refreshTokenKey = 'finora_refresh_token';
  static const String _biometricEnabledKey = 'finora_biometric_enabled';
  static const String _pinHashKey = 'finora_pin_hash';
  static const String _aiApiKeyId = 'finora_ai_api_key';
  static const String _pinLockoutKey = 'finora_pin_lockout';
  static const String _pinAttemptsKey = 'finora_pin_attempts';

  // ── Session Token ─────────────────────────────────────────────────────────
  static Future<void> saveSessionToken(String token) =>
      _storage.write(key: _sessionTokenKey, value: token);

  static Future<String?> readSessionToken() =>
      _storage.read(key: _sessionTokenKey);

  static Future<void> clearSessionToken() =>
      _storage.delete(key: _sessionTokenKey);

  // ── Refresh Token (for biometric session restore) ──────────────────────────
  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  static Future<String?> readRefreshToken() =>
      _storage.read(key: _refreshTokenKey);

  static Future<void> clearRefreshToken() =>
      _storage.delete(key: _refreshTokenKey);

  // ── Biometric preference ───────────────────────────────────────────────────
  static Future<void> setBiometricEnabled({required bool enabled}) =>
      _storage.write(key: _biometricEnabledKey, value: enabled.toString());

  static Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometricEnabledKey)) == 'true';

  // ── PIN Hash (bcrypt) ──────────────────────────────────────────────────────
  static Future<void> savePinHash(String hash) =>
      _storage.write(key: _pinHashKey, value: hash);

  static Future<String?> readPinHash() => _storage.read(key: _pinHashKey);

  static Future<void> clearPinHash() => _storage.delete(key: _pinHashKey);

  // ── AI API Key (user-provided Gemini key) ─────────────────────────────────
  static Future<void> saveAiApiKey(String apiKey) =>
      _storage.write(key: _aiApiKeyId, value: apiKey);

  static Future<String?> readAiApiKey() => _storage.read(key: _aiApiKeyId);

  static Future<void> clearAiApiKey() => _storage.delete(key: _aiApiKeyId);

  // ── PIN lockout tracking ───────────────────────────────────────────────────
  static Future<void> savePinAttempts(int count) =>
      _storage.write(key: _pinAttemptsKey, value: count.toString());

  static Future<int> readPinAttempts() async {
    final val = await _storage.read(key: _pinAttemptsKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  static Future<void> saveLockoutExpiry(DateTime expiry) =>
      _storage.write(key: _pinLockoutKey, value: expiry.toIso8601String());

  static Future<DateTime?> readLockoutExpiry() async {
    final val = await _storage.read(key: _pinLockoutKey);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  static Future<void> clearLockout() =>
      Future.wait([
        _storage.delete(key: _pinLockoutKey),
        _storage.delete(key: _pinAttemptsKey),
      ]);

  // ── Full wipe (on logout) ──────────────────────────────────────────────────
  static Future<void> clearAll() => _storage.deleteAll();
}
