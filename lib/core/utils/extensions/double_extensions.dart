import 'package:intl/intl.dart';
import 'package:finora/features/settings/presentation/viewmodels/settings_controller.dart';

extension DoubleX on double {
  String formatCurrency({String? symbol, int decimalDigits = 2}) {
    final sym = symbol ?? AppSettings.currentCurrency;
    if (AppSettings.currentPrivacyMode) return '$sym ••••';
    if (AppSettings.currentCompactAmounts) return _compact(sym);
    return NumberFormat.currency(
      symbol: sym,
      decimalDigits: decimalDigits,
    ).format(this);
  }

  String formatAmount({String? symbol}) {
    final sym = symbol ?? AppSettings.currentCurrency;
    if (AppSettings.currentPrivacyMode) return '$sym ••••';
    return _compact(sym);
  }

  /// Short form (1.2K / 3.4M), falling back to the full figure below 1,000.
  String _compact(String sym) {
    if (abs() >= 1000000) {
      return '$sym${(this / 1000000).toStringAsFixed(1)}M';
    }
    if (abs() >= 1000) {
      return '$sym${(this / 1000).toStringAsFixed(1)}K';
    }
    return NumberFormat.currency(symbol: sym, decimalDigits: 2).format(this);
  }

  double get roundTo2 => double.parse(toStringAsFixed(2));
}
