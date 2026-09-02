import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/double_extensions.dart';
import 'package:finora/features/expense/domain/entities/dashboard_summary.dart';
import 'package:finora/features/settings/presentation/viewmodels/settings_controller.dart';

/// The dashboard hero card, styled as a physical payment card: brand name,
/// chip, contactless glyph, the holder's name and their balance.
class BalanceCreditCard extends ConsumerWidget {
  const BalanceCreditCard({
    super.key,
    required this.summary,
    required this.holderName,
  });

  final DashboardSummary summary;
  final String holderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(settingsProvider).accentOption;

    return AspectRatio(
      // Close to the 85.6 × 54 mm of a real card, so it reads as one instantly.
      aspectRatio: 1.62,
      child: Container(
        decoration: BoxDecoration(
          gradient: accent.gradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: accent.start.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(
            children: [
              // Soft holographic bloom, the sheen a real card has.
              Positioned(
                top: -70,
                right: -50,
                child: _Bloom(size: 190, color: Colors.white.withValues(alpha: 0.13)),
              ),
              Positioned(
                bottom: -80,
                left: -40,
                child: _Bloom(size: 170, color: Colors.white.withValues(alpha: 0.08)),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Brand row ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded,
                                color: Colors.white, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'FINORA',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.5,
                                  ),
                            ),
                          ],
                        ),
                        const Icon(Icons.contactless_rounded,
                            color: Colors.white70, size: 22),
                      ],
                    ),

                    const Spacer(),

                    // ── Chip + balance ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const _CardChip(),
                        AppSpacing.hMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL BALANCE',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  summary.totalBalance.formatCurrency(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // ── Holder + in/out ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD HOLDER',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                holderName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        _FlowChip(
                          icon: Icons.south_west_rounded,
                          label: 'In',
                          amount: summary.totalIncome,
                        ),
                        const SizedBox(width: 8),
                        _FlowChip(
                          icon: Icons.north_east_rounded,
                          label: 'Out',
                          amount: summary.totalExpense,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

/// The little gold EMV chip.
class _CardChip extends StatelessWidget {
  const _CardChip();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7D774), Color(0xFFC9A227)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            3,
            (_) => Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 7),
              color: Colors.black.withValues(alpha: 0.22),
            ),
          ),
        ),
      );
}

class _FlowChip extends StatelessWidget {
  const _FlowChip({
    required this.icon,
    required this.label,
    required this.amount,
  });

  final IconData icon;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  amount.formatAmount(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
