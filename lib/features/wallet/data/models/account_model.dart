import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/domain/entities/account_type.dart';

class AccountModel extends Account {
  const AccountModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.type,
    super.bankName,
    super.accountNumberLast4,
    required super.currency,
    required super.openingBalance,
    required super.currentBalance,
    required super.icon,
    required super.color,
    required super.isDefault,
    super.createdAt,
    super.updatedAt,
  });

  factory AccountModel.fromMap(Map<String, dynamic> map) => AccountModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String,
        type: AccountType.fromWire(map['type'] as String?),
        bankName: map['bank_name'] as String?,
        accountNumberLast4: map['account_number_last4'] as String?,
        currency: map['currency'] as String? ?? 'INR',
        openingBalance: _toDouble(map['opening_balance']),
        currentBalance: _toDouble(map['current_balance']),
        icon: map['icon'] as String? ?? 'account_balance_wallet',
        color: map['color'] as String? ?? '#3498DB',
        isDefault: (map['is_default'] as bool?) ?? false,
        createdAt: _date(map['created_at']),
        updatedAt: _date(map['updated_at']),
      );

  factory AccountModel.fromEntity(Account e) => AccountModel(
        id: e.id,
        userId: e.userId,
        name: e.name,
        type: e.type,
        bankName: e.bankName,
        accountNumberLast4: e.accountNumberLast4,
        currency: e.currency,
        openingBalance: e.openingBalance,
        currentBalance: e.currentBalance,
        icon: e.icon,
        color: e.color,
        isDefault: e.isDefault,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  Map<String, dynamic> toInsert() => <String, dynamic>{
        'user_id': userId,
        'name': name,
        'type': type.wire,
        'bank_name': bankName,
        'account_number_last4': accountNumberLast4,
        'currency': currency,
        'opening_balance': openingBalance,
        'current_balance': currentBalance,
        'icon': icon,
        'color': color,
        'is_default': isDefault,
      };

  Map<String, dynamic> toCache() => <String, dynamic>{
        'id': id,
        ...toInsert(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();
}
