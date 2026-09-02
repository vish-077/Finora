import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:finora/features/auth/domain/entities/auth_user.dart';

/// Data-layer model. Maps between Supabase [User], Hive cache JSON, and the
/// domain [AuthUser] entity.
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    super.displayName,
    super.avatarUrl,
    super.isEmailVerified,
    super.createdAt,
  });

  factory AuthUserModel.fromSupabase(User user) => AuthUserModel(
        id: user.id,
        email: user.email ?? '',
        displayName: user.userMetadata?['display_name'] as String?,
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        isEmailVerified: user.emailConfirmedAt != null,
        createdAt: DateTime.tryParse(user.createdAt),
      );

  factory AuthUserModel.fromCache(Map<String, dynamic> json) => AuthUserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isEmailVerified: json['is_email_verified'] as bool? ?? false,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'] as String),
      );

  Map<String, dynamic> toCache() => <String, dynamic>{
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'is_email_verified': isEmailVerified,
        'created_at': createdAt?.toIso8601String(),
      };
}
