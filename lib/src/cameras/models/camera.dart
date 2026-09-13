/// HubSight Camera entity and configuration.
class Camera {
  final String id;
  final String name;
  final String host;
  final bool isActive;
  final bool isStopped;
  final bool enableAI;
  final String thumbnailUrl;
  final String streamName;

  const Camera({
    required this.id,
    required this.name,
    required this.host,
    required this.isActive,
    required this.isStopped,
    required this.enableAI,
    required this.thumbnailUrl,
    required this.streamName,
  });

  factory Camera.fromJson(Map<String, dynamic> json) {
    return Camera(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      isStopped: json['is_stopped'] as bool? ?? false,
      enableAI: json['enable_ai'] as bool? ?? false,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      streamName: json['stream_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'is_active': isActive,
      'is_stopped': isStopped,
      'enable_ai': enableAI,
      'thumbnail_url': thumbnailUrl,
      'stream_name': streamName,
    };
  }

  Camera copyWith({
    String? id,
    String? name,
    String? host,
    bool? isActive,
    bool? isStopped,
    bool? enableAI,
    String? thumbnailUrl,
    String? streamName,
  }) {
    return Camera(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      isActive: isActive ?? this.isActive,
      isStopped: isStopped ?? this.isStopped,
      enableAI: enableAI ?? this.enableAI,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      streamName: streamName ?? this.streamName,
    );
  }

  /// Whether the camera is currently streaming and can be viewed.
  bool get isStreaming => isActive && !isStopped;
}
