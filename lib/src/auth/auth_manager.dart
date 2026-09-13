import 'dart:async';
import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../security/device_info_collector.dart';
import '../security/secure_storage.dart';
import 'models/auth_response.dart';
import 'models/passkey_item.dart';
import 'models/session_item.dart';
import 'models/user_profile.dart';

/// Manager for authentication lifecycle, session tracking, and user profile.
class HubSightAuthManager {
  final HubSightApiClient _client;
  final HubSightSecureStorage _storage;
  final DeviceInfoCollector _deviceCollector;

  UserProfile? _currentUser;
  final StreamController<UserProfile?> _userStreamController =
      StreamController<UserProfile?>.broadcast();

  HubSightAuthManager({
    required HubSightApiClient client,
    required HubSightSecureStorage storage,
    DeviceInfoCollector? deviceCollector,
  })  : _client = client,
        _storage = storage,
        _deviceCollector = deviceCollector ?? DeviceInfoCollector();

  Stream<UserProfile?> get onUserChanged => _userStreamController.stream;
  UserProfile? get currentUser => _currentUser;

  /// Check if user has an active session in local storage.
  Future<bool> get isAuthenticated async {
    final token = await _storage.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Primary login with username, password, optional geolocation, and automatic device fingerprinting.
  Future<AuthResult> login({
    required String username,
    required String password,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? geoCity,
    String? geoCountry,
    String? geoRegion,
  }) async {
    final device = await _deviceCollector.collect(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      geoCity: geoCity,
      geoCountry: geoCountry,
      geoRegion: geoRegion,
    );

    final payload = {
      'username': username,
      'password': password,
      'device_name': device.deviceLabel,
      'platform': device.clientType,
      'device_id': device.fingerprint,
      'device_info': device.toMap(),
    };

    final data = await _client.post(Endpoints.authLogin, data: payload);
    final result = AuthResult.fromJson(Map<String, dynamic>.from(data as Map));

    if (result.isSuccess && result.accessToken != null) {
      await _storage.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
      );
      _currentUser = result.user;
      _userStreamController.add(_currentUser);
    }

    return result;
  }

  /// Verify TOTP code or recovery code during two-factor authentication challenge.
  Future<AuthResult> verify2FA({
    required String preAuthToken,
    required String code,
    String? recoveryCode,
    double? latitude,
    double? longitude,
    double? accuracy,
    String? geoCity,
    String? geoCountry,
    String? geoRegion,
  }) async {
    final device = await _deviceCollector.collect(
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      geoCity: geoCity,
      geoCountry: geoCountry,
      geoRegion: geoRegion,
    );

    final payload = {
      'pre_auth_token': preAuthToken,
      'code': code,
      if (recoveryCode != null && recoveryCode.isNotEmpty)
        'recovery_code': recoveryCode,
      'device_info': device.toMap(),
    };

    final data = await _client.post(Endpoints.auth2faVerify, data: payload);
    final result = AuthResult.fromJson(Map<String, dynamic>.from(data as Map));

    if (result.isSuccess && result.accessToken != null) {
      await _storage.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
      );
      _currentUser = result.user;
      _userStreamController.add(_currentUser);
    }

    return result;
  }

  /// Manually refresh access token using current refresh token.
  Future<bool> refreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final data = await _client.post(
      Endpoints.authRefresh,
      data: {'refresh_token': refreshToken},
    );

    final resMap = Map<String, dynamic>.from(data as Map);
    final newAccess = (resMap['access_token'] ?? resMap['token']) as String?;
    final newRefresh = resMap['refresh_token'] as String?;

    if (newAccess != null && newAccess.isNotEmpty) {
      await _storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh ?? refreshToken,
      );
      return true;
    }
    return false;
  }

  /// Change account password.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post(
      Endpoints.authChangePassword,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  /// Sign out current session and clear stored tokens.
  Future<void> logout() async {
    try {
      await _client.post(Endpoints.authLogout);
    } catch (_) {
      // Best effort remote revocation
    } finally {
      await _storage.clearTokens();
      _currentUser = null;
      _userStreamController.add(null);
    }
  }

  /// Fetch full user profile and permissions from server.
  Future<UserProfile> getProfile() async {
    final data = await _client.get(Endpoints.profile);
    _currentUser = UserProfile.fromJson(Map<String, dynamic>.from(data as Map));
    _userStreamController.add(_currentUser);
    return _currentUser!;
  }

  /// Update profile preferences (full name, locale, timezone, theme, push preferences).
  Future<UserProfile> updateProfile({
    String? fullName,
    String? locale,
    String? timezone,
    String? theme,
    Map<String, bool>? pushPreferences,
  }) async {
    final payload = <String, dynamic>{
      if (fullName != null) 'full_name': fullName,
      if (locale != null) 'locale': locale,
      if (timezone != null) 'timezone': timezone,
      if (theme != null) 'theme': theme,
      if (pushPreferences != null) 'push_preferences': pushPreferences,
    };

    final data = await _client.patch(Endpoints.profile, data: payload);
    final userMap = (data as Map)['user'] as Map<String, dynamic>? ??
        Map<String, dynamic>.from(data);
    _currentUser = UserProfile.fromJson(userMap);
    _userStreamController.add(_currentUser);
    return _currentUser!;
  }

  /// List active sessions across all devices for this account.
  Future<List<SessionItem>> listSessions() async {
    final data = await _client.get(Endpoints.profileSessions);
    final list = (data as Map)['sessions'] as List? ?? [];
    return list
        .map((e) => SessionItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Remotely revoke a specific session.
  Future<void> revokeSession(String sessionId) async {
    await _client.delete(Endpoints.profileSessionRevoke(sessionId));
  }

  // ── Passkey / FIDO2 (WebAuthn) ─────────────────────────────────────────────

  /// Fetch list of registered passkey credentials for current user.
  Future<List<PasskeyItem>> listPasskeys() async {
    final data = await _client.get(Endpoints.authPasskeys);
    final list = (data as List? ?? []);
    return list
        .map((e) => PasskeyItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Request passkey login assertion options from server.
  Future<Map<String, dynamic>> getPasskeyLoginOptions(String username) async {
    final trimmed = username.trim();
    final data = await _client.post(
      Endpoints.authPasskeyLoginOptions,
      data: {'username': trimmed},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  /// Verify passkey assertion response and establish authenticated session.
  Future<AuthResult> verifyPasskeyLogin({
    required String challengeId,
    required String credential,
    Map<String, dynamic>? customDeviceInfo,
  }) async {
    final device = await _deviceCollector.collect();

    final payload = {
      'challenge_id': challengeId,
      'credential': credential,
      'is_pwa': false,
      'device_info': customDeviceInfo ?? device.toMap(),
    };

    final data =
        await _client.post(Endpoints.authPasskeyLoginVerify, data: payload);
    final result = AuthResult.fromJson(Map<String, dynamic>.from(data as Map));

    if (result.isSuccess && result.accessToken != null) {
      await _storage.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken,
      );
      _currentUser = result.user;
      _userStreamController.add(_currentUser);
    }

    return result;
  }

  /// Request passkey registration options.
  Future<Map<String, dynamic>> getPasskeyRegisterOptions() async {
    final data = await _client.post(Endpoints.authPasskeyRegisterOptions);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Verify passkey registration assertion.
  Future<PasskeyItem> verifyPasskeyRegister({
    required String challengeId,
    required String credential,
    required String name,
  }) async {
    final data = await _client.post(
      Endpoints.authPasskeyRegisterVerify,
      data: {
        'challenge_id': challengeId,
        'credential': credential,
        'name': name,
      },
    );
    final resMap = Map<String, dynamic>.from(data as Map);
    final passkeyMap = resMap['passkey'] != null
        ? Map<String, dynamic>.from(resMap['passkey'] as Map)
        : resMap;
    return PasskeyItem.fromJson(passkeyMap);
  }

  /// Rename a registered passkey.
  Future<void> renamePasskey(String id, String name) async {
    await _client.put(Endpoints.authPasskeyItem(id), data: {'name': name});
  }

  /// Delete/revoke a registered passkey.
  Future<void> deletePasskey(String id) async {
    await _client.delete(Endpoints.authPasskeyItem(id));
  }

  // ── Quick Biometric Login ──────────────────────────────────────────────────

  /// Save credentials securely for biometric sign-in.
  Future<void> saveBiometricCredentials({
    required String username,
    required String password,
  }) async {
    await _storage.saveBiometricCredentials(
      username: username,
      password: password,
    );
  }

  /// Retrieve stored biometric credentials.
  Future<Map<String, String>?> getBiometricCredentials() async {
    return await _storage.getBiometricCredentials();
  }

  /// Check whether biometric credentials exist in secure storage.
  Future<bool> hasBiometricCredentials() async {
    return await _storage.hasBiometricCredentials();
  }

  /// Remove stored biometric credentials.
  Future<void> clearBiometricCredentials() async {
    await _storage.clearBiometricCredentials();
  }

  /// Perform automatic login with saved biometric credentials.
  Future<AuthResult?> loginWithBiometrics() async {
    final creds = await _storage.getBiometricCredentials();
    if (creds == null) return null;
    return await login(
      username: creds['username']!,
      password: creds['password']!,
    );
  }

  /// Retrieve the last successfully used username for autofill.
  Future<String?> getLastUsername() async {
    return await _storage.getLastUsername();
  }

  void dispose() {
    _userStreamController.close();
  }
}
