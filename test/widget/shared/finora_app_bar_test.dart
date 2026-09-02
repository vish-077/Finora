import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finora/core/theme/app_theme.dart';
import 'package:finora/shared/widgets/finora_app_bar.dart';

/// Relative luminance, per WCAG. Used to assert the bar is dark enough for the
/// white title text to be readable.
double _luminance(Color c) => c.computeLuminance();

Future<void> _pumpBar(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: const Scaffold(
          appBar: FinoraAppBar(title: 'Hello, Jane'),
          body: SizedBox(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('FinoraAppBar contrast', () {
    // Regression: the bar used a transparent background and relied only on
    // flexibleSpace to paint, so white title text could land on the light
    // scaffold — the user's name rendered white-on-white in light theme.
    testWidgets('has an opaque dark background in light theme', (tester) async {
      await _pumpBar(tester, AppTheme.light());

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final bg = appBar.backgroundColor!;

      expect(bg.a, 1.0, reason: 'app bar background must be opaque');
      expect(
        _luminance(bg),
        lessThan(0.4),
        reason: 'background must be dark enough for white text',
      );
    });

    testWidgets('has an opaque dark background in dark theme', (tester) async {
      await _pumpBar(tester, AppTheme.dark());

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      final bg = appBar.backgroundColor!;

      expect(bg.a, 1.0);
      expect(_luminance(bg), lessThan(0.4));
    });

    testWidgets('renders the title in white', (tester) async {
      await _pumpBar(tester, AppTheme.light());

      expect(find.text('Hello, Jane'), findsOneWidget);
      final title = tester.widget<Text>(find.text('Hello, Jane'));
      expect(title.style?.color, Colors.white);
    });
  });
}
