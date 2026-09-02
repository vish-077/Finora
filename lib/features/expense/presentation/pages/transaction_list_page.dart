import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/expense_list_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/filter_controller.dart';
import 'package:finora/features/expense/presentation/widgets/expense_card.dart';
import 'package:finora/features/expense/presentation/widgets/filter_sheet.dart';
import 'package:finora/features/expense/presentation/widgets/offline_banner.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';

class TransactionListPage extends ConsumerStatefulWidget {
  const TransactionListPage({super.key});

  @override
  ConsumerState<TransactionListPage> createState() =>
      _TransactionListPageState();
}

class _TransactionListPageState extends ConsumerState<TransactionListPage> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  int _visible = 20;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 300) {
      setState(() => _visible += 20);
    }
  }

  void _openEditor(BuildContext context, Expense e) {
    context.go(Routes.transactionEditPath(e.id));
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expenseListControllerProvider);
    final categories = ref.watch(categoryControllerProvider).valueOrNull ?? [];
    final categoryById = {for (final c in categories) c.id: c};
    final filter = ref.watch(filterControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: filter.isActive,
              child: const Icon(Icons.tune),
            ),
            onPressed: () => FilterSheet.show(context),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.base, 0, AppSpacing.base, AppSpacing.sm),
            child: TextField(
              controller: _search,
              onChanged: (v) =>
                  ref.read(filterControllerProvider.notifier).setQuery(v),
              decoration: InputDecoration(
                hintText: 'Search title or notes…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          ref
                              .read(filterControllerProvider.notifier)
                              .setQuery('');
                        },
                      ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                message: e is Failure ? e.message : 'Something went wrong',
                onRetry: () =>
                    ref.read(expenseListControllerProvider.notifier).refresh(),
              ),
              data: (all) {
                if (all.isEmpty) {
                  return FinoraEmptyState(
                    icon: const Icon(Icons.receipt_long_outlined, size: 56),
                    title: filter.isActive
                        ? 'No matching transactions'
                        : 'No transactions yet',
                    subtitle: filter.isActive
                        ? 'Try adjusting your filters'
                        : 'Tap “Add” to record your first expense',
                  );
                }
                final visible = all.take(_visible).toList();
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(expenseListControllerProvider.notifier)
                      .refresh(),
                  child: _GroupedList(
                    scroll: _scroll,
                    expenses: visible,
                    hasMore: visible.length < all.length,
                    categoryById: categoryById,
                    onTap: (e) => context.go(
                      Routes.transactionDetailPath(e.id),
                    ),
                    onEdit: (e) => _openEditor(context, e),
                    onDelete: _confirmDelete,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(Expense e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('“${e.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    final failure = await ref
        .read(expenseListControllerProvider.notifier)
        .deleteExpense(e.id);
    if (mounted) {
      showAuthSnack(
        context,
        failure == null ? 'Transaction deleted' : failure.message,
        isError: failure != null,
      );
    }
    return failure == null;
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.scroll,
    required this.expenses,
    required this.hasMore,
    required this.categoryById,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ScrollController scroll;
  final List<Expense> expenses;
  final bool hasMore;
  final Map<String, Category> categoryById;
  final void Function(Expense) onTap;
  final void Function(Expense) onEdit;
  final Future<bool> Function(Expense) onDelete;

  @override
  Widget build(BuildContext context) {
    // Build header/item rows grouped by day.
    final rows = <Widget>[];
    String? lastKey;
    for (final e in expenses) {
      final key = _dayKey(e.transactionDate);
      if (key != lastKey) {
        rows.add(_DateHeader(label: key));
        lastKey = key;
      }
      rows.add(
        Dismissible(
          key: ValueKey(e.id),
          background: _swipeBg(
            color: AppColors.primary,
            icon: Icons.edit,
            alignment: Alignment.centerLeft,
          ),
          secondaryBackground: _swipeBg(
            color: AppColors.expense,
            icon: Icons.delete,
            alignment: Alignment.centerRight,
          ),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              onEdit(e);
              return false;
            }
            return onDelete(e);
          },
          child: ExpenseCard(
            expense: e,
            category: e.categoryId == null ? null : categoryById[e.categoryId],
            onTap: () => onTap(e),
          ),
        ),
      );
    }
    if (hasMore) {
      rows.add(const Padding(
        padding: EdgeInsets.all(AppSpacing.base),
        child: Center(child: CircularProgressIndicator()),
      ));
    }

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (_, i) => rows[i],
    );
  }

  Widget _swipeBg({
    required Color color,
    required IconData icon,
    required Alignment alignment,
  }) =>
      Container(
        color: color,
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Icon(icon, color: Colors.white),
      );

  String _dayKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('EEEE, d MMM yyyy').format(date);
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.xs),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FinoraEmptyState(
        icon: const Icon(Icons.error_outline, size: 56, color: AppColors.error),
        title: 'Could not load transactions',
        subtitle: message,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      );
}
