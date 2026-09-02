import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_spacing.dart';

class FinoraCard extends StatelessWidget {
  const FinoraCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Card(
          color: color,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardRadius,
            child: Padding(
              padding: padding ?? AppSpacing.cardPadding,
              child: child,
            ),
          ),
        ),
      );
}
