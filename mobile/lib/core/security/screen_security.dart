import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ScreenSecurityService {
  static const MethodChannel _channel = MethodChannel('uz.lexguard/security');

  Future<void> setFlagSecure(bool enabled) async {
    try {
      await _channel.invokeMethod<bool>('setSecureFlag', {'enabled': enabled});
    } on MissingPluginException {
      // Safe no-op on Web/Desktop platforms without Android FLAG_SECURE.
    } on PlatformException {
      // Non-fatal fallback.
    }
  }
}

class SecureTokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _refreshKey = 'lexguard_refresh_token';
  String? _inMemoryAccessToken;
  String? _fallbackRefreshToken;

  String? get accessToken => _inMemoryAccessToken;

  void setAccessToken(String? token) {
    _inMemoryAccessToken = token;
  }

  Future<void> saveRefreshToken(String token) async {
    _fallbackRefreshToken = token;
    try {
      await _storage.write(key: _refreshKey, value: token);
    } catch (_) {
      // Safe in-memory fallback for environments without keystore support.
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshKey) ?? _fallbackRefreshToken;
    } catch (_) {
      return _fallbackRefreshToken;
    }
  }

  Future<void> clearAll() async {
    _inMemoryAccessToken = null;
    _fallbackRefreshToken = null;
    try {
      await _storage.delete(key: _refreshKey);
    } catch (_) {
      // Safe fallback.
    }
  }
}
