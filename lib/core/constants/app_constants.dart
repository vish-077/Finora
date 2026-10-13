class AppConstants {
  AppConstants._();

  static const String appName = 'FINORA';
  static const String appTagline = 'Your AI Money Partner';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static const int pinLength = 6;
  static const int bcryptSaltRounds = 12;
  static const String gmailDomain = '@gmail.com';

  // ── Dev test account (DEBUG BUILDS ONLY) ───────────────────────────────────
  // Lets you launch the app without a Firebase account. The bypass in
  // LoginController is guarded by AppConfig.isDevelopment, so it is completely
  // inert in release builds.
  static const String devTestEmail = 'finora.test@gmail.com';
  static const String devTestPassword = 'Fin@123';

  // ── Session ───────────────────────────────────────────────────────────────
  static const Duration sessionTokenExpiry = Duration(hours: 24);
  static const Duration autoLockDefault = Duration(minutes: 5);

  // ── OCR ───────────────────────────────────────────────────────────────────
  static const double ocrAutoFillThreshold = 0.85;
  static const double ocrWarnThreshold = 0.60;

  // ── AI ────────────────────────────────────────────────────────────────────
  static const int aiChatHistoryLimit = 50;
  static const int aiContextMaxTokens = 4096;

  // ── Sync ──────────────────────────────────────────────────────────────────
  static const Duration syncRetryBase = Duration(seconds: 30);
  static const int syncMaxRetries = 5;

  // ── Pagination ────────────────────────────────────────────────────────────
  static const int pageSize = 25;

  // ── PDF ───────────────────────────────────────────────────────────────────
  static const String pdfFilePrefix = 'finora_report_';

  // ── Deep Links ───────────────────────────────────────────────────────────
  static const String deepLinkScheme = 'finora';
  static const String deepLinkHost = 'app';
}
