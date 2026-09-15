import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

class MockStorage extends HubSightSecureStorage {
  String? accessToken;
  String? refreshToken;

  @override
  Future<String?> getAccessToken() async => accessToken;
  @override
  Future<String?> getRefreshToken() async => refreshToken;
  @override
  Future<void> saveTokens(
      {required String accessToken, String? refreshToken}) async {
    this.accessToken = accessToken;
    if (refreshToken != null) this.refreshToken = refreshToken;
  }

  @override
  Future<void> clearTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

void main() {
  group('HubSightAuthManager Tests', () {
    late HubSightApiClient client;
    late MockStorage storage;
    late HubSightAuthManager authManager;
    late _MockAuthManagerAdapter mockAdapter;

    setUp(() {
      storage = MockStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://cctv.quoctran.space'));
      mockAdapter = _MockAuthManagerAdapter();
      dio.httpClientAdapter = mockAdapter;

      client = HubSightApiClient(
        baseUrl: 'https://cctv.quoctran.space',
        apiKey: 'test_api_key',
        storage: storage,
        customDio: dio,
      );

      authManager = HubSightAuthManager(client: client, storage: storage);
    });

    test('login directly succeeds and saves tokens and profile', () async {
      final res = await authManager.login(
        username: 'admin',
        password: 'correct_password',
      );

      expect(res.isSuccess, isTrue);
      expect(res.requires2FA, isFalse);
      expect(res.accessToken, equals('jwt_access_token_123'));
      expect(storage.accessToken, equals('jwt_access_token_123'));
      expect(storage.refreshToken, equals('ref_token_123'));

      expect(res.user?.username, equals('admin'));
      expect(res.user?.role, equals('admin'));
      expect(authManager.currentUser?.fullName, equals('Quản trị viên'));
    });

    test('login returns 2FA challenge when required', () async {
      final res = await authManager.login(
        username: 'user_with_2fa',
        password: 'correct_password',
      );

      expect(res.isSuccess, isFalse);
      expect(res.requires2FA, isTrue);
      expect(res.preAuthToken, equals('pre_auth_tok_81726354'));
      expect(storage.accessToken, isNull);
    });

    test('verify2FA exchanges pre-auth token for session', () async {
      final res = await authManager.verify2FA(
        preAuthToken: 'pre_auth_tok_81726354',
        code: '123456',
      );

      expect(res.isSuccess, isTrue);
      expect(res.accessToken, equals('jwt_access_token_2fa_ok'));
      expect(storage.accessToken, equals('jwt_access_token_2fa_ok'));
    });

    test('getProfile queries user profile and updates currentUser', () async {
      final profile = await authManager.getProfile();
      expect(profile.username, equals('admin'));
      expect(profile.role, equals('admin'));
      expect(profile.hasPermission('cameras:view'), isTrue);
    });

    test('updateProfile updates user info', () async {
      final updated = await authManager.updateProfile(fullName: 'Nguyen Van A');
      expect(updated.fullName, equals('Nguyen Van A'));
    });

    test('listSessions retrieves active user sessions', () async {
      final sessions = await authManager.listSessions();
      expect(sessions.length, equals(1));
      expect(sessions[0].id, equals('sess_001'));
      expect(sessions[0].isCurrent, isTrue);
      expect(sessions[0].geoCity, equals('Hue'));
      expect(sessions[0].geoCountry, equals('Vietnam'));
      expect(sessions[0].geoRegion, equals('Thua Thien Hue'));
      expect(sessions[0].geoLatitude, equals(16.4637));
      expect(sessions[0].geoLongitude, equals(107.5909));
      expect(sessions[0].geoAccuracy, equals(15.0));
      expect(sessions[0].ipAddress, equals('14.162.140.21'));
      expect(sessions[0].deviceFingerprint, equals('fp_abc123'));
      expect(sessions[0].deviceLabel, equals('iPhone 15 Pro'));
      expect(sessions[0].clientType, equals('mobile_ios'));

      final json = sessions[0].toJson();
      expect(json['geo_city'], equals('Hue'));
      expect(json['geo_latitude'], equals(16.4637));
    });

    test('login with geolocation attaches coordinates to login payload',
        () async {
      final res = await authManager.login(
        username: 'admin',
        password: 'correct_password',
        latitude: 10.7769,
        longitude: 106.7009,
        accuracy: 5.0,
        geoCity: 'Ho Chi Minh City',
        geoCountry: 'Vietnam',
      );

      expect(res.isSuccess, isTrue);
      final deviceInfo =
          mockAdapter.lastLoginPayload?['device_info'] as Map<String, dynamic>?;
      expect(deviceInfo, isNotNull);
      expect(deviceInfo?['latitude'], equals(10.7769));
      expect(deviceInfo?['longitude'], equals(106.7009));
      expect(deviceInfo?['accuracy'], equals(5.0));
      expect(deviceInfo?['geo_city'], equals('Ho Chi Minh City'));
      expect(deviceInfo?['geo_country'], equals('Vietnam'));

      final headers = mockAdapter.lastRequestOptions?.headers ?? {};
      expect(headers.containsKey('X-Device-Fingerprint'), isFalse);
      expect(headers.containsKey('X-Device-Label'), isFalse);
      expect(headers.containsKey('X-Client-Type'), isFalse);
    });

    test('verify2FA with geolocation passes coordinates into 2fa payload',
        () async {
      final res = await authManager.verify2FA(
        preAuthToken: 'pre_auth_tok_81726354',
        code: '123456',
        latitude: 21.0285,
        longitude: 105.8542,
        geoCity: 'Hanoi',
      );

      expect(res.isSuccess, isTrue);
      final deviceInfo =
          mockAdapter.last2faPayload?['device_info'] as Map<String, dynamic>?;
      expect(deviceInfo, isNotNull);
      expect(deviceInfo?['latitude'], equals(21.0285));
      expect(deviceInfo?['longitude'], equals(105.8542));
      expect(deviceInfo?['geo_city'], equals('Hanoi'));

      final headers = mockAdapter.lastRequestOptions?.headers ?? {};
      expect(headers.containsKey('X-Device-Fingerprint'), isFalse);
      expect(headers.containsKey('X-Device-Label'), isFalse);
      expect(headers.containsKey('X-Client-Type'), isFalse);
    });

    test('revokeSession revokes session', () async {
      await expectLater(authManager.revokeSession('sess_001'), completes);
    });

    test('logout revokes remote session and clears tokens', () async {
      storage.accessToken = 'some_token';
      await authManager.logout();
      expect(storage.accessToken, isNull);
      expect(authManager.currentUser, isNull);
    });

    test('HubSightJWTClaims correctly parses valid JWT token', () {
      const validJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAic3ViIjogInVzcl8wMDEiLCAidXNlcm5hbWUiOiAiYWRtaW4iLCAicm9sZSI6ICJhZG1pbiIsICJzZXNzaW9uX2lkIjogInNlc3NfMDAxIiwgImlzcyI6ICJodWJzaWdodC1hdXRoLXNlcnZpY2UiLCAiZXhwIjogMjUyNDYwODAwMCwgImlhdCI6IDE3ODkwMDAwMDAgfQ.c2lnbmF0dXJl';

      final claims = HubSightJWTClaims.tryParse(validJwt);
      expect(claims, isNotNull);
      expect(claims!.userId, equals('usr_001'));
      expect(claims.username, equals('admin'));
      expect(claims.role, equals('admin'));
      expect(claims.sessionId, equals('sess_001'));
      expect(claims.iss, equals('hubsight-auth-service'));
      expect(claims.isExpired, isFalse);
    });

    test('HubSightJWTClaims detects expired JWT token', () {
      const expiredJwt =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAic3ViIjogInVzcl8wMDEiLCAidXNlcm5hbWUiOiAiYWRtaW4iLCAicm9sZSI6ICJhZG1pbiIsICJzZXNzaW9uX2lkIjogInNlc3NfMDAxIiwgImlzcyI6ICJodWJzaWdodC1hdXRoLXNlcnZpY2UiLCAiZXhwIjogMTAwMDAwMDAwMCwgImlhdCI6IDkwMDAwMDAwMCB9.c2lnbmF0dXJl';

      final claims = HubSightJWTClaims.tryParse(expiredJwt);
      expect(claims, isNotNull);
      expect(claims!.isExpired, isTrue);
    });

    test('authManager.getClaims decodes claims from stored token', () async {
      storage.accessToken =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAic3ViIjogInVzcl8wMDEiLCAidXNlcm5hbWUiOiAiYWRtaW4iLCAicm9sZSI6ICJhZG1pbiIsICJzZXNzaW9uX2lkIjogInNlc3NfMDAxIiwgImlzcyI6ICJodWJzaWdodC1hdXRoLXNlcnZpY2UiLCAiZXhwIjogMjUyNDYwODAwMCwgImlhdCI6IDE3ODkwMDAwMDAgfQ.c2lnbmF0dXJl';

      final claims = await authManager.getClaims();
      expect(claims, isNotNull);
      expect(claims!.username, equals('admin'));
      expect(claims.role, equals('admin'));
    });

    test('getPasskeyLoginOptions calls App API passkey options endpoint',
        () async {
      final options = await authManager.getPasskeyLoginOptions('admin');
      expect(options['status'], equals('ok'));
      expect(options['challenge_id'], equals('ch_123'));
      expect(mockAdapter.lastRequestOptions?.path,
          equals(Endpoints.authPasskeyLoginOptions));
    });

    test('verifyPasskeyLogin calls App API passkey verify and saves tokens',
        () async {
      final res = await authManager.verifyPasskeyLogin(
        challengeId: 'ch_123',
        credential: '{"id":"cred_123"}',
      );

      expect(res.isSuccess, isTrue);
      expect(res.tokenType, equals('Bearer'));
      expect(res.accessToken, equals('jwt_access_token_passkey_ok'));
      expect(storage.accessToken, equals('jwt_access_token_passkey_ok'));
      expect(mockAdapter.lastRequestOptions?.path,
          equals(Endpoints.authPasskeyLoginVerify));
    });
  });
}

class _MockAuthManagerAdapter implements HttpClientAdapter {
  Map<String, dynamic>? lastLoginPayload;
  Map<String, dynamic>? last2faPayload;
  RequestOptions? lastRequestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    final path = options.path;

    if (path == Endpoints.authLogin) {
      final data = options.data as Map;
      lastLoginPayload = Map<String, dynamic>.from(data);
      if (data['username'] == 'user_with_2fa') {
        return ResponseBody.fromString(
          jsonEncode({
            'status': '2fa_required',
            'requires_2fa': true,
            'pre_auth_token': 'pre_auth_tok_81726354',
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      }

      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'access_token': 'jwt_access_token_123',
          'refresh_token': 'ref_token_123',
          'user': {
            'id': 'usr_001',
            'username': 'admin',
            'full_name': 'Quản trị viên',
            'role': 'admin',
            'permissions': ['*'],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.auth2faVerify) {
      last2faPayload = Map<String, dynamic>.from(options.data as Map);
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'access_token': 'jwt_access_token_2fa_ok',
          'refresh_token': 'ref_token_2fa_ok',
          'user': {
            'id': 'usr_001',
            'username': 'admin',
            'full_name': 'Quản trị viên',
            'role': 'admin',
            'permissions': ['*'],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.profile) {
      if (options.method == 'PATCH') {
        final data = options.data as Map;
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'ok',
            'user': {
              'id': 'usr_001',
              'username': 'admin',
              'full_name': data['full_name'] ?? 'Quản trị viên',
              'role': 'admin',
              'permissions': ['*'],
            },
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      }

      return ResponseBody.fromString(
        jsonEncode({
          'id': 'usr_001',
          'username': 'admin',
          'full_name': 'Quản trị viên',
          'role': 'admin',
          'permissions': ['*'],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.profileSessions) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'sessions': [
            {
              'id': 'sess_001',
              'client_id': 'app_client_mobile',
              'is_pwa': false,
              'is_current': true,
              'expires_at': '2026-09-10T12:00:00Z',
              'created_at': '2026-09-09T12:00:00Z',
              'geo_city': 'Hue',
              'geo_country': 'Vietnam',
              'geo_region': 'Thua Thien Hue',
              'geo_latitude': 16.4637,
              'geo_longitude': 107.5909,
              'geo_accuracy': 15.0,
              'ip_address': '14.162.140.21',
              'user_agent': 'HubSightMobile/1.0',
              'device_fingerprint': 'fp_abc123',
              'device_label': 'iPhone 15 Pro',
              'client_type': 'mobile_ios',
              'is_new_device': false,
              'is_active': true,
            }
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.profileSessionRevoke('sess_001') ||
        path == Endpoints.authLogout) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'message': 'success'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.authPasskeyLoginOptions) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'challenge_id': 'ch_123'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.authPasskeyLoginVerify) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'token_type': 'Bearer',
          'access_token': 'jwt_access_token_passkey_ok',
          'refresh_token': 'ref_token_passkey_ok',
          'expires_in': 604800,
          'user': {
            'id': 'usr_001',
            'username': 'admin',
            'full_name': 'Quản trị viên',
            'role': 'admin',
            'permissions': ['*'],
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}
