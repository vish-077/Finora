import 'package:equatable/equatable.dart';
import 'package:finora/features/auth/domain/entities/auth_user.dart';

/// An active authenticated session (tokens + the user they belong to).
class AuthSession extends Equatable {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  List<Object?> get props => [accessToken, refreshToken, user, expiresAt];
}
