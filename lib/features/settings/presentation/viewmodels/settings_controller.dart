import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';
import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/theme/app_colors.dart';

/// A selectable brand accent. Drives the coloured top navigation bar so the
/// same identity shows up in light, dark and system themes.
class AccentOption {
  const AccentOption({
    required this.key,
    required this.label,
    required this.start,
    required this.end,
  });

  final String key;
  final String label;
  final Color start;
  final Color end;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, end],
      );

  /// Narrower gradient for the top bar. Some accents end on a light tone
  /// (Sunset finishes in amber) which would leave white title text barely
  /// legible, so the far stop is pulled back toward the dark start colour.
  LinearGradient get appBarGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [start, Color.lerp(start, end, 0.55) ?? end],
      );
}

class AppAccents {
  AppAccents._();

  static const List<AccentOption> all = [
    AccentOption(
      key: 'navy',
      label: 'Finora Navy',
      start: AppColors.primary,
      end: AppColors.primaryLight,
    ),
    AccentOption(
      key: 'emerald',
      label: 'Emerald',
      start: Color(0xFF11705A),
      end: Color(0xFF27AE60),
    ),
    AccentOption(
      key: 'violet',
      label: 'Violet',
      start: Color(0xFF5B2C87),
      end: Color(0xFF9B59B6),
    ),
    AccentOption(
      key: 'sunset',
      label: 'Sunset',
      start: Color(0xFFC0392B),
      end: Color(0xFFF39C12),
    ),
    AccentOption(
      key: 'midnight',
      label: 'Midnight',
      start: Color(0xFF11172B),
      end: Color(0xFF2C3E64),
    ),
    AccentOption(
      key: 'teal',
      label: 'Teal',
      start: Color(0xFF0E5A62),
      end: Color(0xFF1ABC9C),
    ),
  ];

  static AccentOption byKey(String key) =>
      all.firstWhere((a) => a.key == key, orElse: () => all.first);
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.currency,
    required this.accent,
    required this.notificationsEnabled,
    required this.budgetAlerts,
    required this.privacyMode,
    required this.compactAmounts,
    required this.startOfWeekMonday,
    required this.dateFormat,
    required this.defaultTransactionType,
    required this.confirmScannedExpense,
  });

  final String themeMode; // 'light', 'dark', 'system'
  final String currency; // '₹', '$', '€', '£'

  /// Key into [AppAccents.all].
  final String accent;

  final bool notificationsEnabled;
  final bool budgetAlerts;

  /// Masks every amount on screen as •••• until toggled off.
  final bool privacyMode;

  /// Show 1.2K instead of 1,200.00 in summary tiles.
  final bool compactAmounts;

  final bool startOfWeekMonday;
  final String dateFormat; // 'dd/MM/yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'
  final String defaultTransactionType; // 'expense' | 'income'

  /// Ask for a name + category confirmation before a scanned receipt becomes
  /// an expense.
  final bool confirmScannedExpense;

  static String currentCurrency = '₹';

  /// Read by the currency formatter so masking works everywhere at once
  /// without threading the setting through every widget.
  static bool currentPrivacyMode = false;
  static bool currentCompactAmounts = false;

  AccentOption get accentOption => AppAccents.byKey(accent);

  AppSettings copyWith({
    String? themeMode,
    String? currency,
    String? accent,
    bool? notificationsEnabled,
    bool? budgetAlerts,
    bool? privacyMode,
    bool? compactAmounts,
    bool? startOfWeekMonday,
    String? dateFormat,
    String? defaultTransactionType,
    bool? confirmScannedExpense,
  }) {
    final settings = AppSettings(
      themeMode: themeMode ?? this.themeMode,
      currency: currency ?? this.currency,
      accent: accent ?? this.accent,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      privacyMode: privacyMode ?? this.privacyMode,
      compactAmounts: compactAmounts ?? this.compactAmounts,
      startOfWeekMonday: startOfWeekMonday ?? this.startOfWeekMonday,
      dateFormat: dateFormat ?? this.dateFormat,
      defaultTransactionType:
          defaultTransactionType ?? this.defaultTransactionType,
      confirmScannedExpense:
          confirmScannedExpense ?? this.confirmScannedExpense,
    );
    currentCurrency = settings.currency;
    currentPrivacyMode = settings.privacyMode;
    currentCompactAmounts = settings.compactAmounts;
    return settings;
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  /// Null when the settings box has not been opened. Settings are now read by
  /// shared chrome (the top bar), which can be built in contexts that never
  /// boot Hive — widget tests, error fallbacks — so a missing box degrades to
  /// in-memory defaults instead of throwing.
  SqlBox? _box;

  T _get<T>(String key, T fallback) {
    final value = _box?.get(key, defaultValue: fallback);
    return value is T ? value : fallback;
  }

  @override
  AppSettings build() {
    try {
      _box = AppDatabase.box(StorageBoxes.settings);
    } catch (_) {
      _box = null;
    }

    final settings = AppSettings(
      themeMode: _get('theme_mode', 'system'),
      currency: _get('currency', '₹'),
      accent: _get('accent', 'navy'),
      notificationsEnabled: _get('notifications_enabled', true),
      budgetAlerts: _get('budget_alerts', true),
      privacyMode: _get('privacy_mode', false),
      compactAmounts: _get('compact_amounts', false),
      startOfWeekMonday: _get('start_of_week_monday', true),
      dateFormat: _get('date_format', 'dd/MM/yyyy'),
      defaultTransactionType: _get('default_txn_type', 'expense'),
      confirmScannedExpense: _get('confirm_scanned_expense', true),
    );

    // Set global static helpers used by the formatting extensions.
    AppSettings.currentCurrency = settings.currency;
    AppSettings.currentPrivacyMode = settings.privacyMode;
    AppSettings.currentCompactAmounts = settings.compactAmounts;

    return settings;
  }

  Future<void> _put(String key, Object value) async =>
      _box == null ? null : _box!.put(key, value);

  Future<void> setThemeMode(String theme) async {
    await _put('theme_mode', theme);
    state = state.copyWith(themeMode: theme);
  }

  Future<void> setCurrency(String currency) async {
    await _put('currency', currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> setAccent(String accent) async {
    await _put('accent', accent);
    state = state.copyWith(accent: accent);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    await _put('notifications_enabled', value);
    state = state.copyWith(notificationsEnabled: value);
  }

  Future<void> setBudgetAlerts(bool value) async {
    await _put('budget_alerts', value);
    state = state.copyWith(budgetAlerts: value);
  }

  Future<void> setPrivacyMode(bool value) async {
    await _put('privacy_mode', value);
    state = state.copyWith(privacyMode: value);
  }

  Future<void> setCompactAmounts(bool value) async {
    await _put('compact_amounts', value);
    state = state.copyWith(compactAmounts: value);
  }

  Future<void> setStartOfWeekMonday(bool value) async {
    await _put('start_of_week_monday', value);
    state = state.copyWith(startOfWeekMonday: value);
  }

  Future<void> setDateFormat(String value) async {
    await _put('date_format', value);
    state = state.copyWith(dateFormat: value);
  }

  Future<void> setDefaultTransactionType(String value) async {
    await _put('default_txn_type', value);
    state = state.copyWith(defaultTransactionType: value);
  }

  Future<void> setConfirmScannedExpense(bool value) async {
    await _put('confirm_scanned_expense', value);
    state = state.copyWith(confirmScannedExpense: value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});
