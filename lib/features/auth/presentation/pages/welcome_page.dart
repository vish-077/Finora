import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/app_constants.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              const Spacer(),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/app_logo.jpg',
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
              AppSpacing.vLg,
              Text(
                'Welcome to ${AppConstants.appName}',
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              AppSpacing.vSm,
              Text(
                'Track spending, set budgets, and let AI help you\nsave smarter — all in one place.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FinoraButton(
                label: 'Create an account',
                onPressed: () => context.push(Routes.register),
              ),
              AppSpacing.vMd,
              FinoraButton(
                label: 'I already have an account',
                variant: FinoraButtonVariant.outline,
                onPressed: () => context.push(Routes.login),
              ),
              AppSpacing.vMd,
              FinoraButton(
                label: 'Continue without email',
                variant: FinoraButtonVariant.ghost,
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).continueAsGuest();
                },
              ),
              AppSpacing.vXl,
            ],
          ),
        ),
      ),
    );
  }
}
