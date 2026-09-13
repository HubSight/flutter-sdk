/// HubSight Alert & Event Notification entity.
class AppNotification {
  final String id;
  final String cameraId;
  final String type;
  final String title;
  final String body;
  final String category;
  final String? memberId;
  final String? thumbnailUrl;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.cameraId,
    required this.type,
    required this.title,
    required this.body,
    required this.category,
    this.memberId,
    this.thumbnailUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      cameraId: json['camera_id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      category: json['category'] as String? ?? '',
      memberId: json['member_id'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'camera_id': cameraId,
      'type': type,
      'title': title,
      'body': body,
      'category': category,
      'member_id': memberId,
      'thumbnail_url': thumbnailUrl,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? cameraId,
    String? type,
    String? title,
    String? body,
    String? category,
    String? memberId,
    String? thumbnailUrl,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      cameraId: cameraId ?? this.cameraId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      memberId: memberId ?? this.memberId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Paginated notifications response.
class NotificationListResponse {
  final int unreadCount;
  final int page;
  final int limit;
  final int total;
  final List<AppNotification> items;

  const NotificationListResponse({
    required this.unreadCount,
    required this.page,
    required this.limit,
    required this.total,
    required this.items,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] as List? ?? [];
    return NotificationListResponse(
      unreadCount: json['unread_count'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      total: json['total'] as int? ?? 0,
      items: itemsRaw
          .map((e) =>
              AppNotification.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}
