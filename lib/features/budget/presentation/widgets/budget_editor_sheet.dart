import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/context_extensions.dart';
import 'package:finora/features/budget/domain/entities/budget.dart';
import 'package:finora/features/budget/presentation/viewmodels/budget_editor_controller.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/shared/enums/transaction_type.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class BudgetEditorSheet extends ConsumerStatefulWidget {
  const BudgetEditorSheet({
    super.key,
    this.budget,
    required this.month,
    required this.year,
  });

  final Budget? budget;
  final int month;
  final int year;

  static Future<void> show(
    BuildContext context, {
    Budget? budget,
    required int month,
    required int year,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => BudgetEditorSheet(
        budget: budget,
        month: month,
        year: year,
      ),
    );
  }

  @override
  ConsumerState<BudgetEditorSheet> createState() => _BudgetEditorSheetState();
}

class _BudgetEditorSheetState extends ConsumerState<BudgetEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Category? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.budget != null) {
      _amountController.text = widget.budget!.amount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      context.showSnackBar('Please select a category', isError: true);
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      context.showSnackBar('Enter a valid amount', isError: true);
      return;
    }

    final failure = await ref
        .read(budgetEditorControllerProvider.notifier)
        .saveBudget(
          existingBudget: widget.budget,
          categoryId: _selectedCategory!.id,
          amount: amount,
          month: widget.month,
          year: widget.year,
        );

    if (failure != null) {
      if (mounted) context.showSnackBar(failure.message, isError: true);
      return;
    }

    if (mounted) {
      context.showSnackBar('Budget saved successfully');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCategories = ref.watch(categoryControllerProvider);
    final state = ref.watch(budgetEditorControllerProvider);

    // If editing, try to pre-select the category once they are loaded
    if (widget.budget != null &&
        _selectedCategory == null &&
        asyncCategories.hasValue) {
      final matches = asyncCategories.value!
          .where((c) => c.id == widget.budget!.categoryId);
      if (matches.isNotEmpty) {
        _selectedCategory = matches.first;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.budget == null ? 'Create Budget' : 'Edit Budget',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              AppSpacing.vLg,
              asyncCategories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error loading categories: $e'),
                data: (categories) {
                  // Only show expense categories for budgets
                  final expenseCats = categories
                      .where((c) => c.type == TransactionType.expense)
                      .toList();
                  return DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: expenseCats.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Row(
                          children: [
                            Icon(
                              CategoryVisuals.icon(cat.icon),
                              color: CategoryVisuals.color(cat.color),
                            ),
                            AppSpacing.hMd,
                            Text(cat.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: widget.budget != null
                        ? null // Prevent changing category if editing
                        : (val) => setState(() => _selectedCategory = val),
                    validator: (v) => v == null ? 'Select a category' : null,
                  );
                },
              ),
              AppSpacing.vLg,
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Enter amount';
                  if (double.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
              AppSpacing.vXl,
              FinoraButton(
                onPressed: _save,
                isLoading: state.isLoading,
                label: 'Save Budget',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
