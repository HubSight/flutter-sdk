/// Playback stream details for an archived MP4 recording.
class PlayStreamResult {
  final String recordingId;
  final String? cameraId;
  final String streamUrl;
  final int? durationSeconds;
  final int? sizeBytes;
  final String format;
  final DateTime? expiresAt;

  const PlayStreamResult({
    required this.recordingId,
    this.cameraId,
    required this.streamUrl,
    this.durationSeconds,
    this.sizeBytes,
    this.format = 'mp4',
    this.expiresAt,
  });

  factory PlayStreamResult.fromJson(Map<String, dynamic> json) {
    return PlayStreamResult(
      recordingId: (json['recording_id'] ?? '') as String,
      cameraId: json['camera_id'] as String?,
      streamUrl: (json['stream_url'] ?? json['play_url'] ?? '') as String,
      durationSeconds: json['duration_seconds'] as int?,
      sizeBytes: (json['size_bytes'] as num?)?.toInt(),
      format: json['format'] as String? ?? 'mp4',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recording_id': recordingId,
      'camera_id': cameraId,
      'stream_url': streamUrl,
      'duration_seconds': durationSeconds,
      'size_bytes': sizeBytes,
      'format': format,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }
}
