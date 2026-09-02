import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({
    super.key,
    required this.expense,
    this.category,
    this.onTap,
  });

  final Expense expense;
  final Category? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final arrowIcon = expense.isIncome ? Icons.arrow_downward : Icons.arrow_upward;
    final amountColor = expense.isIncome ? AppColors.income : AppColors.expense;
    final sign = expense.isIncome ? '+' : '-';

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: AppRadius.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: amountColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(arrowIcon, color: amountColor, size: 22),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category?.name ?? 'Uncategorized'} · ${expense.paymentMethod.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hSm,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$sign${expense.amount.formatCurrency()}',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: amountColor, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('d MMM').format(expense.transactionDate)} · ${DateFormat('h:mm a').format(expense.transactionDate)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
