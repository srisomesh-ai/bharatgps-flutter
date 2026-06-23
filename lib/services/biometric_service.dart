import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Handles Face / Fingerprint login.
///
/// Flow:
///  - after the first successful password login, the user can enable biometrics
///    -> we securely store their email+password (encrypted, on-device only)
///  - on the login page, if biometrics are enabled, we auto-prompt face/finger
///    -> on success we return the saved credentials so the app can log in
class BiometricService {
  static final _auth = LocalAuthentication();
  static const _store = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kEnabled = 'bio_enabled';
  static const _kEmail = 'bio_email';
  static const _kPass = 'bio_pass';

  /// Is the device capable of biometric auth (has hardware + enrolled face/finger)?
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported && !canCheck) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Has the user enabled biometric login (and do we have stored credentials)?
  static Future<bool> isEnabled() async {
    try {
      final v = await _store.read(key: _kEnabled);
      if (v != 'true') return false;
      final e = await _store.read(key: _kEmail);
      final p = await _store.read(key: _kPass);
      return e != null && e.isNotEmpty && p != null && p.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Save credentials + turn biometric login on.
  static Future<void> enable(String email, String password) async {
    await _store.write(key: _kEmail, value: email);
    await _store.write(key: _kPass, value: password);
    await _store.write(key: _kEnabled, value: 'true');
  }

  /// Turn off biometric login and wipe stored credentials.
  static Future<void> disable() async {
    await _store.delete(key: _kEnabled);
    await _store.delete(key: _kEmail);
    await _store.delete(key: _kPass);
  }

  /// Prompt the phone's face/fingerprint. Returns the stored credentials on
  /// success, or null if it failed / was cancelled.
  static Future<Map<String, String>?> authenticate() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Log in to BharatGPS Tracker',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow device PIN/pattern as fallback
          stickyAuth: true,
        ),
      );
      if (!ok) return null;
      final e = await _store.read(key: _kEmail);
      final p = await _store.read(key: _kPass);
      if (e == null || p == null) return null;
      return {'email': e, 'password': p};
    } catch (_) {
      return null;
    }
  }
}
