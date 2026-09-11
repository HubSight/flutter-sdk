/// Realtime event emitted when a user session is revoked from remote.
class SessionRevokedEvent {
  final String sessionId;
  final String? reason;

  const SessionRevokedEvent({
    required this.sessionId,
    this.reason,
  });

  factory SessionRevokedEvent.fromJson(Map<String, dynamic> json) {
    return SessionRevokedEvent(
      sessionId: json['session_id'] as String? ?? '',
      reason: json['reason'] as String?,
    );
  }
}

/// Realtime event emitted on AI detection alert.
class AIAlertEvent {
  final String cameraId;
  final String eventType;
  final String title;
  final String? message;
  final String? thumbnailUrl;
  final DateTime timestamp;

  const AIAlertEvent({
    required this.cameraId,
    required this.eventType,
    required this.title,
    this.message,
    this.thumbnailUrl,
    required this.timestamp,
  });

  factory AIAlertEvent.fromJson(Map<String, dynamic> json) {
    return AIAlertEvent(
      cameraId: json['camera_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'general',
      title: json['title'] as String? ?? 'Cảnh báo mới',
      message: json['message'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Realtime camera online/offline status event.
class CameraStatusEvent {
  final String cameraId;
  final bool isOnline;
  final bool isStopped;

  const CameraStatusEvent({
    required this.cameraId,
    required this.isOnline,
    required this.isStopped,
  });

  factory CameraStatusEvent.fromJson(Map<String, dynamic> json) {
    return CameraStatusEvent(
      cameraId: json['camera_id'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      isStopped: json['is_stopped'] as bool? ?? false,
    );
  }
}
