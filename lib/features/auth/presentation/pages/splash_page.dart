import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/core/constants/app_constants.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';

/// Branded loading screen shown while [AuthController] restores the session.
/// The router redirects away once auth state resolves.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure the controller is instantiated so restore begins.
    ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/app_logo.jpg',
                width: 96,
                height: 96,
                fit: BoxFit.cover,
              ),
            ),
            AppSpacing.vLg,
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
            ),
            AppSpacing.vXs,
            Text(
              AppConstants.appTagline,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white70),
            ),
            AppSpacing.vXxl,
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
