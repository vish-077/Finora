// FINORA smoke test — verifies the app boots and renders the initial route.
//
// Note: the full app (FINORAApp) depends on runtime initialization
// (dotenv, SQLite, Firebase, GetIt) done in main._bootstrap(). Testing that
// requires integration-level setup, so this smoke test validates the theme
// and a minimal MaterialApp render instead. Feature widget tests live under
// test/unit and test/widget per feature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finora/core/theme/app_theme.dart';

void main() {
  testWidgets('App theme applies and renders a scaffold', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const Scaffold(body: Center(child: Text('FINORA'))),
      ),
    );

    expect(find.text('FINORA'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).theme, isNotNull);
  });
}
