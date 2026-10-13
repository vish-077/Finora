import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/validators.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_form_controllers.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:finora/features/auth/presentation/widgets/password_strength_bar.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(registerControllerProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
    if (!mounted) return;
    if (ok) {
      context.go(Routes.dashboard);
    } else {
      final err = ref.read(registerControllerProvider).error;
      showAuthSnack(context, failureMessage(err), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.vLg,
                AuthTextField(
                  controller: _name,
                  label: 'Full name',
                  hint: 'Jane Doe',
                  prefixIcon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: Validators.displayName,
                  enabled: !isLoading,
                ),
                AppSpacing.vMd,
                AuthTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'you@gmail.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.gmail,
                  enabled: !isLoading,
                ),
                AppSpacing.vMd,
                AuthTextField(
                  controller: _password,
                  label: 'Password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: Validators.password,
                  enabled: !isLoading,
                  onChanged: (_) => setState(() {}),
                ),
                PasswordStrengthBar(password: _password.text),
                AppSpacing.vMd,
                AuthTextField(
                  controller: _confirm,
                  label: 'Confirm password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) =>
                      Validators.confirmPassword(v, _password.text),
                  enabled: !isLoading,
                  onFieldSubmitted: (_) => _submit(),
                ),
                AppSpacing.vXl,
                FinoraButton(
                  label: 'Create account',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                AppSpacing.vMd,
                // Registration sends a confirmation email. Say so up
                // front, including the sender limit, because the account cannot
                // be signed into until that link is opened.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.mark_email_unread_outlined,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          'We will email you a confirmation link. You must open '
                          'it before you can sign in. Only a couple of these '
                          'emails can be sent per hour.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                AppSpacing.vLg,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: isLoading ? null : () => context.pop(),
                      child: const Text('Sign in'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
