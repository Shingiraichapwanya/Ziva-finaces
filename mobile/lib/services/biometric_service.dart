import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final BiometricService instance = BiometricService._internal();
  final LocalAuthentication _auth = LocalAuthentication();

  BiometricService._internal();

  /// Check whether biometric hardware is available on the device
  Future<bool> canAuthenticate() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Get list of available biometric modalities (Face ID, Touch ID, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return <BiometricType>[];
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return <BiometricType>[];
    }
  }

  /// Trigger Face ID / Touch ID authentication challenge with passcode fallback
  Future<bool> authenticate({
    String reason = 'Authenticate with Face ID to access your Ziva Finance portfolio and records',
  }) async {
    // Web environments do not possess mobile Face ID / Touch ID hardware
    if (kIsWeb) {
      debugPrint('[BiometricService] Web target (kIsWeb) detected. Bypassing biometric check.');
      return true;
    }

    try {
      final isAvailable = await canAuthenticate();
      if (!isAvailable) {
        // In environments without biometric hardware (e.g. basic simulator without enrolled face),
        // fallback gracefully so the user isn't permanently locked out.
        return true;
      }

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allows device PIN/passcode fallback
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
