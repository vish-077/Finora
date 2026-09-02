import 'package:logger/logger.dart';
import 'package:finora/core/config/app_config.dart';

class LogService {
  LogService._();

  static final Logger _logger = Logger(
    level: AppConfig.isDevelopment ? Level.trace : Level.warning,
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    filter: _FinoraLogFilter(),
  );

  static void t(String message, [Object? context]) =>
      _logger.t(_sanitize(message), error: context);

  static void d(String message, [Object? context]) =>
      _logger.d(_sanitize(message), error: context);

  static void i(String message, [Object? context]) =>
      _logger.i(_sanitize(message), error: context);

  static void w(String message, [Object? context]) =>
      _logger.w(_sanitize(message), error: context);

  static void e(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(_sanitize(message), error: error, stackTrace: stackTrace);

  static void event(String name, {Map<String, Object>? params}) {
    if (AppConfig.isDevelopment) {
      _logger.i('[EVENT] $name ${params ?? ''}');
    }
  }

  static String _sanitize(String message) {
    final emailPattern = RegExp(r'[\w.+-]+@[\w-]+\.[a-z]{2,}', caseSensitive: false);
    final apiKeyPattern = RegExp(r'[A-Za-z0-9_-]{32,}');
    return message
        .replaceAll(emailPattern, '[REDACTED_EMAIL]')
        .replaceAll(apiKeyPattern, '[REDACTED_KEY]');
  }
}

class _FinoraLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (AppConfig.isProduction && event.level.index < Level.warning.index) {
      return false;
    }
    return true;
  }
}
