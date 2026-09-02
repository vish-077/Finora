import 'package:finora/core/utils/extensions/string_extensions.dart';

/// Form field validators for use with [TextFormField.validator].
/// Each returns `null` when valid, or a user-friendly message when invalid.
class Validators {
  Validators._();

  static const int minPasswordLength = 8;
  static const int minNameLength = 2;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!v.isValidEmail) return 'Enter a valid email address';
    return null;
  }

  /// Strict @gmail.com validation (per FINORA V1 policy).
  static String? gmail(String? value) {
    final base = email(value);
    if (base != null) return base;
    if (!value!.trim().isGmailAddress) {
      return 'Only @gmail.com accounts are supported';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < minPasswordLength) {
      return 'Password must be at least $minPasswordLength characters';
    }
    if (!v.contains(RegExp('[A-Z]'))) {
      return 'Add at least one uppercase letter';
    }
    if (!v.contains(RegExp('[a-z]'))) {
      return 'Add at least one lowercase letter';
    }
    if (!v.contains(RegExp('[0-9]'))) {
      return 'Add at least one number';
    }
    return null;
  }

  /// Lenient check for the login screen — we only require non-empty there,
  /// so users with legacy passwords can still sign in.
  static String? loginPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? displayName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < minNameLength) {
      return 'Name must be at least $minNameLength characters';
    }
    return null;
  }

  /// Returns a 0–4 strength score for a password (for strength meters).
  static int passwordStrength(String value) {
    var score = 0;
    if (value.length >= minPasswordLength) score++;
    if (value.contains(RegExp('[A-Z]'))) score++;
    if (value.contains(RegExp('[0-9]'))) score++;
    if (value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'))) score++;
    return score;
  }
}
