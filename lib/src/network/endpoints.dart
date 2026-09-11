/// HubSight Mobile App API v1 Endpoints.
class Endpoints {
  Endpoints._();

  static const String basePrefix = '/api/app/v1';

  // System
  static const String systemStatus = '$basePrefix/system/status';

  // Auth
  static const String authLogin = '$basePrefix/auth/login';
  static const String auth2faVerify = '$basePrefix/auth/2fa/verify';
  static const String authRefresh = '$basePrefix/auth/refresh';
  static const String authChangePassword = '$basePrefix/auth/change-password';
  static const String authLogout = '$basePrefix/auth/logout';

  // Profile & Sessions
  static const String profile = '$basePrefix/profile';
  static const String profileSessions = '$basePrefix/profile/sessions';
  static String profileSessionRevoke(String id) =>
      '$basePrefix/profile/sessions/$id';

  // Cameras
  static const String cameras = '$basePrefix/cameras';
  static String cameraDetail(String id) => '$basePrefix/cameras/$id';
  static String cameraThumbnail(String id) =>
      '$basePrefix/cameras/$id/thumbnail';
  static String cameraLiveWebRTC(String id) =>
      '$basePrefix/cameras/$id/live/webrtc';
  static String cameraLiveHeartbeat(String id) =>
      '$basePrefix/cameras/$id/live/heartbeat';
  static String cameraLiveRelease(String id) =>
      '$basePrefix/cameras/$id/live/release';

  // Multi-View Batching
  static const String batchLiveWebRTC = '$basePrefix/cameras/live/batch-webrtc';
  static const String batchLiveHeartbeat =
      '$basePrefix/cameras/live/batch-heartbeat';
  static const String batchLiveRelease =
      '$basePrefix/cameras/live/batch-release';

  // Archive & Playback
  static String archiveCalendar(String id) =>
      '$basePrefix/cameras/$id/archive/calendar';
  static String archiveTimeline(String id) =>
      '$basePrefix/cameras/$id/archive/timeline';
  static String archivePlay(String recordingId) =>
      '$basePrefix/archive/$recordingId/play';
  static String archiveThumbnail(String recordingId) =>
      '$basePrefix/archive/$recordingId/thumbnail';

  // Notifications
  static const String pushToken = '$basePrefix/notifications/push-token';
  static const String notificationsUnreadCount =
      '$basePrefix/notifications/unread-count';
  static const String notifications = '$basePrefix/notifications';
  static String notificationRead(String id) =>
      '$basePrefix/notifications/$id/read';
  static const String notificationsReadAll =
      '$basePrefix/notifications/read-all';
  static String notificationDelete(String id) =>
      '$basePrefix/notifications/$id';
}
