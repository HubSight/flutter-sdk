import '../network/api_client.dart';
import '../network/endpoints.dart';
import 'models/app_notification.dart';

/// Service managing alert notifications and unread badge count queries.
class HubSightNotificationService {
  final HubSightApiClient _client;

  HubSightNotificationService({required HubSightApiClient client})
      : _client = client;

  /// High-performance query to get unread notification count for App Icon Badge.
  Future<int> getUnreadCount() async {
    final data = await _client.get(Endpoints.notificationsUnreadCount);
    return ((data as Map)['unread_count'] as num?)?.toInt() ?? 0;
  }

  /// List notifications with optional pagination and filters.
  Future<NotificationListResponse> listNotifications({
    int page = 1,
    int limit = 20,
    String? cameraId,
    String? type,
    bool? isRead,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (cameraId != null && cameraId.isNotEmpty) 'camera_id': cameraId,
      if (type != null && type.isNotEmpty) 'type': type,
      if (isRead != null) 'is_read': isRead.toString(),
    };

    final data =
        await _client.get(Endpoints.notifications, queryParameters: query);
    return NotificationListResponse.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String notificationId) async {
    await _client.patch(Endpoints.notificationRead(notificationId));
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await _client.post(Endpoints.notificationsReadAll);
  }

  /// Delete a notification record.
  Future<void> deleteNotification(String notificationId) async {
    await _client.delete(Endpoints.notificationDelete(notificationId));
  }
}
