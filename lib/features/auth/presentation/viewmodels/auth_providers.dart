import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:finora/core/di/injection_container.dart';
import 'package:finora/core/security/biometric_service.dart';
import 'package:finora/features/auth/domain/repositories/auth_repository.dart';
import 'package:finora/features/auth/domain/use_cases/authenticate_biometric_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/resend_verification_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/restore_session_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/send_password_reset_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_in_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_out_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/sign_up_use_case.dart';
import 'package:finora/features/auth/domain/use_cases/update_password_use_case.dart';

import 'package:finora/features/auth/data/sources/auth_local_source.dart';

part 'auth_providers.g.dart';

@riverpod
AuthLocalSource authLocalSource(AuthLocalSourceRef ref) => sl<AuthLocalSource>();

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => sl<AuthRepository>();

@riverpod
BiometricService biometricService(BiometricServiceRef ref) =>
    sl<BiometricService>();

@riverpod
SignInUseCase signInUseCase(SignInUseCaseRef ref) => sl<SignInUseCase>();

@riverpod
SignUpUseCase signUpUseCase(SignUpUseCaseRef ref) => sl<SignUpUseCase>();

@riverpod
SignOutUseCase signOutUseCase(SignOutUseCaseRef ref) => sl<SignOutUseCase>();

@riverpod
RestoreSessionUseCase restoreSessionUseCase(RestoreSessionUseCaseRef ref) =>
    sl<RestoreSessionUseCase>();

@riverpod
SendPasswordResetUseCase sendPasswordResetUseCase(
        SendPasswordResetUseCaseRef ref) =>
    sl<SendPasswordResetUseCase>();

@riverpod
UpdatePasswordUseCase updatePasswordUseCase(UpdatePasswordUseCaseRef ref) =>
    sl<UpdatePasswordUseCase>();

@riverpod
ResendVerificationUseCase resendVerificationUseCase(
        ResendVerificationUseCaseRef ref) =>
    sl<ResendVerificationUseCase>();

@riverpod
AuthenticateBiometricUseCase authenticateBiometricUseCase(
        AuthenticateBiometricUseCaseRef ref) =>
    sl<AuthenticateBiometricUseCase>();
