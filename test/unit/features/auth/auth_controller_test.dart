import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:finora/core/error/failures.dart';
import 'package:finora/features/auth/domain/entities/auth_session.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';
import 'package:finora/features/auth/domain/use_cases/restore_session_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';

/// Configurable fake — only the methods AuthController touches matter.
class FakeAuthRepository implements AuthRepository {
  Either<Failure, AuthSession?> restoreResult =
      right<Failure, AuthSession?>(null);

  @override
  Future<Either<Failure, AuthSession?>> restoreSession() async => restoreResult;

  @override
  Future<Either<Failure, Unit>> signOut() async => right(unit);

  @override
  Future<Either<Failure, AuthUser?>> refreshUser() async => right(null);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const tUser = AuthUser(
    id: 'u1',
    email: 'jane@gmail.com',
    isEmailVerified: true,
  );

  ProviderContainer makeContainer(FakeAuthRepository repo) {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        restoreSessionUseCaseProvider
            .overrideWithValue(RestoreSessionUseCase(repo)),
        signOutUseCaseProvider.overrideWithValue(SignOutUseCase(repo)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('initial state is unknown', () {
    final container = makeContainer(FakeAuthRepository());
    expect(container.read(authControllerProvider).status, AuthStatus.unknown);
  });

  test('restoreSession with no session → unauthenticated', () async {
    final container = makeContainer(FakeAuthRepository());
    await container.read(authControllerProvider.notifier).restoreSession();
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);
  });

  test('restoreSession with valid session → authenticated', () async {
    final repo = FakeAuthRepository()
      ..restoreResult = right(
        const AuthSession(accessToken: 'a', refreshToken: 'r', user: tUser),
      );
    final container = makeContainer(repo);
    await container.read(authControllerProvider.notifier).restoreSession();
    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user?.email, 'jane@gmail.com');
  });

  test('onRegistered with unverified user → authenticated directly', () {
    const unverifiedUser = AuthUser(
      id: 'u1',
      email: 'jane@gmail.com',
      isEmailVerified: false,
    );
    final container = makeContainer(FakeAuthRepository());
    container.read(authControllerProvider.notifier).onRegistered(unverifiedUser);
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  test('onRegistered with verified user → authenticated', () {
    final container = makeContainer(FakeAuthRepository());
    container.read(authControllerProvider.notifier).onRegistered(tUser);
    expect(container.read(authControllerProvider).status, AuthStatus.authenticated);
  });

  test('onAuthenticated → authenticated', () {
    final container = makeContainer(FakeAuthRepository());
    container.read(authControllerProvider.notifier).onAuthenticated(tUser);
    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
  });

  test('signOut → unauthenticated', () async {
    final container = makeContainer(FakeAuthRepository());
    container.read(authControllerProvider.notifier).onAuthenticated(tUser);
    await container.read(authControllerProvider.notifier).signOut();
    expect(container.read(authControllerProvider).status,
        AuthStatus.unauthenticated);
  });
}
