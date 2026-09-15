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
    late _MockCameraAdapter adapter;

    setUp(() {
      mockStorage = MockStorage();
      final dio = Dio(BaseOptions(baseUrl: 'https://cctv.quoctran.space'));
      adapter = _MockCameraAdapter();
      dio.httpClientAdapter = adapter;

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
      expect(cam1.onvifEnabled, isTrue);
      expect(cam1.onvifPtzSupported, isTrue);
      expect(cam1.thumbnailUrl,
          equals('/api/app/v1/cameras/cam_front_door/thumbnail'));
      expect(cam1.streamName, equals('cam_cam_front_door_thumb'));

      final cam2 = cameras[1];
      expect(cam2.id, equals('cam_garage'));
      expect(cam2.name, equals('Gara xe'));
      expect(cam2.isStopped, isTrue);
      expect(cam2.isStreaming, isFalse);
      expect(cam2.onvifEnabled, isFalse);
      expect(cam2.onvifPtzSupported, isFalse);
    });

    test('getCamera returns details of single camera', () async {
      final camera = await cameraService.getCamera('cam_front_door');

      expect(camera.id, equals('cam_front_door'));
      expect(camera.name, equals('Cổng chính'));
      expect(camera.host, contains('192.168.1.100'));
      expect(camera.onvifEnabled, isTrue);
      expect(camera.onvifPtzSupported, isTrue);
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

    test('continuousMove sends correct PTZ command', () async {
      await cameraService.continuousMove(
        'cam_front_door',
        pan: 0.7,
        tilt: -0.5,
        zoom: 0.2,
      );

      expect(adapter.lastPtzRequest, isNotNull);
      expect(adapter.lastPtzRequest!.data['action'], equals('continuous'));
      expect(adapter.lastPtzRequest!.data['pan'], equals(0.7));
      expect(adapter.lastPtzRequest!.data['tilt'], equals(-0.5));
      expect(adapter.lastPtzRequest!.data['zoom'], equals(0.2));
    });

    test('relativeMove sends correct relative command', () async {
      await cameraService.relativeMove('cam_front_door', pan: 0.1, tilt: 0.2);

      expect(adapter.lastPtzRequest, isNotNull);
      expect(adapter.lastPtzRequest!.data['action'], equals('relative'));
      expect(adapter.lastPtzRequest!.data['pan'], equals(0.1));
      expect(adapter.lastPtzRequest!.data['tilt'], equals(0.2));
    });

    test('stopPtz sends stop command', () async {
      await cameraService.stopPtz('cam_front_door');

      expect(adapter.lastPtzRequest, isNotNull);
      expect(adapter.lastPtzRequest!.data['action'], equals('stop'));
    });

    test('getPresets returns list of PresetItem', () async {
      final presets = await cameraService.getPresets('cam_front_door');

      expect(presets.length, equals(2));
      expect(presets[0].token, equals('preset_1'));
      expect(presets[0].name, equals('Entrance'));
      expect(presets[1].token, equals('preset_2'));
      expect(presets[1].name, equals('Parking Lot'));
    });

    test('gotoPreset sends goto command with preset token', () async {
      await cameraService.gotoPreset('cam_front_door', 'preset_1');

      expect(adapter.lastPresetRequest, isNotNull);
      expect(adapter.lastPresetRequest!.data['action'], equals('goto'));
      expect(
          adapter.lastPresetRequest!.data['preset_token'], equals('preset_1'));
    });

    test('setPreset saves new preset and returns PresetItem', () async {
      final item = await cameraService.setPreset('cam_front_door', 'Backyard');

      expect(item.name, equals('Backyard'));
      expect(item.token, equals('preset_new'));
      expect(adapter.lastPresetRequest, isNotNull);
      expect(adapter.lastPresetRequest!.data['action'], equals('set'));
      expect(
          adapter.lastPresetRequest!.data['preset_name'], equals('Backyard'));
    });

    test('removePreset sends remove command with preset token', () async {
      await cameraService.removePreset('cam_front_door', 'preset_1');

      expect(adapter.lastPresetRequest, isNotNull);
      expect(adapter.lastPresetRequest!.data['action'], equals('remove'));
      expect(
          adapter.lastPresetRequest!.data['preset_token'], equals('preset_1'));
    });

    test('probeONVIF queries ONVIF device info and profiles', () async {
      final result = await cameraService.probeONVIF(
        cameraId: 'cam_front_door',
        host: '192.168.1.100',
        port: 80,
      );

      expect(result.success, isTrue);
      expect(result.hasPtz, isTrue);
      expect(result.deviceInfo.manufacturer, equals('HubSight Corp'));
      expect(result.deviceInfo.model, equals('HS-PTZ-500'));
      expect(result.profiles.length, equals(1));
      expect(result.profiles[0].token, equals('profile_main'));
    });

    test('batchWebRTC sends batch streams and returns results', () async {
      final results = await cameraService.batchWebRTC([
        const BatchWebRTCItem(cameraId: 'cam_front_door', sdpOffer: 'v=0...'),
      ]);

      expect(results.length, equals(1));
      expect(results[0].cameraId, equals('cam_front_door'));
      expect(results[0].sdpAnswer, equals('v=0 answer...'));
      expect(results[0].poolStreamName, equals('stream_front_door'));
      expect(results[0].isSuccess, isTrue);
    });

    test('batchHeartbeat sends leases and cameraIds and returns count',
        () async {
      final res = await cameraService.batchHeartbeat(
        leases: [
          const BatchHeartbeatItem(
            cameraId: 'cam_front_door',
            streamName: 'stream_front_door',
          ),
        ],
        cameraIds: ['cam_front_door'],
      );

      expect(res.status, equals('ok'));
      expect(res.renewed, equals(1));
    });

    test('batchRelease sends leases and cameraIds and returns released count',
        () async {
      final res = await cameraService.batchRelease(
        leases: [
          const BatchHeartbeatItem(
            cameraId: 'cam_front_door',
            streamName: 'stream_front_door',
          ),
        ],
        cameraIds: ['cam_front_door'],
      );

      expect(res.status, equals('ok'));
      expect(res.released, equals(1));
    });
  });
}

class _MockCameraAdapter implements HttpClientAdapter {
  RequestOptions? lastPtzRequest;
  RequestOptions? lastPresetRequest;
  RequestOptions? lastProbeRequest;

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
              'onvif_enabled': true,
              'onvif_ptz_supported': true,
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
              'onvif_enabled': false,
              'onvif_ptz_supported': false,
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
          'onvif_enabled': true,
          'onvif_ptz_supported': true,
          'thumbnail_url': '/api/app/v1/cameras/cam_front_door/thumbnail',
          'stream_name': 'cam_cam_front_door_thumb',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.cameraPTZ('cam_front_door')) {
      lastPtzRequest = options;
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok'}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.cameraPresets('cam_front_door')) {
      lastPresetRequest = options;
      if (options.method == 'GET') {
        return ResponseBody.fromString(
          jsonEncode({
            'status': 'ok',
            'presets': [
              {'token': 'preset_1', 'name': 'Entrance'},
              {'token': 'preset_2', 'name': 'Parking Lot'},
            ],
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      } else if (options.method == 'POST') {
        final data = options.data as Map<String, dynamic>;
        if (data['action'] == 'set') {
          return ResponseBody.fromString(
            jsonEncode({
              'token': 'preset_new',
              'name': data['preset_name'] ?? 'New Preset',
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType]
            },
          );
        }
        return ResponseBody.fromString(
          jsonEncode({'status': 'ok'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          },
        );
      }
    }

    if (path == Endpoints.onvifProbe) {
      lastProbeRequest = options;
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'host': '192.168.1.100',
          'port': 80,
          'has_ptz': true,
          'device_info': {
            'manufacturer': 'HubSight Corp',
            'model': 'HS-PTZ-500',
            'firmware_version': 'v2.1.0',
            'serial_number': 'SN12345678',
            'hardware_id': 'HW-01',
          },
          'profiles': [
            {
              'token': 'profile_main',
              'name': 'Main Stream',
              'stream_uri': 'rtsp://192.168.1.100:554/profile_main',
              'ptz_supported': true,
              'width': 1920,
              'height': 1080,
            }
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.batchLiveWebRTC) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'streams': [
            {
              'camera_id': 'cam_front_door',
              'sdp_answer': 'v=0 answer...',
              'pool_stream_name': 'stream_front_door',
              'pool_conn_index': '0',
            }
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.batchLiveHeartbeat) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'renewed': 1}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.batchLiveRelease) {
      return ResponseBody.fromString(
        jsonEncode({'status': 'ok', 'released': 1}),
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
