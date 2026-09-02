import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/expense/domain/entities/expense_filter.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/filter_controller.dart';
import 'package:finora/shared/enums/transaction_type.dart';

class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const FilterSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(filterControllerProvider);
    final notifier = ref.read(filterControllerProvider.notifier);
    final categories = ref.watch(categoryControllerProvider).valueOrNull ?? [];
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        top: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filters', style: theme.textTheme.titleLarge),
                TextButton(
                  onPressed: notifier.clear,
                  child: const Text('Clear all'),
                ),
              ],
            ),
            AppSpacing.vMd,
            Text('Date range', style: theme.textTheme.labelLarge),
            AppSpacing.vXs,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final p in DateRangePreset.values)
                  if (p != DateRangePreset.custom)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: filter.preset == p,
                      onSelected: (_) => notifier.setPreset(p),
                    ),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(
                    filter.preset == DateRangePreset.custom &&
                            filter.customStart != null
                        ? 'Custom ✓'
                        : 'Custom',
                  ),
                  onPressed: () => _pickCustom(context, notifier),
                ),
              ],
            ),
            AppSpacing.vMd,
            Text('Type', style: theme.textTheme.labelLarge),
            AppSpacing.vXs,
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter.transactionType == null,
                  onSelected: (_) => notifier.setTransactionType(null),
                ),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: filter.transactionType == TransactionType.expense,
                  onSelected: (_) =>
                      notifier.setTransactionType(TransactionType.expense),
                ),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: filter.transactionType == TransactionType.income,
                  onSelected: (_) =>
                      notifier.setTransactionType(TransactionType.income),
                ),
              ],
            ),
            AppSpacing.vMd,
            Text('Category', style: theme.textTheme.labelLarge),
            AppSpacing.vXs,
            DropdownButtonFormField<String?>(
              initialValue: filter.categoryId,
              isExpanded: true,
              hint: const Text('Any category'),
              items: [
                const DropdownMenuItem(child: Text('Any category')),
                for (final c in categories)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: notifier.setCategory,
            ),
            AppSpacing.vMd,
            Text('Payment method', style: theme.textTheme.labelLarge),
            AppSpacing.vXs,
            DropdownButtonFormField<PaymentMethod?>(
              initialValue: filter.paymentMethod,
              isExpanded: true,
              hint: const Text('Any method'),
              items: [
                const DropdownMenuItem(child: Text('Any method')),
                for (final m in PaymentMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.label)),
              ],
              onChanged: notifier.setPaymentMethod,
            ),
            AppSpacing.vLg,
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustom(
    BuildContext context,
    FilterController notifier,
  ) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (range != null) {
      notifier.setCustomRange(
        range.start,
        range.end.add(const Duration(days: 1)),
      );
    }
  }
}
