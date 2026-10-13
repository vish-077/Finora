enum TransactionType {
  income,
  expense,
  transfer;

  String get label => switch (this) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
      };

  bool get isIncome => this == TransactionType.income;
  bool get isExpense => this == TransactionType.expense;
  bool get isTransfer => this == TransactionType.transfer;
}

enum WalletType {
  cash,
  bank,
  creditCard,
  savings,
  investment,
  other;

  String get label => switch (this) {
        WalletType.cash => 'Cash',
        WalletType.bank => 'Bank Account',
        WalletType.creditCard => 'Credit Card',
        WalletType.savings => 'Savings',
        WalletType.investment => 'Investment',
        WalletType.other => 'Other',
      };
}

enum SyncOperation {
  insert,
  update,
  delete;
}

enum ThemePreference {
  system,
  light,
  dark;
}

enum PaymentMethod {
  cash,
  upi,
  creditCard,
  debitCard,
  wallet,
  bankTransfer;

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.upi => 'UPI',
        PaymentMethod.creditCard => 'Credit Card',
        PaymentMethod.debitCard => 'Debit Card',
        PaymentMethod.wallet => 'Wallet',
        PaymentMethod.bankTransfer => 'Bank Transfer',
      };

  /// Stable string stored in Firestore / SQLite.
  String get wire => name;

  static PaymentMethod fromWire(String? value) => PaymentMethod.values
      .firstWhere((m) => m.name == value, orElse: () => PaymentMethod.cash);
}

extension TransactionTypeWire on TransactionType {
  String get wire => name;

  static TransactionType fromWire(String? value) => TransactionType.values
      .firstWhere((t) => t.name == value, orElse: () => TransactionType.expense);
}
