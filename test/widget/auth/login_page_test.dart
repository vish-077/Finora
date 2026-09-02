import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/security/biometric_service.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';
import 'package:finora/features/auth/presentation/pages/login_page.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';

import '../../helpers/test_helpers.dart';

class _FakeBiometric implements BiometricService {
  @override
  Future<bool> isAvailable() async => false;
  @override
  Future<Either<Failure, bool>> authenticate({required String reason}) async =>
      right(false);
}

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<bool> isBiometricEnabled() async => false;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  final overrides = [
    biometricServiceProvider.overrideWithValue(_FakeBiometric()),
    authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
  ];

  testWidgets('renders email and password fields', (tester) async {
    await tester
        .pumpWidget(buildTestWidget(const LoginPage(), overrides: overrides));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    await tester
        .pumpWidget(buildTestWidget(const LoginPage(), overrides: overrides));
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('rejects invalid email format', (tester) async {
    await tester
        .pumpWidget(buildTestWidget(const LoginPage(), overrides: overrides));
    await tester.pump();

    await tester.enterText(
        find.byType(TextFormField).first, 'not-an-email');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Enter a valid email address'), findsOneWidget);
  });
}
