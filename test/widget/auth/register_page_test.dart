import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/auth/presentation/pages/register_page.dart';

import '../../helpers/test_helpers.dart';

void main() {
  testWidgets('renders all registration fields', (tester) async {
    await tester.pumpWidget(buildTestWidget(const RegisterPage()));
    await tester.pump();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });

  testWidgets('non-gmail email is rejected', (tester) async {
    await tester.pumpWidget(buildTestWidget(const RegisterPage()));
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), 'jane@yahoo.com');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pump();

    expect(find.text('Only @gmail.com accounts are supported'), findsOneWidget);
  });

  testWidgets('mismatched passwords are rejected', (tester) async {
    await tester.pumpWidget(buildTestWidget(const RegisterPage()));
    await tester.pump();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Jane Doe');
    await tester.enterText(fields.at(1), 'jane@gmail.com');
    await tester.enterText(fields.at(2), 'Str0ngPass');
    await tester.enterText(fields.at(3), 'Different1');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('password strength meter appears while typing', (tester) async {
    await tester.pumpWidget(buildTestWidget(const RegisterPage()));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(2), 'Str0ng!Pass');
    await tester.pump();

    expect(find.text('Strong'), findsOneWidget);
  });
}
