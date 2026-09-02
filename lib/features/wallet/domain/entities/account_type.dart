enum AccountType {
  cash('Cash'),
  savingsBank('Savings Bank'),
  currentBank('Current Bank'),
  upi('UPI'),
  creditCard('Credit Card'),
  debitCard('Debit Card'),
  wallet('Wallet'),
  investment('Investment'),
  loan('Loan'),
  other('Other');

  const AccountType(this.label);
  final String label;

  String get wire => name;

  static AccountType fromWire(String? v) {
    return AccountType.values.firstWhere(
      (e) => e.wire == v,
      orElse: () => AccountType.other,
    );
  }
}
