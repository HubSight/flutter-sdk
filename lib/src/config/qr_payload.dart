import 'dart:convert';

/// Representation of QR code data scanned by the app.
class HubSightQRPayload {
  final int version;
  final String configId;
  final String name;
  final String downloadUrl;
  final String sha256;

  const HubSightQRPayload({
    required this.version,
    required this.configId,
    required this.name,
    required this.downloadUrl,
    required this.sha256,
  });

  factory HubSightQRPayload.fromJson(Map<String, dynamic> json) {
    return HubSightQRPayload(
      version: json['v'] as int? ?? 1,
      configId: json['config_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      downloadUrl: json['download_url'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
    );
  }

  factory HubSightQRPayload.fromString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('QR code data must be a valid JSON object');
    }
    return HubSightQRPayload.fromJson(decoded);
  }

  Map<String, dynamic> toJson() {
    return {
      'v': version,
      'config_id': configId,
      'name': name,
      'download_url': downloadUrl,
      'sha256': sha256,
    };
  }
}
