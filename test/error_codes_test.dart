import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

void main() {
  group('HubSightErrorCode and Resolver Tests', () {
    test('maps new standardized machine error codes accurately', () {
      expect(
        HubSightErrorCode.fromBackendCode('TWO_FACTOR_INVALID', 401),
        equals(HubSightErrorCode.authInvalidTwoFactorCode),
      );
      expect(
        HubSightErrorCode.fromBackendCode('TWO_FACTOR_REQUIRED', 200),
        equals(HubSightErrorCode.authTwoFactorRequired),
      );
      expect(
        HubSightErrorCode.fromBackendCode('TWO_FACTOR_EXPIRED', 401),
        equals(HubSightErrorCode.authTwoFactorExpired),
      );
      expect(
        HubSightErrorCode.fromBackendCode('DEVICE_NOT_FOUND', 404),
        equals(HubSightErrorCode.cameraNotFound),
      );
      expect(
        HubSightErrorCode.fromBackendCode('DEVICE_STOPPED', 200),
        equals(HubSightErrorCode.cameraStopped),
      );
      expect(
        HubSightErrorCode.fromBackendCode('INCORRECT_PASSWORD', 400),
        equals(HubSightErrorCode.authIncorrectPassword),
      );
      expect(
        HubSightErrorCode.fromBackendCode('APP_API_DISABLED', 503),
        equals(HubSightErrorCode.systemMaintenance),
      );
      expect(
        HubSightErrorCode.fromBackendCode('STREAM_NOT_FOUND', 404),
        equals(HubSightErrorCode.streamNotFound),
      );
      expect(
        HubSightErrorCode.fromBackendCode('POOL_UNAVAILABLE', 503),
        equals(HubSightErrorCode.poolUnavailable),
      );
      expect(
        HubSightErrorCode.fromBackendCode('DATABASE_ERROR', 500),
        equals(HubSightErrorCode.databaseError),
      );
      expect(
        HubSightErrorCode.fromBackendCode('STORAGE_ERROR', 500),
        equals(HubSightErrorCode.storageError),
      );
      expect(
        HubSightErrorCode.fromBackendCode('INVALID_PIN_LENGTH', 400),
        equals(HubSightErrorCode.configInvalidPinLength),
      );
      expect(
        HubSightErrorCode.fromBackendCode('CONFIG_NOT_FOUND', 404),
        equals(HubSightErrorCode.configNotFound),
      );
    });

    test('HTTP status fallback works when code is missing or unrecognized', () {
      expect(
        HubSightErrorCode.fromBackendCode(null, 400),
        equals(HubSightErrorCode.invalidInput),
      );
      expect(
        HubSightErrorCode.fromBackendCode('', 401),
        equals(HubSightErrorCode.authUnauthorized),
      );
      expect(
        HubSightErrorCode.fromBackendCode(null, 403),
        equals(HubSightErrorCode.accessForbidden),
      );
      expect(
        HubSightErrorCode.fromBackendCode(null, 404),
        equals(HubSightErrorCode.notFound),
      );
      expect(
        HubSightErrorCode.fromBackendCode(null, 409),
        equals(HubSightErrorCode.conflict),
      );
      expect(
        HubSightErrorCode.fromBackendCode(null, 429),
        equals(HubSightErrorCode.tooManyRequests),
      );
      expect(
        HubSightErrorCode.fromBackendCode(null, 503),
        equals(HubSightErrorCode.systemMaintenance),
      );
      expect(
        HubSightErrorCode.fromBackendCode(null, 500),
        equals(HubSightErrorCode.systemInternalError),
      );
    });

    test(
        'dual-locale error resolver provides clear English and Vietnamese descriptions',
        () {
      const enResolver = HubSightDefaultErrorResolver(locale: 'en');
      const viResolver = HubSightDefaultErrorResolver(locale: 'vi');

      // Invalid Credentials
      expect(
        enResolver.resolve(HubSightErrorCode.authInvalidCredentials),
        equals('Invalid username or password.'),
      );
      expect(
        viResolver.resolve(HubSightErrorCode.authInvalidCredentials),
        equals('Tên đăng nhập hoặc mật khẩu không chính xác.'),
      );

      // System Maintenance
      expect(
        HubSightErrorCode.systemMaintenance.description('en'),
        contains('maintenance'),
      );
      expect(
        HubSightErrorCode.systemMaintenance.description('vi'),
        contains('bảo trì'),
      );

      // Camera Not Found
      expect(
        HubSightErrorCode.cameraNotFound.description('en'),
        equals('Camera device not found.'),
      );
      expect(
        HubSightErrorCode.cameraNotFound.description('vi'),
        equals('Không tìm thấy thiết bị camera trong hệ thống.'),
      );
    });

    test('HubSightApiException parses machine response format and details', () {
      final json = {
        'status': 'error',
        'code': 'INVALID_INPUT',
        'error': 'INVALID_INPUT',
        'details': {
          'field': 'new_password',
          'rule': 'min_length_8',
        },
      };

      final ex = HubSightApiException.fromJson(json, 400);
      expect(ex.code, equals(HubSightErrorCode.invalidInput));
      expect(ex.statusCode, equals(400));
      expect(ex.details, isA<Map>());
      expect((ex.details as Map)['field'], equals('new_password'));
    });
  });
}
