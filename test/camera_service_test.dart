import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hubsight_sdk/hubsight_sdk.dart';

class MockStorage extends HubSightSecureStorage {
  @override
  Future<String?> getAccessToken() async => 'mock_jwt_token';
}

void main() {
  group('HubSightCameraService Tests', () {
    late HubSightApiClient client;
    late HubSightCameraService cameraService;
    late MockStorage mockStorage;

    setUp(() {
      mockStorage = MockStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://cctv.quoctran.space'));
      dio.httpClientAdapter = _MockCameraAdapter();

      client = HubSightApiClient(
        baseUrl: 'https://cctv.quoctran.space',
        apiKey: 'test_api_key',
        storage: mockStorage,
        customDio: dio,
      );

      cameraService =
          HubSightCameraService(client: client, storage: mockStorage);
    });

    test('listCameras returns correctly parsed list of Camera objects',
        () async {
      final cameras = await cameraService.listCameras();

      expect(cameras.length, equals(2));

      final cam1 = cameras[0];
      expect(cam1.id, equals('cam_front_door'));
      expect(cam1.name, equals('Cổng chính'));
      expect(cam1.isActive, isTrue);
      expect(cam1.isStopped, isFalse);
      expect(cam1.isStreaming, isTrue);
      expect(cam1.thumbnailUrl,
          equals('/api/app/v1/cameras/cam_front_door/thumbnail'));
      expect(cam1.streamName, equals('cam_cam_front_door_thumb'));

      final cam2 = cameras[1];
      expect(cam2.id, equals('cam_garage'));
      expect(cam2.name, equals('Gara xe'));
      expect(cam2.isStopped, isTrue);
      expect(cam2.isStreaming, isFalse);
    });

    test('getCamera returns details of single camera', () async {
      final camera = await cameraService.getCamera('cam_front_door');

      expect(camera.id, equals('cam_front_door'));
      expect(camera.name, equals('Cổng chính'));
      expect(camera.host, contains('192.168.1.100'));
    });

    test('buildThumbnailUrl constructs authenticated URL with query parameters',
        () async {
      final url = await cameraService.buildThumbnailUrl('cam_front_door');

      expect(
          url,
          startsWith(
              'https://cctv.quoctran.space/api/app/v1/cameras/cam_front_door/thumbnail'));
      expect(url, contains('api_key=test_api_key'));
      expect(url, contains('token=mock_jwt_token'));
      expect(url, contains('&_t='));
    });
  });
}

class _MockCameraAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (path == Endpoints.cameras) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'cameras': [
            {
              'id': 'cam_front_door',
              'name': 'Cổng chính',
              'host': 'rtsp://192.168.1.100:554/live',
              'is_active': true,
              'is_stopped': false,
              'enable_ai': true,
              'thumbnail_url': '/api/app/v1/cameras/cam_front_door/thumbnail',
              'stream_name': 'cam_cam_front_door_thumb',
            },
            {
              'id': 'cam_garage',
              'name': 'Gara xe',
              'host': 'rtsp://192.168.1.101:554/live',
              'is_active': true,
              'is_stopped': true,
              'enable_ai': false,
              'thumbnail_url': '',
              'stream_name': '',
            }
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.cameraDetail('cam_front_door')) {
      return ResponseBody.fromString(
        jsonEncode({
          'id': 'cam_front_door',
          'name': 'Cổng chính',
          'host': 'rtsp://192.168.1.100:554/live',
          'is_active': true,
          'is_stopped': false,
          'enable_ai': true,
          'thumbnail_url': '/api/app/v1/cameras/cam_front_door/thumbnail',
          'stream_name': 'cam_cam_front_door_thumb',
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
