import 'package:equatable/equatable.dart';

/// Domain representation of an authenticated user (provider-agnostic).
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.isEmailVerified = false,
    this.createdAt,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final bool isEmailVerified;
  final DateTime? createdAt;

  AuthUser copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isEmailVerified,
  }) =>
      AuthUser(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, email, displayName, avatarUrl, isEmailVerified, createdAt];
}
