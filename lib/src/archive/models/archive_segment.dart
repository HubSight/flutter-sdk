/// Video recording segment in archive timeline.
class ArchiveSegment {
  final String id;
  final String cameraId;
  final DateTime startAt;
  final DateTime endAt;
  final int durationSeconds;
  final int sizeBytes;
  final String? thumbnailUrl;

  const ArchiveSegment({
    required this.id,
    required this.cameraId,
    required this.startAt,
    required this.endAt,
    required this.durationSeconds,
    required this.sizeBytes,
    this.thumbnailUrl,
  });

  factory ArchiveSegment.fromJson(Map<String, dynamic> json) {
    return ArchiveSegment(
      id: json['id'] as String? ?? '',
      cameraId: json['camera_id'] as String? ?? '',
      startAt: DateTime.tryParse(json['start_at'] as String? ?? '') ?? DateTime.now(),
      endAt: DateTime.tryParse(json['end_at'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'camera_id': cameraId,
      'start_at': startAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'duration_seconds': durationSeconds,
      'size_bytes': sizeBytes,
      'thumbnail_url': thumbnailUrl,
    };
  }
}
