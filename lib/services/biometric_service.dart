import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

enum BiometricResult {
  success,
  failed,
  cancelled,
  notAvailable,
}

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> isBiometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) return false;

      // Check if any biometric/credential is actually enrolled
      final availableBiometrics = await auth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) return false;

      return true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<BiometricResult> authenticate() async {
    if (kIsWeb) return BiometricResult.notAvailable;
    try {
      final available = await isBiometricsAvailable();
      if (!available) return BiometricResult.notAvailable;

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Vui lòng xác thực bản thân để truy cập ứng dụng',
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Xác thực sinh trắc học',
            cancelButton: 'Hủy',
          ),
          IOSAuthMessages(cancelButton: 'Hủy'),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true, // Forces native Face ID / Touch ID UI on iOS
          useErrorDialogs:
              false, // Disable plugin dialogs to ensure strictly native Dynamic Island prompt
          stickyAuth:
              false, // Let iOS handle the lifecycle naturally instead of pausing the app aggressively
        ),
      );

      return didAuthenticate ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      if (e.code == auth_error.notEnrolled ||
          e.code == auth_error.notAvailable ||
          e.code == auth_error.passcodeNotSet) {
        return BiometricResult.notAvailable;
      }
      // If none of those matched, it's typically user cancellation or fallback
      // the local_auth_darwin translates userCancel into a specific code or returns false.
      // But if we caught an exception here, it was forcefully cancelled by system or user.
      return BiometricResult.cancelled;
    } catch (_) {
      // General fallthrough fallback for iOS 14 returning false on cancel
      return BiometricResult.failed;
    }
  }
}
