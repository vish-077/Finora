import 'dart:io';

import 'package:finora/core/storage/app_database.dart';
import 'package:finora/core/storage/sql_box.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finora/core/constants/storage_constants.dart';
import 'package:finora/core/logging/log_service.dart';

/// Raised when a chosen picture cannot be used as an avatar.
class AvatarException implements Exception {
  const AvatarException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Stores the user's profile picture on disk and remembers the path.
///
/// Images are capped at 1 MB. Rather than rejecting a large photo outright we
/// first downscale/re-encode it — a modern phone camera shot is several MB but
/// compresses well under the cap, so most picks succeed. Only if the result is
/// still over 1 MB do we surface an error.
class AvatarService {
  AvatarService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int maxBytes = 1024 * 1024; // 1 MB
  static const int _maxDimension = 512;

  /// Pre-fix key that stored a single avatar for the whole device, which meant
  /// one account's photo showed up on every other account (including guest).
  /// Read only to clean it up.
  static const String _legacyKey = 'avatar_path';

  /// Avatars are stored per account. Guest mode uses the `local-user` id, so it
  /// keeps its own picture instead of inheriting the last signed-in user's.
  static String _keyFor(String userId) => 'avatar_path_$userId';

  static String _fileNameFor(String userId) {
    // Ids can contain characters that are illegal in a filename.
    final safe = userId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'profile_avatar_$safe.jpg';
  }

  /// Null when the settings box is not open — the avatar is read by shared
  /// chrome that can be built without Hive (widget tests, error fallbacks).
  SqlBox? get _box {
    try {
      return AppDatabase.box(StorageBoxes.settings);
    } catch (_) {
      return null;
    }
  }

  /// The avatar belonging to [userId], or null when unset or the file is gone.
  File? currentAvatar(String userId) {
    _discardLegacyAvatar();
    final path = _box?.get(_keyFor(userId)) as String?;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  /// Removes the old device-wide avatar entry.
  ///
  /// It is dropped rather than migrated: there is no way to tell which account
  /// it belonged to, and guessing wrong would show one person's photo on
  /// somebody else's profile — the exact bug being fixed.
  void _discardLegacyAvatar() {
    final box = _box;
    if (box == null || !box.containsKey(_legacyKey)) return;

    final path = box.get(_legacyKey) as String?;
    if (path != null && path.isNotEmpty) {
      try {
        final legacyFile = File(path);
        if (legacyFile.existsSync()) legacyFile.deleteSync();
      } catch (e) {
        LogService.w('Could not delete legacy avatar file: $e');
      }
    }
    box.delete(_legacyKey);
    LogService.i('Cleared device-wide avatar; avatars are now per account');
  }

  /// Opens the picker, validates and persists the result.
  ///
  /// Returns null when the user backs out without choosing anything.
  Future<File?> pickAndSave({
    required ImageSource source,
    required String userId,
  }) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
      imageQuality: 85,
    );
    if (picked == null) return null;

    final raw = await picked.readAsBytes();

    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const AvatarException(
        'That file is not a readable image. Try a JPG or PNG.',
      );
    }

    // Square-crop to the centre so the circular frame never lops off a face
    // at a weird offset, then downscale.
    final side = decoded.width < decoded.height ? decoded.width : decoded.height;
    final square = img.copyCrop(
      decoded,
      x: (decoded.width - side) ~/ 2,
      y: (decoded.height - side) ~/ 2,
      width: side,
      height: side,
    );
    final resized = img.copyResize(square, width: _maxDimension);

    // Step the quality down until it fits the cap.
    List<int> bytes = img.encodeJpg(resized, quality: 88);
    for (final quality in const [70, 55, 40]) {
      if (bytes.length <= maxBytes) break;
      bytes = img.encodeJpg(resized, quality: quality);
    }

    if (bytes.length > maxBytes) {
      final mb = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
      throw AvatarException(
        'Image is too large (${mb}MB) even after compression. '
        'Please pick one under 1MB.',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${_fileNameFor(userId)}');

    // Overwrite in place, then bust Flutter's decoded-image cache so the new
    // picture actually appears (same path = same cache key).
    await file.writeAsBytes(bytes, flush: true);
    await _box?.put(_keyFor(userId), file.path);

    LogService.i('Avatar saved (${bytes.length} bytes) → ${file.path}');
    return file;
  }

  /// Forgets and deletes [userId]'s avatar, leaving other accounts untouched.
  Future<void> remove(String userId) async {
    final existing = currentAvatar(userId);
    if (existing != null) {
      try {
        await existing.delete();
      } catch (e) {
        LogService.e('Could not delete avatar file: $e');
      }
    }
    await _box?.delete(_keyFor(userId));
  }
}
