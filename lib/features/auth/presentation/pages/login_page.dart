import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/core/constants/route_constants.dart';
import 'package:finora/core/theme/app_spacing.dart';
import 'package:finora/core/utils/validators.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_form_controllers.dart';
import 'package:finora/features/auth/presentation/viewmodels/auth_providers.dart';
import 'package:finora/features/auth/presentation/widgets/auth_feedback.dart';
import 'package:finora/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:finora/shared/widgets/finora_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _biometricReady = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await ref.read(biometricServiceProvider).isAvailable();
    final enabled = await ref.read(authRepositoryProvider).isBiometricEnabled();
    if (mounted) setState(() => _biometricReady = available && enabled);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(loginControllerProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    if (ok) {
      showAuthSnack(context, 'Welcome back!');
    } else {
      final err = ref.read(loginControllerProvider).error;
      showAuthSnack(context, failureMessage(err), isError: true);
    }
  }

  Future<void> _biometricLogin() async {
    final ok = await ref
        .read(loginControllerProvider.notifier)
        .loginWithBiometrics();
    if (!mounted) return;
    if (!ok) {
      final err = ref.read(loginControllerProvider).error;
      if (err != null) showAuthSnack(context, failureMessage(err), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSpacing.vLg,
                  Text('Welcome back',
                      style: Theme.of(context).textTheme.headlineSmall),
                  AppSpacing.vXs,
                  Text('Sign in to continue',
                      style: Theme.of(context).textTheme.bodyMedium),
                  AppSpacing.vXl,
                  AuthTextField(
                    controller: _email,
                    label: 'Email',
                    hint: 'you@gmail.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                    enabled: !isLoading,
                  ),
                  AppSpacing.vMd,
                  AuthTextField(
                    controller: _password,
                    label: 'Password',
                    hint: 'Your password',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    validator: Validators.loginPassword,
                    enabled: !isLoading,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () => context.push(Routes.forgotPassword),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  AppSpacing.vSm,
                  FinoraButton(
                    label: 'Sign in',
                    isLoading: isLoading,
                    onPressed: _submit,
                  ),
                  if (_biometricReady) ...[
                    AppSpacing.vMd,
                    FinoraButton(
                      label: 'Use biometrics',
                      variant: FinoraButtonVariant.outline,
                      icon: const Icon(Icons.fingerprint),
                      onPressed: isLoading ? null : _biometricLogin,
                    ),
                  ],
                  AppSpacing.vLg,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push(Routes.register),
                        child: const Text('Sign up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
