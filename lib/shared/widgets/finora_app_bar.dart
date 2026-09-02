import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finora/features/settings/presentation/viewmodels/settings_controller.dart';

/// The app's top navigation bar.
///
/// Every screen gets the same accent-coloured band regardless of the active
/// theme, which is what gives the app one recognisable identity in light, dark
/// and system mode. The accent itself is user-selectable in settings.
class FinoraAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const FinoraAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.centerTitle = false,
    this.bottom,
  });

  final String? title;
  final Widget? titleWidget;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(settingsProvider).accentOption;

    return AppBar(
      leading: leading,
      leadingWidth: leadingWidth,
      centerTitle: centerTitle,
      title: titleWidget ??
          (title == null
              ? null
              : Text(
                  title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                )),
      actions: actions,
      bottom: bottom,
      elevation: 0,
      scrolledUnderElevation: 2,
      // Solid accent underneath, gradient on top. Previously this was
      // transparent and relied solely on flexibleSpace to paint — when that
      // didn't cover, white title text landed on the light scaffold and the
      // user's name was invisible in light/system theme.
      backgroundColor: accent.start,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black26,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: accent.appBarGradient,
          boxShadow: [
            BoxShadow(
              color: accent.start.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      ),
    );
  }
}
