import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/shared/enums/transaction_type.dart';

/// Bottom sheet for creating or editing a [Category].
class CategoryEditorSheet extends ConsumerStatefulWidget {
  const CategoryEditorSheet({super.key, this.existing});

  final Category? existing;

  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    Category? existing,
  }) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => CategoryEditorSheet(existing: existing),
      );

  @override
  ConsumerState<CategoryEditorSheet> createState() =>
      _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends ConsumerState<CategoryEditorSheet> {
  late final TextEditingController _name;
  late String _icon;
  late String _color;
  late TransactionType _type;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    _name = TextEditingController(text: c?.name ?? '');
    _icon = c?.icon ?? CategoryVisuals.pickable.first;
    _color = c?.color ?? CategoryVisuals.palette.first;
    _type = c?.type ?? TransactionType.expense;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showAuthSnack(context, 'Category name is required', isError: true);
      return;
    }
    setState(() => _saving = true);
    final controller = ref.read(categoryControllerProvider.notifier);
    final failure = _isEditing
        ? await controller.updateCategory(
            widget.existing!.copyWith(
              name: _name.text.trim(),
              icon: _icon,
              color: _color,
              type: _type,
            ),
          )
        : await controller.addCategory(
            name: _name.text.trim(),
            icon: _icon,
            color: _color,
            type: _type,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (failure == null) {
      Navigator.of(context).pop();
      showAuthSnack(context, _isEditing ? 'Category updated' : 'Category added');
    } else {
      showAuthSnack(context, failure.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = CategoryVisuals.color(_color);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.base,
        right: AppSpacing.base,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEditing ? 'Edit category' : 'New category',
                style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.vLg,
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            AppSpacing.vMd,
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                    value: TransactionType.expense, label: Text('Expense')),
                ButtonSegment(
                    value: TransactionType.income, label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            AppSpacing.vLg,
            Text('Icon', style: Theme.of(context).textTheme.labelLarge),
            AppSpacing.vXs,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final name in CategoryVisuals.pickable)
                  InkWell(
                    onTap: () => setState(() => _icon = name),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CircleAvatar(
                      backgroundColor: _icon == name
                          ? selectedColor
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        CategoryVisuals.icon(name),
                        color: _icon == name
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.vLg,
            Text('Color', style: Theme.of(context).textTheme.labelLarge),
            AppSpacing.vXs,
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final hex in CategoryVisuals.palette)
                  InkWell(
                    onTap: () => setState(() => _color = hex),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: CategoryVisuals.color(hex),
                        shape: BoxShape.circle,
                        border: _color == hex
                            ? Border.all(
                                color: Theme.of(context).colorScheme.onSurface,
                                width: 3)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.vXl,
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEditing ? 'Save changes' : 'Create category'),
            ),
          ],
        ),
      ),
    );
  }
}
