class Routes {
  Routes._();

  // ── Auth Shell ────────────────────────────────────────────────────────────
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String welcome = '/welcome';
  static const String register = '/register';
  static const String login = '/login';
  static const String emailVerification = '/email-verification';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String pinSetup = '/pin-setup';
  static const String pinVerify = '/pin-verify';
  static const String biometricSetup = '/biometric-setup';

  // ── Main App Shell (bottom nav) ───────────────────────────────────────────
  static const String home = '/home';

  static const String dashboard = '/home/dashboard';
  static const String transactions = '/home/transactions';
  static const String addExpense = '/home/transactions/add-expense';
  static const String addIncome = '/home/transactions/add-income';
  static const String transactionDetail = '/home/transactions/:id';
  static String transactionDetailPath(String id) => '/home/transactions/$id';
  static String transactionEditPath(String id) => '/home/transactions/$id/edit';
  static const String reports = '/home/reports';
  static const String aiBox = '/home/ai-box';
  static const String more = '/home/more';

  // ── Feature Routes ────────────────────────────────────────────────────────
  static const String budgets = '/budgets';
  static const String budgetDetail = '/budgets/:id';
  static String budgetDetailPath(String id) => '$budgets/$id';
  static const String categories = '/categories';
  static const String wallets = '/wallets';
  static const String walletDetail = '/wallets/:id';
  static const String goals = '/goals';
  static const String goalDetail = '/goals/:id';
  static const String receiptScanner = '/receipt-scanner';
  static const String billing = '/billing';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
  static const String aiApiSetup = '/settings/ai-api';
  static const String aiAssistant = '/ai-assistant';

  // ── Utility ───────────────────────────────────────────────────────────────
  static const String error = '/error';
}
