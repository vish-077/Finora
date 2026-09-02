import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/domain/entities/account_type.dart';
import 'package:finora/features/wallet/presentation/viewmodels/add_account_controller.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class AddAccountPage extends ConsumerStatefulWidget {
  const AddAccountPage({super.key, this.existing});

  final Account? existing;

  @override
  ConsumerState<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends ConsumerState<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _balance;
  late final TextEditingController _bankName;
  late final TextEditingController _accountNumber;

  late AccountType _type;
  String _color = '#3498DB';
  String _icon = 'account_balance_wallet';

  bool get _isEditing => widget.existing != null;

  final _availableColors = [
    '#3498DB', '#E74C3C', '#2ECC71', '#F1C40F', 
    '#9B59B6', '#E67E22', '#34495E', '#1ABC9C'
  ];
  
  final _availableIcons = [
    'account_balance_wallet', 'account_balance', 'credit_card', 
    'phone_android', 'savings', 'payments'
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _name = TextEditingController(text: a?.name ?? '');
    _balance = TextEditingController(text: a == null ? '' : a.openingBalance.toStringAsFixed(2));
    _bankName = TextEditingController(text: a?.bankName ?? '');
    _accountNumber = TextEditingController(text: a?.accountNumberLast4 ?? '');
    _type = a?.type ?? AccountType.cash;
    if (a != null) {
      _color = a.color;
      _icon = a.icon;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _bankName.dispose();
    _accountNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final ok = await ref.read(addAccountControllerProvider.notifier).save(
          id: widget.existing?.id,
          name: _name.text,
          type: _type,
          openingBalance: double.parse(_balance.text),
          color: _color,
          icon: _icon,
          bankName: _bankName.text.isNotEmpty ? _bankName.text : null,
          accountNumberLast4: _accountNumber.text.isNotEmpty ? _accountNumber.text : null,
        );
    if (!mounted) return;
    if (ok) {
      showAuthSnack(context, _isEditing ? 'Account updated' : 'Account created');
      context.pop();
    } else {
      final err = ref.read(addAccountControllerProvider).error;
      showAuthSnack(context, _friendly(err), isError: true);
    }
  }

  String _friendly(Object? err) =>
      err is Failure ? err.message : 'Could not save account';

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(addAccountControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Account' : 'Add Account'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              _Label('Account Name'),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: 'e.g. Main Bank'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                enabled: !isLoading,
              ),
              AppSpacing.vMd,
              _Label('Account Type'),
              DropdownButtonFormField<AccountType>(
                value: _type,
                items: [
                  for (final t in AccountType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: isLoading
                    ? null
                    : (t) => setState(() => _type = t!),
              ),
              AppSpacing.vMd,
              _Label(_isEditing ? 'Current Balance' : 'Opening Balance'),
              TextFormField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  return null;
                },
                enabled: !isLoading,
              ),
              
              if (_type != AccountType.cash && _type != AccountType.wallet) ...[
                AppSpacing.vMd,
                _Label('Bank Name (optional)'),
                TextFormField(
                  controller: _bankName,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'e.g. Chase'),
                  enabled: !isLoading,
                ),
                AppSpacing.vMd,
                _Label('Last 4 Digits (optional)'),
                TextFormField(
                  controller: _accountNumber,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(hintText: 'e.g. 1234'),
                  enabled: !isLoading,
                ),
              ],
              
              AppSpacing.vMd,
              _Label('Color Theme'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _availableColors.map((c) {
                  final colorVal = Color(int.parse(c.replaceFirst('#', 'ff'), radix: 16));
                  final isSelected = _color == c;
                  return GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorVal,
                        shape: BoxShape.circle,
                        border: isSelected 
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                        boxShadow: [
                          if (isSelected)
                            const BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }).toList(),
              ),

              AppSpacing.vXl,
              FinoraButton(
                label: _isEditing ? 'Save changes' : 'Add account',
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
        padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
        child: Text(
          text,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
}
