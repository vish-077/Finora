import 'dart:async';

import 'package:finora/core/config/app_config.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/navigation/app_router.dart';
import 'package:finora/core/services/notification_service.dart';
import 'package:finora/core/sync/sync_engine.dart';
import 'package:finora/core/theme/app_theme.dart';
import 'package:finora/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

void main() {
  runZonedGuarded(
    _bootstrap,
    (error, stack) {
      LogService.e('Uncaught error', error: error, stackTrace: stack);
    },
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) =>
      LogService.e('Flutter error', error: details.exception, stackTrace: details.stack);

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await dotenv.load();
    LogService.i('Environment: ${AppConfig.environment.name}');

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    await initDependencies();
    await NotificationService().init();

    runApp(
      const ProviderScope(
        child: FINORAApp(),
      ),
    );
  } catch (e, stack) {
    LogService.e('Bootstrap initialization failed', error: e, stackTrace: stack);
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Startup Failed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      e.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        await GetIt.instance.reset();
                        await _bootstrap();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Startup'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FINORAApp extends ConsumerStatefulWidget {
  const FINORAApp({super.key});

  @override
  ConsumerState<FINORAApp> createState() => _FINORAAppState();
}

class _FINORAAppState extends ConsumerState<FINORAApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Picking the phone back up is the moment a user expects to see what they
    // entered on their other device.
    if (state == AppLifecycleState.resumed && GetIt.instance.isRegistered<SyncEngine>()) {
      GetIt.instance<SyncEngine>().onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final settings = ref.watch(settingsProvider);

    final themeMode = switch (settings.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'FINORA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(accent: settings.accentOption.start),
      darkTheme: AppTheme.dark(accent: settings.accentOption.start),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
