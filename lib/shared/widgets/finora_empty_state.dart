import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_spacing.dart';

class FinoraEmptyState extends StatelessWidget {
  const FinoraEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                icon!,
                AppSpacing.vLg,
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (subtitle != null) ...[
                AppSpacing.vSm,
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                AppSpacing.vXl,
                action!,
              ],
            ],
          ),
        ),
      );
}
