import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_spacing.dart';

enum FinoraButtonVariant { primary, secondary, outline, ghost }

enum FinoraButtonSize { small, medium, large }

class FinoraButton extends StatelessWidget {
  const FinoraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = FinoraButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.size = FinoraButtonSize.medium,
  });

  final String label;
  final VoidCallback? onPressed;
  final FinoraButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool enabled;
  final FinoraButtonSize size;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon!, AppSpacing.hSm],
              Text(label),
            ],
          );

    return switch (variant) {
      FinoraButtonVariant.primary => ElevatedButton(
          onPressed: (enabled && !isLoading) ? onPressed : null,
          style: _sizeStyle(context),
          child: child,
        ),
      FinoraButtonVariant.outline => OutlinedButton(
          onPressed: (enabled && !isLoading) ? onPressed : null,
          style: _sizeStyle(context),
          child: child,
        ),
      FinoraButtonVariant.secondary => FilledButton.tonal(
          onPressed: (enabled && !isLoading) ? onPressed : null,
          style: _sizeStyle(context),
          child: child,
        ),
      FinoraButtonVariant.ghost => TextButton(
          onPressed: (enabled && !isLoading) ? onPressed : null,
          child: child,
        ),
    };
  }

  ButtonStyle? _sizeStyle(BuildContext context) => switch (size) {
        FinoraButtonSize.small => ElevatedButton.styleFrom(
            minimumSize: const Size(80, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        FinoraButtonSize.medium => null,
        FinoraButtonSize.large => ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: Theme.of(context).textTheme.titleSmall,
          ),
      };
}
