import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finora/core/config/app_config.dart';
import 'package:finora/core/constants/hive_constants.dart';
import 'package:finora/core/logging/log_service.dart';
import 'package:finora/core/network/network_info.dart';
import 'package:finora/core/security/biometric_service.dart';
import 'package:finora/core/sync/legacy_id_migration.dart';
import 'package:finora/core/sync/sync_cursor_store.dart';
import 'package:finora/core/sync/sync_engine.dart';
import 'package:finora/core/sync/sync_local_store.dart';
import 'package:finora/core/sync/sync_queue.dart';
import 'package:finora/core/sync/sync_scope.dart';
import 'package:finora/core/sync/sync_writer.dart';
import 'package:finora/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finora/features/auth/data/sources/auth_local_source.dart';
import 'package:finora/features/auth/data/sources/auth_remote_source.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';
import 'package:finora/features/auth/domain/use_cases/authenticate_biometric_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/restore_session_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/send_password_reset_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_up_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/update_password_use_case.dart';
import 'package:finora/features/ai/data/repositories/local_insight_repository.dart';
import 'package:finora/features/ai/domain/repositories/insight_repository.dart';
import 'package:finora/features/ai/domain/use_cases/insight_use_cases.dart';
import 'package:finora/features/budget/data/repositories/budget_repository_impl.dart';
import 'package:finora/features/budget/data/sources/budget_sources.dart';
import 'package:finora/features/budget/domain/repositories/budget_repository.dart';
import 'package:finora/features/budget/domain/use_cases/budget_use_cases.dart';
import 'package:finora/features/wallet/data/repositories/account_repository_impl.dart';
import 'package:finora/features/wallet/data/sources/account_sources.dart';
import 'package:finora/features/wallet/domain/repositories/account_repository.dart';
import 'package:finora/features/wallet/domain/use_cases/account_use_cases.dart';
import 'package:finora/features/expense/data/repositories/category_repository_impl.dart';
import 'package:finora/features/expense/data/repositories/expense_repository_impl.dart';
import 'package:finora/features/expense/data/sources/category_sources.dart';
import 'package:finora/features/expense/data/sources/expense_local_source.dart';
import 'package:finora/features/expense/domain/repositories/category_repository.dart';
import 'package:finora/features/expense/domain/repositories/expense_repository.dart';
import 'package:finora/features/expense/domain/use_cases/add_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/category_use_cases.dart';
import 'package:finora/features/expense/domain/use_cases/delete_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/duplicate_expense_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_analytics_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_dashboard_summary_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_expense_by_id_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_expenses_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/get_recent_transactions_use_case.dart';
import 'package:finora/features/expense/domain/use_cases/update_expense_use_case.dart';

final GetIt sl = GetIt.instance;

/// Initializes all infrastructure singletons.
/// Call this once in main() before runApp().
Future<void> initDependencies() async {
  await _initHive();
  await _initSupabase();
  _initNetwork();
  _initSync();
  _initAuth();
  _initExpense();
  _initBudget();
  _initWallet();
  _initAi();

  // Repair pre-sync local data, then start reconciling with the server.
  await sl<LegacyIdMigration>().run();
  await sl<SyncEngine>().start();

  LogService.i('Dependency injection initialized');
}

void _initSync() {
  final settingsBox = Hive.box<dynamic>(HiveBoxes.settings);

  sl
    ..registerLazySingleton<SyncLocalStore>(SyncLocalStore.new)
    ..registerLazySingleton<SyncQueue>(
      () => SyncQueue(Hive.box<dynamic>(HiveBoxes.syncQueue)),
    )
    ..registerLazySingleton<SyncCursorStore>(
      () => SyncCursorStore(settingsBox),
    )
    ..registerLazySingleton<SyncScopeStore>(
      () => SyncScopeStore(
        box: Hive.box<dynamic>(HiveBoxes.syncScope),
        store: sl<SyncLocalStore>(),
        queue: sl<SyncQueue>(),
      ),
    )
    ..registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        client: sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
        queue: sl<SyncQueue>(),
        store: sl<SyncLocalStore>(),
        cursors: sl<SyncCursorStore>(),
        scopes: sl<SyncScopeStore>(),
        network: sl<NetworkInfo>(),
      ),
    )
    ..registerLazySingleton<SyncWriter>(
      () => SyncWriter(
        queue: sl<SyncQueue>(),
        store: sl<SyncLocalStore>(),
        engine: sl<SyncEngine>(),
      ),
    )
    ..registerLazySingleton<LegacyIdMigration>(
      () => LegacyIdMigration(
        settingsBox: settingsBox,
        store: sl<SyncLocalStore>(),
        queue: sl<SyncQueue>(),
      ),
    );
}

Future<void> _initHive() async {
  await Hive.initFlutter();

  // Register TypeAdapters here when models are generated
  // Hive.registerAdapter(UserProfileModelAdapter());
  // Hive.registerAdapter(TransactionModelAdapter());
  // ...

  // Open all encrypted boxes
  // final encryptionKey = await SecureKeyService.getOrCreateHiveKey();
  // final cipher = HiveAesCipher(encryptionKey);

  // For now open unencrypted boxes (encryption wired in after TypeAdapters)
  await Future.wait([
    Hive.openBox<dynamic>(HiveBoxes.userProfile),
    Hive.openBox<dynamic>(HiveBoxes.transactions),
    Hive.openBox<dynamic>(HiveBoxes.categories),
    Hive.openBox<dynamic>(HiveBoxes.budgets),
    Hive.openBox<dynamic>(HiveBoxes.wallets),
    Hive.openBox<dynamic>(HiveBoxes.goals),
    Hive.openBox<dynamic>(HiveBoxes.syncQueue),
    Hive.openBox<dynamic>(HiveBoxes.syncScope),
    Hive.openBox<dynamic>(HiveBoxes.aiHistory),
    Hive.openBox<dynamic>(HiveBoxes.settings),
    Hive.openBox<dynamic>(HiveBoxes.notifications),
    Hive.openBox<dynamic>(HiveBoxes.receipts),
    Hive.openBox<dynamic>(HiveBoxes.reports),
  ]);

  sl.registerSingleton<Box<dynamic>>(
    Hive.box<dynamic>(HiveBoxes.transactions),
    instanceName: HiveBoxes.transactions,
  );
  sl.registerSingleton<Box<dynamic>>(
    Hive.box<dynamic>(HiveBoxes.syncQueue),
    instanceName: HiveBoxes.syncQueue,
  );
  sl.registerSingleton<Box<dynamic>>(
    Hive.box<dynamic>(HiveBoxes.settings),
    instanceName: HiveBoxes.settings,
  );

  LogService.d('Hive boxes initialized');
}

Future<void> _initSupabase() async {
  if (AppConfig.supabaseUrl.isEmpty || AppConfig.supabaseAnonKey.isEmpty) {
    LogService.w('Supabase not configured — cloud sync disabled');
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey, // ignore: deprecated_member_use
    debug: AppConfig.isDevelopment,
  );

  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
  LogService.d('Supabase client initialized');
}

void _initNetwork() {
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
}

void _initExpense() {
  // Only local sources are registered: all server traffic for synced tables
  // now goes through SyncEngine/SyncWriter.
  sl
    ..registerLazySingleton<ExpenseLocalSource>(
      () => ExpenseLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.transactions)),
    )
    ..registerLazySingleton<CategoryLocalSource>(
      () => CategoryLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.categories)),
    );

  // ── Repositories ─────────────────────────────────────────────────────────────
  sl
    ..registerLazySingleton<ExpenseRepository>(
      () => ExpenseRepositoryImpl(
        local: sl<ExpenseLocalSource>(),
        sync: sl<SyncWriter>(),
        store: sl<SyncLocalStore>(),
      ),
    )
    ..registerLazySingleton<CategoryRepository>(
      () => CategoryRepositoryImpl(
        local: sl<CategoryLocalSource>(),
        sync: sl<SyncWriter>(),
        store: sl<SyncLocalStore>(),
        currentUserId: () =>
            sl<AuthRepository>().currentUser?.id ?? 'local-user',
      ),
    );

  // ── Use cases ──────────────────────────────────────────────────────────────
  sl
    ..registerFactory(() => GetExpensesUseCase(sl<ExpenseRepository>()))
    ..registerFactory(() => GetExpenseByIdUseCase(sl<ExpenseRepository>()))
    ..registerFactory(
        () => GetRecentTransactionsUseCase(sl<ExpenseRepository>()))
    ..registerFactory(() => AddExpenseUseCase(sl<ExpenseRepository>()))
    ..registerFactory(() => UpdateExpenseUseCase(sl<ExpenseRepository>()))
    ..registerFactory(() => DeleteExpenseUseCase(sl<ExpenseRepository>()))
    ..registerFactory(() => DuplicateExpenseUseCase(sl<ExpenseRepository>()))
    ..registerFactory(() => GetCategoriesUseCase(sl<CategoryRepository>()))
    ..registerFactory(() => AddCategoryUseCase(sl<CategoryRepository>()))
    ..registerFactory(() => UpdateCategoryUseCase(sl<CategoryRepository>()))
    ..registerFactory(() => DeleteCategoryUseCase(sl<CategoryRepository>()))
    ..registerFactory(
      () => GetDashboardSummaryUseCase(
        sl<ExpenseRepository>(),
        sl<CategoryRepository>(),
      ),
    )
    ..registerFactory(
      () => GetAnalyticsUseCase(
        sl<ExpenseRepository>(),
        sl<CategoryRepository>(),
      ),
    );
}

void _initAuth() {
  // ── Sources ────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<BiometricService>(() => BiometricServiceImpl());

  sl.registerLazySingleton<AuthLocalSource>(
    () => AuthLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.userProfile)),
  );

  sl.registerLazySingleton<AuthRemoteSource>(
    () => AuthRemoteSourceImpl(
      sl.isRegistered<SupabaseClient>() ? sl<SupabaseClient>() : null,
    ),
  );

  // ── Repository ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remote: sl<AuthRemoteSource>(),
      local: sl<AuthLocalSource>(),
      network: sl<NetworkInfo>(),
      sync: sl<SyncEngine>(),
    ),
  );

  // ── Use cases ────────────────────────────────────────────────────────────────
  sl
    ..registerFactory(() => SignInUseCase(sl<AuthRepository>()))
    ..registerFactory(() => SignUpUseCase(sl<AuthRepository>()))
    ..registerFactory(() => SignOutUseCase(sl<AuthRepository>()))
    ..registerFactory(() => RestoreSessionUseCase(sl<AuthRepository>()))
    ..registerFactory(() => SendPasswordResetUseCase(sl<AuthRepository>()))
    ..registerFactory(() => UpdatePasswordUseCase(sl<AuthRepository>()))
    ..registerFactory(() => ResendVerificationUseCase(sl<AuthRepository>()))
    ..registerFactory(
      () => AuthenticateBiometricUseCase(
        sl<BiometricService>(),
        sl<AuthRepository>(),
      ),
    );
}

void _initBudget() {
  sl.registerLazySingleton<BudgetLocalSource>(
    () => BudgetLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.budgets)),
  );

  // Repository
  sl.registerLazySingleton<BudgetRepository>(
    () => BudgetRepositoryImpl(
      local: sl<BudgetLocalSource>(),
      sync: sl<SyncWriter>(),
      store: sl<SyncLocalStore>(),
    ),
  );

  // Use cases
  sl
    ..registerFactory(() => GetBudgetsUseCase(sl<BudgetRepository>()))
    ..registerFactory(() => AddBudgetUseCase(sl<BudgetRepository>()))
    ..registerFactory(() => UpdateBudgetUseCase(sl<BudgetRepository>()))
    ..registerFactory(() => DeleteBudgetUseCase(sl<BudgetRepository>()));
}

void _initWallet() {
  sl.registerLazySingleton<AccountLocalSource>(
    () => AccountLocalSourceImpl(Hive.box<dynamic>(HiveBoxes.wallets)),
  );

  sl.registerLazySingleton<AccountRepository>(
    () => AccountRepositoryImpl(
      local: sl<AccountLocalSource>(),
      sync: sl<SyncWriter>(),
      store: sl<SyncLocalStore>(),
      currentUserId: () =>
          sl<AuthRepository>().currentUser?.id ?? 'local-user',
    ),
  );

  // Use cases
  sl
    ..registerFactory(() => GetAccountsUseCase(sl<AccountRepository>()))
    ..registerFactory(() => GetAccountByIdUseCase(sl<AccountRepository>()))
    ..registerFactory(() => AddAccountUseCase(sl<AccountRepository>()))
    ..registerFactory(() => UpdateAccountUseCase(sl<AccountRepository>()))
    ..registerFactory(() => DeleteAccountUseCase(sl<AccountRepository>()));
}

void _initAi() {
  sl.registerLazySingleton<InsightRepository>(
    () => LocalInsightRepositoryImpl(
      transactionBox: Hive.box<dynamic>(HiveBoxes.transactions),
      budgetBox: Hive.box<dynamic>(HiveBoxes.budgets),
    ),
  );

  sl
    ..registerFactory(() => GetFinancialHealthUseCase(sl<InsightRepository>()))
    ..registerFactory(() => GetInsightsUseCase(sl<InsightRepository>()));
}
