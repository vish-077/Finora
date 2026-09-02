import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/expense/domain/entities/category.dart';
import 'package:finora/features/expense/domain/entities/expense.dart';
import 'package:finora/features/expense/presentation/viewmodels/add_expense_controller.dart';
import 'package:finora/features/expense/presentation/viewmodels/category_controller.dart';
import 'package:finora/features/expense/presentation/widgets/category_visuals.dart';
import 'package:finora/features/wallet/presentation/viewmodels/wallet_controller.dart';
import 'package:finora/shared/enums/transaction_type.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  const AddExpensePage({super.key, this.existing});

  /// When provided, the page acts as an editor.
  final Expense? existing;

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  late TransactionType _type;
  String? _accountId;
  late DateTime _date;
  String? _categoryId;

  bool get _isEditing => widget.existing != null && widget.existing!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _amount =
        TextEditingController(text: e == null ? '' : e.amount.toStringAsFixed(2));
    _notes = TextEditingController(text: e?.notes ?? '');
    _type = e?.transactionType ?? TransactionType.expense;
    _accountId = e?.accountId;
    _date = e?.transactionDate ?? DateTime.now();
    _categoryId = e?.categoryId;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            picked.year, picked.month, picked.day,
            _date.hour, _date.minute,
          ));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (picked != null) {
      setState(() => _date = DateTime(
            _date.year, _date.month, _date.day,
            picked.hour, picked.minute,
          ));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      showAuthSnack(context, 'Please choose a category', isError: true);
      return;
    }
    final wallets = ref.read(walletControllerProvider).valueOrNull ?? [];
    final selectedAccountId = _accountId ?? (wallets.isNotEmpty ? wallets.first.id : null);
    if (selectedAccountId == null) {
      showAuthSnack(context, 'Please choose an account', isError: true);
      return;
    }
    final ok = await ref.read(addExpenseControllerProvider.notifier).save(
          id: widget.existing?.id,
          title: _title.text,
          amount: double.parse(_amount.text),
          categoryId: _categoryId,
          accountId: selectedAccountId,
          transactionType: _type,
          transactionDate: _date,
          notes: _notes.text,
        );
    if (!mounted) return;
    if (ok) {
      showAuthSnack(context, _isEditing ? 'Expense updated' : 'Expense added');
      context.pop();
    } else {
      final err = ref.read(addExpenseControllerProvider).error;
      showAuthSnack(context, _friendly(err), isError: true);
    }
  }

  String _friendly(Object? err) =>
      err is Failure ? err.message : 'Could not save expense';

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(addExpenseControllerProvider).isLoading;
    final categoriesAsync = ref.watch(categoryControllerProvider);
    final walletsAsync = ref.watch(walletControllerProvider);
    final categories = (categoriesAsync.valueOrNull ?? [])
        .where((c) => c.type == _type)
        .toList();
    final wallets = walletsAsync.valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit expense' : 'Add expense'),
        backgroundColor: AppColors.expense,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              AppSpacing.vMd,
              _Label('Expense Name'),
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'e.g. Groceries'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                enabled: !isLoading,
              ),
              AppSpacing.vMd,
              _Label('Amount'),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '₹ ',
                ),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) return 'Enter a valid amount';
                  if (val <= 0) return 'Amount must be greater than 0';
                  return null;
                },
                enabled: !isLoading,
              ),
              AppSpacing.vMd,
              _Label('Category'),
              _CategoryDropdown(
                categories: categories,
                value: _categoryId,
                loading: categoriesAsync.isLoading,
                onChanged: (id) => setState(() => _categoryId = id),
              ),
              AppSpacing.vMd,
              _Label('Account'),
              DropdownButtonFormField<String>(
                value: wallets.any((w) => w.id == _accountId)
                    ? _accountId
                    : (wallets.isNotEmpty ? wallets.first.id : null),
                hint: const Text('Select account'),
                items: [
                  for (final w in wallets)
                    DropdownMenuItem(value: w.id, child: Text(w.name)),
                ],
                onChanged: isLoading
                    ? null
                    : (m) => setState(() => _accountId = m),
              ),
              AppSpacing.vMd,
              _Label('Date'),
              InkWell(
                onTap: isLoading ? null : _pickDate,
                borderRadius: AppRadius.buttonRadius,
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      AppSpacing.hSm,
                      Text(DateFormat('EEE, d MMM yyyy').format(_date)),
                    ],
                  ),
                ),
              ),
              AppSpacing.vMd,
              _Label('Time'),
              InkWell(
                onTap: isLoading ? null : _pickTime,
                borderRadius: AppRadius.buttonRadius,
                child: InputDecorator(
                  decoration: const InputDecoration(),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_outlined, size: 18),
                      AppSpacing.hSm,
                      Text(DateFormat('h:mm a').format(_date)),
                    ],
                  ),
                ),
              ),
              AppSpacing.vMd,
              _Label('Notes (optional)'),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'Add a note…'),
                enabled: !isLoading,
              ),
              AppSpacing.vXl,
              FinoraButton(
                label: _isEditing ? 'Save changes' : 'Add expense',
                isLoading: isLoading,
                onPressed: _save,
              ),
              AppSpacing.vLg,
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge),
      );
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.loading,
    required this.onChanged,
  });

  final List<Category> categories;
  final String? value;
  final bool loading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (loading && categories.isEmpty) {
      return const LinearProgressIndicator();
    }
    final safeValue =
        categories.any((c) => c.id == value) ? value : null;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      isExpanded: true,
      hint: const Text('Select category'),
      items: [
        for (final c in categories)
          DropdownMenuItem(
            value: c.id,
            child: Row(
              children: [
                Icon(CategoryVisuals.icon(c.icon),
                    size: 18, color: CategoryVisuals.color(c.color)),
                AppSpacing.hSm,
                Text(c.name),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
