import '../network/api_client.dart';
import '../network/endpoints.dart';
import 'models/archive_calendar.dart';
import 'models/archive_segment.dart';
import 'models/play_stream.dart';

/// Service managing NVR recording archive, calendar queries, timeline segments, and playback URLs.
class HubSightArchiveService {
  final HubSightApiClient _client;

  HubSightArchiveService({required HubSightApiClient client})
      : _client = client;

  /// Retrieve available recording days for a given camera in a specific year and month.
  Future<ArchiveCalendar> getCalendar({
    required String cameraId,
    required int year,
    required int month,
  }) async {
    final data = await _client.get(
      Endpoints.archiveCalendar(cameraId),
      queryParameters: {
        'year': year,
        'month': month,
      },
    );
    return ArchiveCalendar.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Query video segments on the timeline between [from] and [to] timestamps.
  Future<List<ArchiveSegment>> getTimeline({
    required String cameraId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = await _client.get(
      Endpoints.archiveTimeline(cameraId),
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final segmentsRaw = (data as Map)['segments'] as List? ?? [];
    return segmentsRaw
        .map(
            (e) => ArchiveSegment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Get direct presigned MP4 streaming URL for native video players.
  Future<PlayStreamResult> getPlayStream(
    String recordingId, {
    bool download = false,
  }) async {
    final data = await _client.get(
      Endpoints.archivePlay(recordingId),
      queryParameters: {
        'redirect': 'false',
        if (download) 'download': 'true',
      },
    );
    return PlayStreamResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Get presigned URL for recording segment thumbnail.
  Future<String> getThumbnailUrl(String recordingId) async {
    final data = await _client.get(
      Endpoints.archiveThumbnail(recordingId),
      queryParameters: {'redirect': 'false'},
    );
    return ((data as Map)['thumbnail_url'] ?? '') as String;
  }
}
