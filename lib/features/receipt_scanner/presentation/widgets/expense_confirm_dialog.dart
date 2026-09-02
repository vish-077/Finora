import 'package:flutter/material.dart';

import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';

/// What the user settled on for a scanned receipt.
class ConfirmedExpenseDetails {
  const ConfirmedExpenseDetails({
    required this.title,
    required this.category,
  });

  final String title;
  final Category? category;
}

/// Last checkpoint before a scanned receipt turns into an expense.
///
/// The OCR/ML pass guesses a name and a category; both are shown as editable
/// fields with the guess pre-filled so confirming is one tap, while a wrong
/// guess can be corrected on the spot instead of after the fact.
class ExpenseConfirmDialog extends StatefulWidget {
  const ExpenseConfirmDialog({
    super.key,
    required this.detectedTitle,
    required this.detectedCategoryName,
    required this.amount,
    required this.categories,
    required this.confidence,
  });

  final String detectedTitle;
  final String detectedCategoryName;
  final double amount;
  final List<Category> categories;
  final double confidence;

  @override
  State<ExpenseConfirmDialog> createState() => _ExpenseConfirmDialogState();
}

class _ExpenseConfirmDialogState extends State<ExpenseConfirmDialog> {
  late final TextEditingController _titleController;
  final _formKey = GlobalKey<FormState>();

  Category? _category;

  /// True while the fields still hold exactly what the scanner detected.
  bool _titleUntouched = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.detectedTitle.trim());
    _category = _matchDetectedCategory();
  }

  /// Case-insensitive name match. Deliberately returns null rather than
  /// falling back to the first category — guessing silently is what made
  /// mis-categorised scans hard to notice.
  Category? _matchDetectedCategory() {
    final target = widget.detectedCategoryName.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final c in widget.categories) {
      if (c.name.toLowerCase() == target) return c;
    }
    return null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  bool get _categoryWasDetected => _matchDetectedCategory() != null;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      ConfirmedExpenseDetails(
        title: _titleController.text.trim(),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidencePct = (widget.confidence * 100).clamp(0, 100).toDouble();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm expense',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Check what the scan detected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Amount recap (read-only; it was already verified) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 18, color: theme.colorScheme.onSurfaceVariant),
                    AppSpacing.hSm,
                    Expanded(
                      child: Text('Amount',
                          style: theme.textTheme.bodyMedium),
                    ),
                    Text(
                      widget.amount.formatCurrency(),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              AppSpacing.vMd,

              // ── Name ──
              Text(
                'Expense name',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              AppSpacing.vXs,
              TextFormField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: 'e.g. Groceries at Big Bazaar',
                  prefixIcon: const Icon(Icons.label_outline),
                  suffixIcon: _titleUntouched && widget.detectedTitle.isNotEmpty
                      ? Tooltip(
                          message: 'Detected from the receipt',
                          child: Icon(Icons.auto_awesome,
                              size: 18, color: theme.colorScheme.primary),
                        )
                      : null,
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Give this expense a name';
                  if (text.length < 2) return 'Name is too short';
                  return null;
                },
                onChanged: (_) {
                  if (_titleUntouched) setState(() => _titleUntouched = false);
                },
              ),
              AppSpacing.vMd,

              // ── Category ──
              Row(
                children: [
                  Text(
                    'Category',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.hSm,
                  if (_categoryWasDetected)
                    _Pill(
                      label: 'Detected · ${confidencePct.toStringAsFixed(0)}%',
                      color: confidencePct >= 70
                          ? AppColors.income
                          : AppColors.warning,
                    )
                  else
                    const _Pill(label: 'Not detected', color: AppColors.warning),
                ],
              ),
              AppSpacing.vXs,
              DropdownButtonFormField<Category?>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                hint: const Text('Pick a category'),
                items: [
                  for (final c in widget.categories)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(CategoryVisuals.icon(c.icon),
                              size: 18, color: CategoryVisuals.color(c.color)),
                          AppSpacing.hSm,
                          Expanded(
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value),
                validator: (value) =>
                    value == null ? 'Choose the category for this expense' : null,
              ),

              AppSpacing.vMd,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 15, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _categoryWasDetected
                          ? 'If the detected category is wrong, change it here — '
                              'this is what the charts will group by.'
                          : 'The scan could not match a category. Pick the right '
                              'one so this shows up correctly in your charts.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Looks right'),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: AppRadius.pillRadius,
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
}
