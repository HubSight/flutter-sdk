import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

class MockStorage extends HubSightSecureStorage {
  @override
  Future<String?> getAccessToken() async => 'mock_jwt_token';
  @override
  Future<String?> getRefreshToken() async => 'mock_refresh_token';
}

void main() {
  group('HubSightNotificationService Tests', () {
    late HubSightApiClient client;
    late HubSightNotificationService notifService;
    late HubSightFCMManager fcmManager;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'https://cctv.quoctran.space'));
      dio.httpClientAdapter = _MockNotificationAdapter();

      client = HubSightApiClient(
        baseUrl: 'https://cctv.quoctran.space',
        apiKey: 'test_api_key',
        storage: MockStorage(),
        customDio: dio,
      );

      notifService = HubSightNotificationService(client: client);
      fcmManager = HubSightFCMManager(client: client);
    });

    test('getUnreadCount returns integer count for app badge', () async {
      final count = await notifService.getUnreadCount();
      expect(count, equals(4));
    });

    test('listNotifications parses items and pagination details', () async {
      final res = await notifService.listNotifications(page: 1, limit: 10);
      expect(res.unreadCount, equals(4));
      expect(res.total, equals(1));
      expect(res.items.length, equals(1));

      final item = res.items[0];
      expect(item.id, equals('notif_001'));
      expect(item.title, equals('Phát hiện người'));
      expect(item.body, contains('Khu vực cổng chính'));
      expect(item.type, equals('person_detected'));
      expect(item.isRead, isFalse);
    });

    test('markAsRead calls endpoint with notification ID', () async {
      await expectLater(notifService.markAsRead('notif_001'), completes);
    });

    test('markAllAsRead completes successfully', () async {
      await expectLater(notifService.markAllAsRead(), completes);
    });

    test('deleteNotification completes successfully', () async {
      await expectLater(
          notifService.deleteNotification('notif_001'), completes);
    });

    test('fcmManager registers and unregisters push tokens', () async {
      await expectLater(
          fcmManager.registerPushToken('fcm_token_sample_123'), completes);
      await expectLater(
          fcmManager.unregisterPushToken('fcm_token_sample_123'), completes);
    });
  });
}

class _MockNotificationAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (path == Endpoints.notificationsUnreadCount) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'unread_count': 4}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.notifications) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'unread_count': 4,
          'page': 1,
          'limit': 10,
          'total': 1,
          'items': [
            {
              'id': 'notif_001',
              'camera_id': 'cam_front_door',
              'type': 'person_detected',
              'title': 'Phát hiện người',
              'body': 'Khu vực cổng chính có người di chuyển',
              'category': 'security_alert',
              'thumbnail_url': '/api/app/v1/cameras/cam_front_door/thumbnail',
              'is_read': false,
              'created_at': '2026-09-09T10:30:00Z',
            }
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.notificationRead('notif_001') ||
        path == Endpoints.notificationsReadAll ||
        path == Endpoints.notificationDelete('notif_001') ||
        path == Endpoints.pushToken) {
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
