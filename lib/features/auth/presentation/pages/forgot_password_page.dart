import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/validators.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_form_controllers.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(forgotPasswordControllerProvider.notifier)
        .submit(_email.text);
    if (!mounted) return;
    if (ok) {
      setState(() => _sent = true);
    } else {
      showAuthSnack(
        context,
        failureMessage(ref.read(forgotPasswordControllerProvider).error),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(forgotPasswordControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: _sent
              ? _SentView(email: _email.text, onDone: () => context.pop())
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSpacing.vLg,
                      Text('Forgot your password?',
                          style: Theme.of(context).textTheme.headlineSmall),
                      AppSpacing.vXs,
                      Text(
                        "Enter your email and we'll send you a link to reset it.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      AppSpacing.vXl,
                      AuthTextField(
                        controller: _email,
                        label: 'Email',
                        hint: 'you@gmail.com',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        validator: Validators.email,
                        enabled: !isLoading,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      AppSpacing.vXl,
                      FinoraButton(
                        label: 'Send reset link',
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

class _SentView extends StatelessWidget {
  const _SentView({required this.email, required this.onDone});

  final String email;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSpacing.vXxl,
          const Icon(Icons.mark_email_read_outlined,
              size: 80, color: Colors.green),
          AppSpacing.vLg,
          Text('Check your email',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          AppSpacing.vSm,
          Text('We sent a password reset link to\n$email',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center),
          AppSpacing.vXxl,
          FinoraButton(label: 'Back to sign in', onPressed: onDone),
        ],
      );
}
