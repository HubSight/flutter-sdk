import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_mobile_sdk/hubsight_sdk.dart';

class MockStorage extends HubSightSecureStorage {
  String? accessToken = 'old_expired_token';
  String? refreshToken = 'valid_refresh_token';

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
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
  group('AuthInterceptor Tests', () {
    late MockStorage mockStorage;
    late Dio dio;
    late int refreshCallCount;
    late List<MaintenanceException> maintenanceEvents;
    late int sessionExpiredCount;

    setUp(() {
      mockStorage = MockStorage();
      refreshCallCount = 0;
      maintenanceEvents = [];
      sessionExpiredCount = 0;

      dio = Dio(BaseOptions(baseUrl: 'https://test.hubsight.internal'));

      dio.interceptors.add(
        HubSightAuthInterceptor(
          dio: dio,
          storage: mockStorage,
          getApiKey: () => 'test_api_key_123',
          getDeviceMetadata: () => null,
          onMaintenance: (m) => maintenanceEvents.add(m),
          onSessionExpired: () => sessionExpiredCount++,
        ),
      );

      // Custom adapter simulating server responses
      dio.httpClientAdapter = _MockHttpClientAdapter(
        onRefreshCalled: () => refreshCallCount++,
        getStorage: () => mockStorage,
      );
    });

    test('injects X-API-Key and Bearer token into requests', () async {
      final res = await dio.get('/api/app/v1/profile');
      expect(res.statusCode, equals(200));
      expect(res.requestOptions.headers['X-API-Key'], equals('test_api_key_123'));
      expect(res.requestOptions.headers['Authorization'], equals('Bearer old_expired_token'));
    });

    test('intercepts 503 Kill-Switch and triggers onMaintenance callback', () async {
      try {
        await dio.get('/api/app/v1/killswitch-test');
        fail('Should throw MaintenanceException');
      } on DioException catch (e) {
        expect(e.error, isA<MaintenanceException>());
        final maint = e.error as MaintenanceException;
        expect(maint.retryAfterSeconds, equals(300));
        expect(maint.code, equals(HubSightErrorCode.systemMaintenance));
        expect(maint.wireCode, equals('APP_API_DISABLED'));
        expect(maintenanceEvents.length, equals(1));
      }
    });

    test('Atomic 401 Token Refresh: handles 5 concurrent requests with only 1 refresh call', () async {
      // Set initial token to trigger 401 on the first attempt
      mockStorage.accessToken = 'expired_jwt_tok';

      // Send 5 concurrent requests simultaneously
      final futures = [
        dio.get('/api/app/v1/cameras'),
        dio.get('/api/app/v1/notifications/unread-count'),
        dio.get('/api/app/v1/profile'),
        dio.get('/api/app/v1/cameras/cam_01'),
        dio.get('/api/app/v1/notifications'),
      ];

      final results = await Future.wait(futures);

      // Verify all 5 completed successfully with HTTP 200
      for (final res in results) {
        expect(res.statusCode, equals(200));
        // All replayed requests should now carry the new access token
        expect(res.requestOptions.headers['Authorization'], equals('Bearer new_refreshed_token_xyz'));
      }

      // Crucial requirement: only 1 refresh request was sent to the server!
      expect(refreshCallCount, equals(1));
      expect(mockStorage.accessToken, equals('new_refreshed_token_xyz'));
      expect(sessionExpiredCount, equals(0));
    });

    test('triggers onSessionExpired when refresh token fails', () async {
      mockStorage.accessToken = 'expired_jwt_tok';
      mockStorage.refreshToken = 'invalid_refresh_token'; // will trigger 401 on refresh

      try {
        await dio.get('/api/app/v1/cameras');
        fail('Should throw SessionExpiredException');
      } on DioException catch (e) {
        expect(e.error, isA<SessionExpiredException>());
        final exp = e.error as SessionExpiredException;
        expect(exp.code, equals(HubSightErrorCode.authSessionExpired));
        expect(exp.wireCode, equals('AUTH_SESSION_EXPIRED'));
        expect(sessionExpiredCount, equals(1));
        expect(mockStorage.accessToken, isNull);
      }
    });
  });
}

class _MockHttpClientAdapter implements HttpClientAdapter {
  final VoidCallback onRefreshCalled;
  final MockStorage Function() getStorage;

  _MockHttpClientAdapter({
    required this.onRefreshCalled,
    required this.getStorage,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    // Simulate Kill-Switch 503
    if (path.contains('killswitch-test')) {
      final jsonBody = jsonEncode({
        'status': 'error',
        'code': 'APP_API_DISABLED',
        'maintenance': true,
        'message': 'Dịch vụ đang bảo trì',
        'message_en': 'Under maintenance',
      });
      return ResponseBody.fromString(
        jsonBody,
        503,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Retry-After': ['300'],
        },
      );
    }

    // Simulate Refresh endpoint
    if (path.contains(Endpoints.authRefresh)) {
      onRefreshCalled();
      final storage = getStorage();
      if (storage.refreshToken == 'invalid_refresh_token') {
        return ResponseBody.fromString(
          jsonEncode({'error': 'invalid refresh token'}),
          401,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }

      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'access_token': 'new_refreshed_token_xyz',
          'refresh_token': 'new_refresh_token_abc',
          'expires_in': 3600,
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // Normal endpoints
    final authHeader = options.headers['Authorization'] as String?;
    if (authHeader == 'Bearer expired_jwt_tok') {
      return ResponseBody.fromString(
        jsonEncode({'error': 'Unauthorized', 'code': 'TOKEN_EXPIRED'}),
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // Success response for replayed or valid requests
    return ResponseBody.fromString(
      jsonEncode({'status': 'ok', 'data': 'mock_data'}),
      200,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}
