import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_typography.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class FinoraAmountText extends StatelessWidget {
  const FinoraAmountText({
    super.key,
    required this.amount,
    required this.type,
    this.style,
    this.showSign = true,
    this.compact = false,
  });

  final double amount;
  final TransactionType type;
  final TextStyle? style;
  final bool showSign;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      TransactionType.income => AppColors.income,
      TransactionType.expense => AppColors.expense,
      TransactionType.transfer => AppColors.transfer,
    };

    final sign = showSign
        ? switch (type) {
            TransactionType.income => '+',
            TransactionType.expense => '-',
            TransactionType.transfer => '',
          }
        : '';

    final formatted =
        compact ? amount.formatAmount() : amount.formatCurrency();

    return Text(
      '$sign$formatted',
      style: (style ?? AppTypography.amountMedium).copyWith(color: color),
    );
  }
}
