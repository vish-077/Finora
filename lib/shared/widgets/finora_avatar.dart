import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finora/features/profile/presentation/viewmodels/avatar_controller.dart';

/// Circular profile picture with an initial-letter fallback.
///
/// Reads the shared avatar provider so every placement (top bar, profile
/// header) updates the moment a new picture is chosen.
class FinoraAvatar extends ConsumerWidget {
  const FinoraAvatar({
    super.key,
    required this.displayName,
    this.radius = 20,
    this.background,
    this.foreground,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String displayName;
  final double radius;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatar = ref.watch(avatarProvider);
    final theme = Theme.of(context);
    final bg = background ?? theme.colorScheme.primaryContainer;
    final fg = foreground ?? theme.colorScheme.primary;

    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : 'U';

    final circle = CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      backgroundImage: avatar == null ? null : FileImage(avatar),
      child: avatar != null
          ? null
          : Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: fg,
                fontSize: radius * 0.8,
              ),
            ),
    );

    if (borderWidth <= 0) return circle;

    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: borderColor ?? theme.colorScheme.surface,
      ),
      child: circle,
    );
  }
}
