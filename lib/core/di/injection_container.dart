import 'package:get_it/get_it.dart';
import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:finora/core/constants/storage_constants.dart';
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
  await _initStorage();
  await _initFirebase();
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
  final settingsBox = AppDatabase.box(StorageBoxes.settings);

  sl
    ..registerLazySingleton<SyncLocalStore>(SyncLocalStore.new)
    ..registerLazySingleton<SyncQueue>(
      () => SyncQueue(AppDatabase.box(StorageBoxes.syncQueue)),
    )
    ..registerLazySingleton<SyncCursorStore>(
      () => SyncCursorStore(settingsBox),
    )
    ..registerLazySingleton<SyncScopeStore>(
      () => SyncScopeStore(
        box: AppDatabase.box(StorageBoxes.syncScope),
        store: sl<SyncLocalStore>(),
        queue: sl<SyncQueue>(),
      ),
    )
    ..registerLazySingleton<SyncEngine>(
      () => SyncEngine(
        auth: sl.isRegistered<FirebaseAuth>() ? sl<FirebaseAuth>() : null,
        firestore: sl.isRegistered<FirebaseFirestore>()
            ? sl<FirebaseFirestore>()
            : null,
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

Future<void> _initStorage() async {
  await AppDatabase.init();
  await AppDatabase.openBoxes(StorageBoxes.all);

  sl.registerSingleton<SqlBox>(
    AppDatabase.box(StorageBoxes.transactions),
    instanceName: StorageBoxes.transactions,
  );
  sl.registerSingleton<SqlBox>(
    AppDatabase.box(StorageBoxes.syncQueue),
    instanceName: StorageBoxes.syncQueue,
  );
  sl.registerSingleton<SqlBox>(
    AppDatabase.box(StorageBoxes.settings),
    instanceName: StorageBoxes.settings,
  );

  LogService.d('SQLite storage initialized');
}

/// Starts Firebase from the platform config file (`google-services.json` on
/// Android). When it is missing the app keeps working fully offline — the sync
/// engine and auth source see a null client and degrade cleanly.
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    LogService.w('Firebase not configured — cloud sync disabled ($e)');
    return;
  }

  // The sync engine owns offline behaviour through its SQLite outbox; the
  // Firestore SDK's own cache would only queue writes a second time.
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: false);

  sl
    ..registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance)
    ..registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  LogService.d('Firebase initialized');
}

void _initNetwork() {
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl());
}

void _initExpense() {
  // Only local sources are registered: all server traffic for synced tables
  // now goes through SyncEngine/SyncWriter.
  sl
    ..registerLazySingleton<ExpenseLocalSource>(
      () => ExpenseLocalSourceImpl(AppDatabase.box(StorageBoxes.transactions)),
    )
    ..registerLazySingleton<CategoryLocalSource>(
      () => CategoryLocalSourceImpl(AppDatabase.box(StorageBoxes.categories)),
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
    () => AuthLocalSourceImpl(AppDatabase.box(StorageBoxes.userProfile)),
  );

  sl.registerLazySingleton<AuthRemoteSource>(
    () => AuthRemoteSourceImpl(
      sl.isRegistered<FirebaseAuth>() ? sl<FirebaseAuth>() : null,
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
    () => BudgetLocalSourceImpl(AppDatabase.box(StorageBoxes.budgets)),
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
    () => AccountLocalSourceImpl(AppDatabase.box(StorageBoxes.wallets)),
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
      transactionBox: AppDatabase.box(StorageBoxes.transactions),
      budgetBox: AppDatabase.box(StorageBoxes.budgets),
    ),
  );

  sl
    ..registerFactory(() => GetFinancialHealthUseCase(sl<InsightRepository>()))
    ..registerFactory(() => GetInsightsUseCase(sl<InsightRepository>()));
}
