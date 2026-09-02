import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/auth/presentation/pages/email_verification_page.dart';
import 'package:finora/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:finora/features/auth/presentation/pages/login_page.dart';
import 'package:finora/features/auth/presentation/pages/register_page.dart';
import 'package:finora/features/auth/presentation/pages/reset_password_page.dart';
import 'package:finora/features/auth/presentation/pages/splash_page.dart';
import 'package:finora/features/auth/presentation/pages/welcome_page.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/presentation/pages/budget_dashboard_page.dart';
import 'package:finora/features/budget/presentation/pages/budget_detail_page.dart';
import 'package:finora/features/expense/presentation/pages/add_expense_page.dart';
import 'package:finora/features/expense/presentation/pages/add_income_page.dart';
import 'package:finora/features/expense/presentation/pages/analytics_page.dart';
import 'package:finora/features/expense/presentation/pages/category_management_page.dart';
import 'package:finora/features/expense/presentation/pages/dashboard_page.dart';
import 'package:finora/features/expense/presentation/pages/expense_detail_page.dart';
import 'package:finora/features/expense/presentation/pages/transaction_list_page.dart';
import 'package:finora/features/settings/presentation/pages/aura_api_setup_page.dart';
import 'package:finora/features/profile/presentation/pages/profile_page.dart';
import 'package:finora/features/ai/presentation/pages/ai_box_page.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/presentation/pages/add_account_page.dart';
import 'package:finora/features/wallet/presentation/pages/wallet_dashboard_page.dart';
import 'package:finora/features/receipt_scanner/presentation/pages/receipt_scanner_page.dart';

part 'app_router.g.dart';

@riverpod
GoRouter appRouter(AppRouterRef ref) {
  // Bridge Riverpod auth state → a Listenable GoRouter can refresh on.
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    redirect: (context, state) => _guard(ref, state),
    routes: [
      ..._authRoutes,
      _mainShellRoute,
      ..._featureRoutes,
    ],
    errorBuilder: (context, state) => _ErrorPage(error: state.error),
  );
}

const _authRouteLocations = <String>{
  Routes.welcome,
  Routes.login,
  Routes.register,
  Routes.forgotPassword,
};

/// Centralized route guard. Returns a redirect path, or null to allow.
String? _guard(Ref ref, GoRouterState state) {
  final auth = ref.read(authControllerProvider);
  final loc = state.matchedLocation;

  // Password recovery deep link is always reachable.
  if (loc == Routes.resetPassword) return null;

  final onSplash = loc == Routes.splash;
  final onAuthRoute = _authRouteLocations.contains(loc);
  final onVerify = loc == Routes.emailVerification;

  return switch (auth.status) {
    AuthStatus.unknown => onSplash ? null : Routes.splash,
    AuthStatus.unauthenticated => onAuthRoute ? null : Routes.welcome,
    AuthStatus.unverified => onVerify ? null : Routes.emailVerification,
    AuthStatus.authenticated =>
      (onSplash || onAuthRoute || onVerify) ? Routes.dashboard : null,
  };
}

// ── Auth Routes ────────────────────────────────────────────────────────────
List<RouteBase> get _authRoutes => [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: Routes.welcome, builder: (_, __) => const WelcomePage()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginPage()),
      GoRoute(path: Routes.register, builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: Routes.emailVerification,
        builder: (_, __) => const EmailVerificationPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.resetPassword,
        builder: (_, __) => const ResetPasswordPage(),
      ),
    ];

// ── Main Shell (bottom navigation) ────────────────────────────────────────
RouteBase get _mainShellRoute => ShellRoute(
      builder: (context, state, child) => _MainShell(child: child),
      routes: [
        GoRoute(
          path: Routes.dashboard,
          builder: (_, __) => const DashboardPage(),
        ),
        GoRoute(
          path: Routes.transactions,
          builder: (_, __) => const TransactionListPage(),
          routes: [
            GoRoute(
              path: 'add-expense',
              builder: (context, state) {
                final expense = state.extra as Expense?;
                return AddExpensePage(existing: expense);
              },
            ),
            GoRoute(
              path: 'add-income',
              builder: (_, __) => const AddIncomePage(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ExpenseDetailPage(expenseId: id);
              },
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return EditExpenseWrapper(expenseId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: Routes.reports,
          builder: (_, __) => const AnalyticsPage(),
        ),
        GoRoute(
          path: Routes.aiBox,
          builder: (_, __) => const AiBoxPage(),
        ),
        GoRoute(
          path: Routes.more,
          builder: (_, __) => const _MorePlaceholderPage(),
        ),
      ],
    );

// ── Feature Routes (outside shell) ────────────────────────────────────────
List<RouteBase> get _featureRoutes => [
      GoRoute(
        path: Routes.budgets,
        builder: (_, __) => const BudgetDashboardPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              final progress = state.extra as BudgetProgress;
              return BudgetDetailPage(budgetId: id, progress: progress);
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.categories,
        builder: (_, __) => const CategoryManagementPage(),
      ),
      GoRoute(
        path: Routes.wallets,
        builder: (_, __) => const WalletDashboardPage(),
        routes: [
          GoRoute(
            path: 'add',
            builder: (_, __) => const AddAccountPage(),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) {
              // Note: Passing the existing account instance would require 
              // extra data payload in state.extra. For now we just route to it.
              final account = state.extra as Account?;
              return AddAccountPage(existing: account);
            },
          ),
        ],
      ),
      GoRoute(
        path: Routes.goals,
        builder: (_, __) => const _PlaceholderPage(title: 'Goals'),
      ),
      GoRoute(
        path: Routes.receiptScanner,
        builder: (_, __) => const ReceiptScannerPage(),
      ),
      GoRoute(
        path: Routes.billing,
        builder: (_, __) => const _PlaceholderPage(title: 'Billing & PDF'),
      ),
      GoRoute(
        path: Routes.aiAssistant,
        builder: (_, __) => const AiBoxPage(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const _PlaceholderPage(title: 'Settings'),
        routes: [
          GoRoute(
            path: 'ai-api',
            builder: (_, __) => const AuraApiSetupPage(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.profile,
        builder: (_, __) => const ProfilePage(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const _PlaceholderPage(title: 'Notifications'),
      ),
    ];

class _MainShell extends StatelessWidget {
  const _MainShell({required this.child});

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(Routes.transactions)) return 1;
    if (location.startsWith(Routes.reports)) return 2;
    if (location.startsWith(Routes.aiBox)) return 3;
    if (location.startsWith(Routes.more) ||
        location.startsWith(Routes.budgets) ||
        location.startsWith(Routes.categories) ||
        location.startsWith(Routes.wallets)) {
      return 4;
    }
    return 0; // Default to Home
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.green),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: Colors.green),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart, color: Colors.green),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome, color: Colors.green),
            label: 'AI Box',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: Colors.green),
            label: 'More',
          ),
        ],
        onDestinationSelected: (index) {
          const routes = [
            Routes.dashboard,
            Routes.transactions,
            Routes.reports,
            Routes.aiBox,
            Routes.more,
          ];
          context.go(routes[index]);
        },
      ),
    );
  }
}

// ── Placeholder page (skeleton for feature implementation) ─────────────────
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction, size: 48),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Feature coming soon',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}

/// Temporary "More" tab with a working Sign out action so the full auth
/// loop (login → home → logout) is exercisable before other features exist.
class _MorePlaceholderPage extends ConsumerWidget {
  const _MorePlaceholderPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('More')),
        body: ListView(
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Categories'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.categories),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('All transactions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.transactions),
            ),
            const Divider(),
            ListTile(
              leading: Text(
                ref.watch(authControllerProvider).user?.email ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign out'),
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ],
        ),
      );
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text('Navigation error: ${error?.toString() ?? 'Unknown'}'),
        ),
      );
}
