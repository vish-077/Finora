import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/theme/app_colors.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/extensions/color_extensions.dart';
import 'package:finora/features/wallet/domain/entities/account.dart';
import 'package:finora/features/wallet/presentation/viewmodels/wallet_controller.dart';
import 'package:finora/shared/widgets/finora_empty_state.dart';
import 'package:intl/intl.dart';

class WalletDashboardPage extends ConsumerWidget {
  const WalletDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts & Wallets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('${Routes.wallets}/add'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(e is Failure ? e.message : 'Error loading wallets'),
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const FinoraEmptyState(
              icon: Icon(Icons.account_balance_wallet, size: 56),
              title: 'No accounts found',
              subtitle: 'Tap the + icon to add an account',
            );
          }

          final totalBalance = accounts.fold(
            0.0,
            (sum, a) => sum + a.currentBalance,
          );

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(walletControllerProvider.notifier).refresh(),
            child: ListView(
              padding: AppSpacing.screenPadding,
              children: [
                _buildTotalCard(context, totalBalance),
                AppSpacing.vLg,
                Text(
                  'Your Accounts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                AppSpacing.vSm,
                ...accounts.map((a) => _AccountCard(account: a)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalCard(BuildContext context, double totalBalance) {
    final formatted = NumberFormat.currency(symbol: '₹').format(totalBalance);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardRadius,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Net Worth',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white70),
          ),
          AppSpacing.vXs,
          Text(
            formatted,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final color = ColorExtensions.fromHex(account.color) ?? AppColors.primary;
    final formatted =
        NumberFormat.currency(symbol: '₹').format(account.currentBalance);

    // Map string icon to IconData
    IconData iconData = Icons.account_balance_wallet;
    if (account.icon == 'account_balance') iconData = Icons.account_balance;
    if (account.icon == 'credit_card') iconData = Icons.credit_card;
    if (account.icon == 'phone_android') iconData = Icons.phone_android;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
      child: InkWell(
        onTap: () => context.push(
          '${Routes.wallets}/${account.id}/edit',
          extra: account,
        ),
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconData, color: color),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      account.type.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                formatted,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: account.currentBalance >= 0
                          ? AppColors.income
                          : AppColors.error,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
