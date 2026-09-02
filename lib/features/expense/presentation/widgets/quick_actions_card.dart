import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';

/// Home-screen quick actions.
///
/// The three entry points are the most-used things in the app, so they get
/// full-height coloured tiles with an icon, a label and a one-word hint rather
/// than the cramped equal-width buttons they replaced.
class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded,
                  color: theme.colorScheme.primary, size: 20),
              AppSpacing.hXs,
              Text(
                'Quick Actions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          AppSpacing.vXs,
          Text(
            'Log money in seconds',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          AppSpacing.vMd,
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.trending_down_rounded,
                  label: 'Expense',
                  hint: 'Money out',
                  start: const Color(0xFFFF6B5B),
                  end: const Color(0xFFC0392B),
                  onTap: () => context.go(Routes.addExpense),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: _ActionTile(
                  icon: Icons.trending_up_rounded,
                  label: 'Income',
                  hint: 'Money in',
                  start: const Color(0xFF2ECC71),
                  end: const Color(0xFF1E8449),
                  onTap: () => context.go(Routes.addIncome),
                ),
              ),
              AppSpacing.hSm,
              Expanded(
                child: _ActionTile(
                  icon: Icons.document_scanner_rounded,
                  label: 'Scan',
                  hint: 'Receipt',
                  start: AppColors.primaryLight,
                  end: AppColors.primary,
                  onTap: () => context.push(Routes.receiptScanner),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.hint,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Color start;
  final Color end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Payment-app layout: a big rounded "logo" badge carrying the colour, on a
    // soft neutral tile, with the label underneath. The colour lives in the
    // badge rather than the whole tile so all three read as one set of icons.
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [start, end],
                  ),
                  // Squircle — the rounded-square app-icon shape.
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: end.withValues(alpha: 0.45),
                      blurRadius: 12,
                      spreadRadius: -1,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glossy top-left highlight, so the badge reads as a logo.
                    Positioned(
                      top: -12,
                      left: -12,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                    ),
                    Icon(icon, color: Colors.white, size: 26),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
