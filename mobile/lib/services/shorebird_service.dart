import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class ShorebirdService {
  static final ShorebirdService instance = ShorebirdService._internal();
  final ShorebirdUpdater _updater = ShorebirdUpdater();

  ShorebirdService._internal();

  /// Check whether the current runtime has Shorebird code push capabilities active
  bool get isShorebirdAvailable {
    return _updater.isAvailable;
  }

  /// Read current patch number applied to this device
  Future<int?> getCurrentPatchNumber() async {
    try {
      final patch = await _updater.readCurrentPatch();
      return patch?.number;
    } catch (e) {
      debugPrint('[ShorebirdService] Error reading patch: $e');
      return null;
    }
  }

  /// Check if a newer OTA code push patch is available in the release channel
  Future<bool> checkForUpdates() async {
    try {
      final status = await _updater.checkForUpdate();
      return status == UpdateStatus.outdated;
    } catch (e) {
      debugPrint('[ShorebirdService] Error checking for updates: $e');
      return false;
    }
  }

  /// Trigger silent or foreground OTA download
  Future<bool> updateAndRestartPrompt() async {
    try {
      await _updater.update();
      return true;
    } catch (e) {
      debugPrint('[ShorebirdService] Error downloading patch: $e');
      return false;
    }
  }
}
