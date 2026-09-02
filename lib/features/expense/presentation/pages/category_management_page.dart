import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/widgets/category_editor_sheet.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class CategoryManagementPage extends ConsumerWidget {
  const CategoryManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryEditorSheet.show(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => FinoraEmptyState(
          icon: const Icon(Icons.error_outline, size: 56),
          title: 'Could not load categories',
          subtitle: e is Failure ? e.message : '$e',
          action: FilledButton(
            onPressed: () =>
                ref.read(categoryControllerProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const FinoraEmptyState(
              icon: Icon(Icons.category_outlined, size: 56),
              title: 'No categories',
              subtitle: 'Create one to organise your spending',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = categories[i];
              final color = CategoryVisuals.color(c.color);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(CategoryVisuals.icon(c.icon), color: color),
                ),
                title: Text(c.name),
                subtitle: Text(c.type.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () =>
                          CategoryEditorSheet.show(context, ref, existing: c),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, c),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Category c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete category?'),
        content: Text(
            '“${c.name}” will be removed. Existing transactions keep their data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    final failure =
        await ref.read(categoryControllerProvider.notifier).deleteCategory(c.id);
    if (context.mounted) {
      showAuthSnack(context, failure == null ? 'Deleted' : failure.message,
          isError: failure != null);
    }
  }
}
