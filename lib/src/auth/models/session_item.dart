/// Model representing an active user login session across devices.
class SessionItem {
  final String id;
  final String clientId;
  final bool isPwa;
  final bool isCurrent;
  final DateTime expiresAt;
  final DateTime createdAt;

  const SessionItem({
    required this.id,
    required this.clientId,
    required this.isPwa,
    required this.isCurrent,
    required this.expiresAt,
    required this.createdAt,
  });

  factory SessionItem.fromJson(Map<String, dynamic> json) {
    return SessionItem(
      id: json['id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      isPwa: json['is_pwa'] as bool? ?? false,
      isCurrent: json['is_current'] as bool? ?? false,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'is_pwa': isPwa,
      'is_current': isCurrent,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
