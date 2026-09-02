import 'package:flutter_test/flutter_test.dart';
import 'package:finora/features/auth/data/models/auth_user_model.dart';

void main() {
  group('AuthUserModel cache round-trip', () {
    test('toCache → fromCache preserves fields', () {
      final model = AuthUserModel(
        id: 'u1',
        email: 'jane@gmail.com',
        displayName: 'Jane',
        avatarUrl: 'https://x/y.png',
        isEmailVerified: true,
        createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

      final restored = AuthUserModel.fromCache(model.toCache());

      expect(restored.id, model.id);
      expect(restored.email, model.email);
      expect(restored.displayName, model.displayName);
      expect(restored.avatarUrl, model.avatarUrl);
      expect(restored.isEmailVerified, isTrue);
      expect(restored.createdAt, model.createdAt);
    });

    test('handles null optionals', () {
      const model = AuthUserModel(id: 'u2', email: 'a@b.com');
      final restored = AuthUserModel.fromCache(model.toCache());
      expect(restored.displayName, isNull);
      expect(restored.createdAt, isNull);
      expect(restored.isEmailVerified, isFalse);
    });
  });
}
