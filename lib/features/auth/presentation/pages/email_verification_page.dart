import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_form_controllers.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class EmailVerificationPage extends ConsumerWidget {
  const EmailVerificationPage({super.key});

  Future<void> _resend(BuildContext context, WidgetRef ref, String email) async {
    final ok =
        await ref.read(resendVerificationControllerProvider.notifier).submit(email);
    if (!context.mounted) return;
    ok
        ? showAuthSnack(context, 'Verification email sent to $email')
        : showAuthSnack(
            context,
            failureMessage(ref.read(resendVerificationControllerProvider).error),
            isError: true,
          );
  }

  Future<void> _checkVerified(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).refreshUser();
    if (!context.mounted) return;
    final status = ref.read(authControllerProvider).status;
    if (status == AuthStatus.authenticated) {
      showAuthSnack(context, 'Email verified!');
    } else {
      showAuthSnack(context, 'Not verified yet. Check your inbox.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authControllerProvider).user?.email ?? 'your email';
    final resendState = ref.watch(resendVerificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify email'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.mark_email_unread_outlined,
                  size: 80, color: AppColors.primary),
              AppSpacing.vLg,
              Text('Check your inbox',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              AppSpacing.vSm,
              Text(
                "We've sent a verification link to\n$email",
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FinoraButton(
                label: "I've verified my email",
                onPressed: () => _checkVerified(context, ref),
              ),
              AppSpacing.vMd,
              FinoraButton(
                label: 'Resend email',
                variant: FinoraButtonVariant.outline,
                isLoading: resendState.isLoading,
                onPressed: () => _resend(context, ref, email),
              ),
              AppSpacing.vXl,
            ],
          ),
        ),
      ),
    );
  }
}
