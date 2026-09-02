import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:finora/features/auth/presentation/viewmodels/auth_controller.dart';
import 'package:finora/features/profile/data/services/avatar_service.dart';

final avatarServiceProvider = Provider<AvatarService>((ref) => AvatarService());

/// The current account's avatar. `null` means "no picture set" — the UI falls
/// back to the initial-letter circle.
class AvatarNotifier extends Notifier<File?> {
  /// Guest mode reports `local-user`, giving it its own avatar slot.
  String get _userId =>
      ref.read(authControllerProvider).user?.id ?? 'local-user';

  @override
  File? build() {
    // Watching auth means signing out or switching accounts re-reads the
    // avatar, instead of leaving the previous user's photo on screen.
    final userId =
        ref.watch(authControllerProvider).user?.id ?? 'local-user';
    return ref.read(avatarServiceProvider).currentAvatar(userId);
  }

  /// Picks a new avatar. Returns an error message on failure, null on success
  /// or when the user cancelled.
  Future<String?> pick(ImageSource source) async {
    try {
      final file = await ref.read(avatarServiceProvider).pickAndSave(
            source: source,
            userId: _userId,
          );
      if (file == null) return null; // cancelled

      // The path is stable across changes, so Flutter would otherwise serve the
      // previous picture straight out of its image cache.
      await FileImage(file).evict();
      imageCache.clear();
      imageCache.clearLiveImages();

      state = null; // force listeners off the old identical File instance
      state = file;
      return null;
    } on AvatarException catch (e) {
      return e.message;
    } catch (e) {
      return 'Could not update profile picture: $e';
    }
  }

  Future<void> remove() async {
    final existing = state;
    await ref.read(avatarServiceProvider).remove(_userId);
    if (existing != null) await FileImage(existing).evict();
    imageCache.clear();
    state = null;
  }
}

final avatarProvider = NotifierProvider<AvatarNotifier, File?>(
  AvatarNotifier.new,
);
