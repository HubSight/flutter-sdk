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
  group('HubSightArchiveService Tests', () {
    late HubSightApiClient client;
    late HubSightArchiveService archiveService;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'https://cctv.quoctran.space'));
      dio.httpClientAdapter = _MockArchiveAdapter();

      client = HubSightApiClient(
        baseUrl: 'https://cctv.quoctran.space',
        apiKey: 'test_api_key',
        storage: MockStorage(),
        customDio: dio,
      );

      archiveService = HubSightArchiveService(client: client);
    });

    test('getCalendar queries available days in month', () async {
      final cal = await archiveService.getCalendar(
        cameraId: 'cam_front_door',
        year: 2026,
        month: 9,
      );

      expect(cal.cameraId, equals('cam_front_door'));
      expect(cal.year, equals(2026));
      expect(cal.month, equals(9));
      expect(cal.availableDays.length, equals(4));
      expect(cal.availableDays, contains('2026-09-01'));
      expect(cal.availableDays, contains('2026-09-09'));
    });

    test('getTimeline queries video segments within time range', () async {
      final from = DateTime.parse('2026-09-09T00:00:00Z');
      final to = DateTime.parse('2026-09-09T23:59:59Z');

      final segments = await archiveService.getTimeline(
        cameraId: 'cam_front_door',
        from: from,
        to: to,
      );

      expect(segments.length, equals(1));
      final seg = segments[0];
      expect(seg.id, equals('rec_01J8G92'));
      expect(seg.durationSeconds, equals(300));
      expect(seg.sizeBytes, equals(15428900));
      expect(seg.thumbnailUrl,
          equals('/api/app/v1/archive/rec_01J8G92/thumbnail'));
    });

    test('getPlayStream returns direct presigned MP4 stream URL', () async {
      final play = await archiveService.getPlayStream('rec_01J8G92');

      expect(play.recordingId, equals('rec_01J8G92'));
      expect(play.format, equals('mp4'));
      expect(play.streamUrl, contains('dl.learncurv.space'));
      expect(play.durationSeconds, equals(300));
    });
  });
}

class _MockArchiveAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    if (path == Endpoints.archiveCalendar('cam_front_door')) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'camera_id': 'cam_front_door',
          'year': 2026,
          'month': 9,
          'available_days': [
            '2026-09-01',
            '2026-09-02',
            '2026-09-08',
            '2026-09-09',
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.archiveTimeline('cam_front_door')) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'camera_id': 'cam_front_door',
          'segments': [
            {
              'id': 'rec_01J8G92',
              'camera_id': 'cam_front_door',
              'start_at': '2026-09-09T08:00:00Z',
              'end_at': '2026-09-09T08:05:00Z',
              'duration_seconds': 300,
              'size_bytes': 15428900,
              'thumbnail_url': '/api/app/v1/archive/rec_01J8G92/thumbnail',
            }
          ],
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );
    }

    if (path == Endpoints.archivePlay('rec_01J8G92')) {
      return ResponseBody.fromString(
        jsonEncode({
          'status': 'ok',
          'recording_id': 'rec_01J8G92',
          'stream_url':
              'https://dl.learncurv.space/bucket-cctv/recordings/08-00-00.mp4',
          'duration_seconds': 300,
          'size_bytes': 15428900,
          'format': 'mp4',
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
