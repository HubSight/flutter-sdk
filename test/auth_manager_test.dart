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

    setUp(() {
      storage = MockStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://cctv.quoctran.space'));
      dio.httpClientAdapter = _MockAuthManagerAdapter();

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

    test('login with geolocation attaches coordinates to device metadata',
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
      expect(client.deviceMetadata?.latitude, equals(10.7769));
      expect(client.deviceMetadata?.longitude, equals(106.7009));
      expect(client.deviceMetadata?.accuracy, equals(5.0));
      expect(client.deviceMetadata?.geoCity, equals('Ho Chi Minh City'));
      expect(client.deviceMetadata?.geoCountry, equals('Vietnam'));
      expect(client.deviceMetadata?.toMap()['latitude'], equals(10.7769));
      expect(client.deviceMetadata?.toMap()['geo_city'],
          equals('Ho Chi Minh City'));
    });

    test('verify2FA with geolocation passes coordinates into device metadata',
        () async {
      final res = await authManager.verify2FA(
        preAuthToken: 'pre_auth_tok_81726354',
        code: '123456',
        latitude: 21.0285,
        longitude: 105.8542,
        geoCity: 'Hanoi',
      );

      expect(res.isSuccess, isTrue);
      expect(client.deviceMetadata?.latitude, equals(21.0285));
      expect(client.deviceMetadata?.longitude, equals(105.8542));
      expect(client.deviceMetadata?.geoCity, equals('Hanoi'));
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
  });
}

class _MockAuthManagerAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (path == Endpoints.authLogin) {
      final data = options.data as Map;
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

    return ResponseBody.fromString('{}', 404);
  }

  @override
  void close({bool force = false}) {}
}
