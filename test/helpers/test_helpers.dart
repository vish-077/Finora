import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:finora/core/theme/app_theme.dart';

/// Wraps a widget with ProviderScope and MaterialApp for testing.
Widget buildTestWidget(
  Widget child, {
  List<Override> overrides = const [],
}) =>
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );

/// Helper to pump and settle with a timeout.
Future<void> pumpAndSettle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(seconds: 5));
}
