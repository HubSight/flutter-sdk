import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Secure token & credentials storage using Keychain (iOS/macOS) and Keystore (Android).
class HubSightSecureStorage {
  static const String _keyAccessToken = 'hs_access_token';
  static const String _keyRefreshToken = 'hs_refresh_token';
  static const String _keyConfigUrls = 'hs_config_urls';
  static const String _keyConfigKey = 'hs_config_key';
  static const String _keyConfigMetadata = 'hs_config_metadata';
  static const String _keyBioUsername = 'hs_bio_username';
  static const String _keyBioPassword = 'hs_bio_password';
  static const String _keyLastUsername = 'hs_last_username';

  final FlutterSecureStorage _storage;

  HubSightSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  /// Save access and refresh tokens.
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
  }

  /// Retrieve current access token.
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  /// Retrieve current refresh token.
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }

  /// Clear all stored tokens (on logout or session expiry).
  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  /// Save decrypted AppConfig into secure storage.
  Future<void> saveAppConfig(HubSightAppConfig config) async {
    await _storage.write(
        key: _keyConfigUrls, value: jsonEncode(config.urls.toMap()));
    await _storage.write(
        key: _keyConfigKey, value: jsonEncode(config.key.toMap()));
    await _storage.write(
        key: _keyConfigMetadata, value: jsonEncode(config.metadata.toMap()));
  }

  /// Load cached AppConfig if available.
  Future<HubSightAppConfig?> getSavedAppConfig() async {
    final urlsJson = await _storage.read(key: _keyConfigUrls);
    final keyJson = await _storage.read(key: _keyConfigKey);
    final metaJson = await _storage.read(key: _keyConfigMetadata);

    if (urlsJson == null || keyJson == null || metaJson == null) {
      return null;
    }

    try {
      final urls =
          HubSightUrls.fromMap(jsonDecode(urlsJson) as Map<String, dynamic>);
      final key = HubSightClientKey.fromMap(
          jsonDecode(keyJson) as Map<String, dynamic>);
      final meta = HubSightConfigMetadata.fromMap(
          jsonDecode(metaJson) as Map<String, dynamic>);

      return HubSightAppConfig(
        urls: urls,
        key: key,
        metadata: meta,
      );
    } catch (_) {
      return null;
    }
  }

  /// Save credentials for quick biometric sign-in.
  Future<void> saveBiometricCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.write(key: _keyBioUsername, value: username);
    await _storage.write(key: _keyBioPassword, value: password);
    await saveLastUsername(username);
  }

  /// Retrieve saved biometric sign-in credentials.
  Future<Map<String, String>?> getBiometricCredentials() async {
    final username = await _storage.read(key: _keyBioUsername);
    final password = await _storage.read(key: _keyBioPassword);
    if (username != null &&
        username.isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  /// Check if biometric sign-in credentials are saved.
  Future<bool> hasBiometricCredentials() async {
    final creds = await getBiometricCredentials();
    return creds != null;
  }

  /// Clear stored biometric sign-in credentials.
  Future<void> clearBiometricCredentials() async {
    await _storage.delete(key: _keyBioUsername);
    await _storage.delete(key: _keyBioPassword);
  }

  /// Save last successfully logged-in username for autofill.
  Future<void> saveLastUsername(String username) async {
    await _storage.write(key: _keyLastUsername, value: username);
  }

  /// Retrieve last successfully logged-in username.
  Future<String?> getLastUsername() async {
    return await _storage.read(key: _keyLastUsername);
  }

  /// Clear all persisted configurations and tokens.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
