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

  final FlutterSecureStorage _storage;

  HubSightSecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
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
    await _storage.write(key: _keyConfigUrls, value: jsonEncode(config.urls.toMap()));
    await _storage.write(key: _keyConfigKey, value: jsonEncode(config.key.toMap()));
    await _storage.write(key: _keyConfigMetadata, value: jsonEncode(config.metadata.toMap()));
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
      final urls = HubSightUrls.fromMap(jsonDecode(urlsJson) as Map<String, dynamic>);
      final key = HubSightClientKey.fromMap(jsonDecode(keyJson) as Map<String, dynamic>);
      final meta = HubSightConfigMetadata.fromMap(jsonDecode(metaJson) as Map<String, dynamic>);

      return HubSightAppConfig(
        urls: urls,
        key: key,
        metadata: meta,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clear all persisted configurations and tokens.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
