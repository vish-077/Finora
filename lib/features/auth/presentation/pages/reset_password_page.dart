import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/validators.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_form_controllers.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:finora/features/auth/presentation/widgets/password_strength_bar.dart';
import 'package:finora/shared/widgets/finora_button.dart';

/// Lets a signed-in user choose a new password. (Forgotten-password emails
/// are completed on Firebase's hosted reset page, not in the app.)
class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(_password.text);
    if (!mounted) return;
    if (ok) {
      showAuthSnack(context, 'Password updated. Please sign in.');
      context.go(Routes.login);
    } else {
      showAuthSnack(
        context,
        failureMessage(ref.read(resetPasswordControllerProvider).error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(resetPasswordControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('New password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSpacing.vLg,
                Text('Set a new password',
                    style: Theme.of(context).textTheme.headlineSmall),
                AppSpacing.vXs,
                Text('Choose a strong password you haven’t used before.',
                    style: Theme.of(context).textTheme.bodyMedium),
                AppSpacing.vXl,
                AuthTextField(
                  controller: _password,
                  label: 'New password',
                  hint: 'At least 8 characters',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.next,
                  validator: Validators.password,
                  enabled: !isLoading,
                  onChanged: (_) => setState(() {}),
                ),
                PasswordStrengthBar(password: _password.text),
                AppSpacing.vMd,
                AuthTextField(
                  controller: _confirm,
                  label: 'Confirm new password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) => Validators.confirmPassword(v, _password.text),
                  enabled: !isLoading,
                  onFieldSubmitted: (_) => _submit(),
                ),
                AppSpacing.vXl,
                FinoraButton(
                  label: 'Update password',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
