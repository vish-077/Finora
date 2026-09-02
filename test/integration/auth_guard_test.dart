import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/core/navigation/app_router.dart';
import 'package:finora/features/auth/domain/entities/auth_session.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';
import 'package:finora/features/auth/domain/use_cases/restore_session_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';

class _FakeAuthRepo implements AuthRepository {
  Either<Failure, AuthSession?> restoreResult =
      right<Failure, AuthSession?>(null);

  @override
  Future<Either<Failure, AuthSession?>> restoreSession() async => restoreResult;
  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<void> _pumpApp(WidgetTester tester, _FakeAuthRepo repo) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      restoreSessionUseCaseProvider
          .overrideWithValue(RestoreSessionUseCase(repo)),
      signOutUseCaseProvider.overrideWithValue(SignOutUseCase(repo)),
    ],
  );
  addTearDown(container.dispose);

  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const tUser = AuthUser(id: 'u1', email: 'jane@gmail.com', isEmailVerified: true);

  testWidgets('unauthenticated user is redirected to Welcome', (tester) async {
    await _pumpApp(tester, _FakeAuthRepo());
    expect(find.textContaining('Welcome to'), findsOneWidget);
  });

  testWidgets('authenticated user lands on the app shell (Dashboard)',
      (tester) async {
    final repo = _FakeAuthRepo()
      ..restoreResult = right(
        const AuthSession(accessToken: 'a', refreshToken: 'r', user: tUser),
      );
    await _pumpApp(tester, repo);
    expect(find.textContaining('Here’s your money'), findsWidgets);
  });
}
