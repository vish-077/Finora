import 'package:equatable/equatable.dart';
import 'package:finora/features/wallet/domain/entities/account_type.dart';

class Account extends Equatable {
  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.bankName,
    this.accountNumberLast4,
    required this.currency,
    required this.openingBalance,
    required this.currentBalance,
    required this.icon,
    required this.color,
    required this.isDefault,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final String? bankName;
  final String? accountNumberLast4;
  final String currency;
  final double openingBalance;
  final double currentBalance;
  final String icon;
  final String color;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? bankName,
    String? accountNumberLast4,
    String? currency,
    double? openingBalance,
    double? currentBalance,
    String? icon,
    String? color,
    bool? isDefault,
  }) =>
      Account(
        id: id ?? this.id,
        userId: userId,
        name: name ?? this.name,
        type: type ?? this.type,
        bankName: bankName ?? this.bankName,
        accountNumberLast4: accountNumberLast4 ?? this.accountNumberLast4,
        currency: currency ?? this.currency,
        openingBalance: openingBalance ?? this.openingBalance,
        currentBalance: currentBalance ?? this.currentBalance,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        isDefault: isDefault ?? this.isDefault,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        type,
        bankName,
        accountNumberLast4,
        currency,
        openingBalance,
        currentBalance,
        icon,
        color,
        isDefault,
      ];
}
