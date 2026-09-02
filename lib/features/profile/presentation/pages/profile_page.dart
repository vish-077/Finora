import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:finora/features/profile/data/services/avatar_service.dart';
import 'package:finora/features/profile/presentation/viewmodels/avatar_controller.dart';
import 'package:finora/features/settings/presentation/viewmodels/settings_controller.dart';
import 'package:finora/shared/widgets/finora_app_bar.dart';
import 'package:finora/shared/widgets/finora_avatar.dart';
import 'package:finora/shared/widgets/finora_card.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool _biometricsEnabled = false;
  bool _loadingBiometrics = true;
  bool _savingAvatar = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricsStatus();
  }

  Future<void> _loadBiometricsStatus() async {
    try {
      final isEnabled = await ref.read(authRepositoryProvider).isBiometricEnabled();
      if (mounted) {
        setState(() {
          _biometricsEnabled = isEnabled;
          _loadingBiometrics = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBiometrics = false;
        });
      }
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    setState(() {
      _biometricsEnabled = value;
    });
    final result = await ref.read(authRepositoryProvider).setBiometricEnabled(enabled: value);
    result.match(
      (failure) {
        setState(() {
          _biometricsEnabled = !value;
        });
        _toast('Failed to update biometrics: ${failure.message}');
      },
      (_) => _toast(
        value ? 'Biometric unlock enabled' : 'Biometric unlock disabled',
      ),
    );
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  // ── Avatar ────────────────────────────────────────────────────────────────

  Future<void> _pickAvatar(ImageSource source) async {
    setState(() => _savingAvatar = true);
    final error = await ref.read(avatarProvider.notifier).pick(source);
    if (!mounted) return;
    setState(() => _savingAvatar = false);

    if (error != null) {
      _toast(error, isError: true);
    } else if (ref.read(avatarProvider) != null) {
      _toast('Profile picture updated');
    }
  }

  Future<void> _showAvatarSheet() async {
    final hasAvatar = ref.read(avatarProvider) != null;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheetRadius,
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.vMd,
            Text(
              'Profile picture',
              style: Theme.of(sheetContext)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 4,
              ),
              child: Text(
                'Images are cropped square and compressed to stay under 1 MB.',
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
            AppSpacing.vSm,
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  'Remove picture',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(avatarProvider.notifier).remove();
                  _toast('Profile picture removed');
                },
              ),
            AppSpacing.vSm,
          ],
        ),
      ),
    );
  }

  Future<void> _clearLocalData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Local Data?'),
        content: const Text(
          'This will wipe all transactions, budgets, settings, and local database cache from this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) {
        _toast('Local data wiped successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final user = authState.user;

    final displayName = user?.displayName ?? 'Guest User';
    final email = user?.email ?? 'guest@finora.local';
    final isGuest = user?.id == 'local-user';

    return Scaffold(
      appBar: const FinoraAppBar(
        title: 'Profile & Settings',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            children: [
              // ── PROFILE HEADER ──
              const SizedBox(height: 12),
              Stack(
                children: [
                  FinoraAvatar(displayName: displayName, radius: 46),
                  // Camera affordance so it's obvious the picture is editable.
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: settings.accentOption.start,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _savingAvatar ? null : _showAvatarSheet,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: _savingAvatar
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              AppSpacing.vMd,
              Text(
                displayName,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                isGuest ? 'Local Storage Only' : email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.vSm,
              TextButton.icon(
                onPressed: _savingAvatar ? null : _showAvatarSheet,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change profile picture'),
              ),
              const SizedBox(height: 20),

              // ── APPEARANCE ──
              _buildSectionHeader('Appearance'),
              AppSpacing.vSm,
              FinoraCard(
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.palette_outlined,
                      title: 'App Theme',
                      subtitle: 'Choose how Finora looks',
                      trailing: DropdownButton<String>(
                        value: settings.themeMode,
                        underline: const SizedBox(),
                        onChanged: (val) {
                          if (val != null) settingsNotifier.setThemeMode(val);
                        },
                        items: const [
                          DropdownMenuItem(value: 'system', child: Text('System')),
                          DropdownMenuItem(value: 'light', child: Text('Light')),
                          DropdownMenuItem(value: 'dark', child: Text('Dark')),
                        ],
                      ),
                    ),
                    const Divider(),
                    // The accent drives the coloured top bar in every theme.
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _tileIcon(Icons.color_lens_outlined),
                              AppSpacing.hMd,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Accent Colour',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Colours the top bar and balance card',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          AppSpacing.vSm,
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final accent in AppAccents.all)
                                _AccentSwatch(
                                  accent: accent,
                                  selected: settings.accent == accent.key,
                                  onTap: () =>
                                      settingsNotifier.setAccent(accent.key),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vLg,

              // ── MONEY & FORMATTING ──
              _buildSectionHeader('Money & Formatting'),
              AppSpacing.vSm,
              FinoraCard(
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.monetization_on_outlined,
                      title: 'Preferred Currency',
                      subtitle: 'Symbol used across transaction displays',
                      trailing: DropdownButton<String>(
                        value: settings.currency,
                        underline: const SizedBox(),
                        onChanged: (val) {
                          if (val != null) settingsNotifier.setCurrency(val);
                        },
                        items: const [
                          DropdownMenuItem(value: '₹', child: Text('INR (₹)')),
                          DropdownMenuItem(value: '\$', child: Text('USD (\$)')),
                          DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                          DropdownMenuItem(value: '£', child: Text('GBP (£)')),
                        ],
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.event_outlined,
                      title: 'Date Format',
                      subtitle: 'How dates are written',
                      trailing: DropdownButton<String>(
                        value: settings.dateFormat,
                        underline: const SizedBox(),
                        onChanged: (val) {
                          if (val != null) settingsNotifier.setDateFormat(val);
                        },
                        items: const [
                          DropdownMenuItem(
                              value: 'dd/MM/yyyy', child: Text('31/12/2026')),
                          DropdownMenuItem(
                              value: 'MM/dd/yyyy', child: Text('12/31/2026')),
                          DropdownMenuItem(
                              value: 'yyyy-MM-dd', child: Text('2026-12-31')),
                        ],
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.swap_vert_rounded,
                      title: 'Default Entry Type',
                      subtitle: 'Which form opens first',
                      trailing: DropdownButton<String>(
                        value: settings.defaultTransactionType,
                        underline: const SizedBox(),
                        onChanged: (val) {
                          if (val != null) {
                            settingsNotifier.setDefaultTransactionType(val);
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                              value: 'expense', child: Text('Expense')),
                          DropdownMenuItem(
                              value: 'income', child: Text('Income')),
                        ],
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.compress_rounded,
                      title: 'Compact Amounts',
                      subtitle: 'Show 1.2K instead of 1,200.00',
                      trailing: Switch(
                        value: settings.compactAmounts,
                        onChanged: settingsNotifier.setCompactAmounts,
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.calendar_view_week_outlined,
                      title: 'Week Starts Monday',
                      subtitle: 'Off means the week starts on Sunday',
                      trailing: Switch(
                        value: settings.startOfWeekMonday,
                        onChanged: settingsNotifier.setStartOfWeekMonday,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vLg,

              // ── NOTIFICATIONS ──
              _buildSectionHeader('Notifications'),
              AppSpacing.vSm,
              FinoraCard(
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Push Notifications',
                      subtitle: 'Reminders and account activity',
                      trailing: Switch(
                        value: settings.notificationsEnabled,
                        onChanged: settingsNotifier.setNotificationsEnabled,
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.savings_outlined,
                      title: 'Budget Alerts',
                      subtitle: 'Warn me at 80% and when I go over',
                      trailing: Switch(
                        // Budget alerts are meaningless with notifications off.
                        value: settings.budgetAlerts &&
                            settings.notificationsEnabled,
                        onChanged: settings.notificationsEnabled
                            ? settingsNotifier.setBudgetAlerts
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vLg,

              // ── SCANNING ──
              _buildSectionHeader('Receipt Scanning'),
              AppSpacing.vSm,
              FinoraCard(
                child: _buildSettingTile(
                  icon: Icons.document_scanner_outlined,
                  title: 'Confirm Before Saving',
                  subtitle: 'Review the name and category the scanner detected',
                  trailing: Switch(
                    value: settings.confirmScannedExpense,
                    onChanged: settingsNotifier.setConfirmScannedExpense,
                  ),
                ),
              ),
              AppSpacing.vLg,

              // ── PRIVACY & SECURITY ──
              _buildSectionHeader('Privacy & Security'),
              AppSpacing.vSm,
              FinoraCard(
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.visibility_off_outlined,
                      title: 'Privacy Mode',
                      subtitle: 'Hide every amount behind ••••',
                      trailing: Switch(
                        value: settings.privacyMode,
                        onChanged: settingsNotifier.setPrivacyMode,
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.fingerprint_outlined,
                      title: 'Biometric Unlock',
                      subtitle: 'Use fingerprint or face recognition',
                      trailing: _loadingBiometrics
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Switch(
                              value: _biometricsEnabled,
                              onChanged: _toggleBiometrics,
                            ),
                    ),
                  ],
                ),
              ),
              AppSpacing.vLg,

              // ── MANAGE ──
              _buildSectionHeader('Manage'),
              AppSpacing.vSm,
              FinoraCard(
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.category_outlined,
                      title: 'Categories',
                      subtitle: 'Add, rename or recolour categories',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Routes.categories),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Accounts & Wallets',
                      subtitle: 'Cash, bank and card balances',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Routes.wallets),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.pie_chart_outline,
                      title: 'Budgets',
                      subtitle: 'Monthly limits per category',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Routes.budgets),
                    ),
                  ],
                ),
              ),
              AppSpacing.vLg,

              // ── ACTIONS ──
              _buildSectionHeader('Database & Diagnostics'),
              AppSpacing.vSm,
              FinoraCard(
                child: Column(
                  children: [
                    _buildSettingTile(
                      icon: Icons.storage_outlined,
                      title: 'Max Picture Size',
                      subtitle: 'Profile images are capped at 1 MB',
                      trailing: Text(
                        '${AvatarService.maxBytes ~/ (1024 * 1024)} MB',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Divider(),
                    _buildSettingTile(
                      icon: Icons.delete_outline,
                      title: 'Clear Local Cache',
                      subtitle: 'Wipe all locally cached data',
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _clearLocalData,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── LOG OUT BUTTON ──
              FinoraButton(
                label: isGuest ? 'Exit Guest Mode' : 'Sign Out',
                variant: FinoraButtonVariant.outline,
                icon: const Icon(Icons.logout_rounded),
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                },
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  Widget _tileIcon(IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            _tileIcon(icon),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// One tappable accent colour chip.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final AccentOption accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: accent.label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: accent.gradient,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
