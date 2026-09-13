import 'error_codes.dart';

/// Base exception for all HubSight SDK errors.
///
/// **Design Rule**: In compliance with industrial SDK standards, [developerMessage]
/// is intended solely for developer console logs, Crashlytics, and debugging.
/// UI applications MUST inspect [code] and provide their own localized text.
abstract class HubSightException implements Exception {
  final HubSightErrorCode code;
  final int? statusCode;
  final String developerMessage;
  final dynamic rawResponse;

  const HubSightException({
    required this.code,
    required this.developerMessage,
    this.statusCode,
    this.rawResponse,
  });

  String get wireCode => code.wireCode;
  String get message => developerMessage;

  @override
  String toString() =>
      '$runtimeType(code: ${code.wireCode}, status: $statusCode): $developerMessage';
}

/// Generic API error returned from HubSight backend.
class HubSightApiException extends HubSightException {
  final dynamic details;

  const HubSightApiException({
    required super.code,
    required super.developerMessage,
    super.statusCode,
    super.rawResponse,
    this.details,
  });

  factory HubSightApiException.fromJson(
      Map<String, dynamic> json, int? statusCode) {
    final rawCode = (json['code'] as String?) ?? (json['error'] as String?);
    final code = HubSightErrorCode.fromBackendCode(rawCode, statusCode);
    final devMsg = json['message_en'] as String? ??
        json['message'] as String? ??
        (json['error'] is String && json['error'] != json['code']
            ? json['error'] as String
            : code.description('en'));

    return HubSightApiException(
      code: code,
      statusCode: statusCode,
      developerMessage: devMsg,
      rawResponse: json,
      details: json['details'] ?? json['errors'],
    );
  }
}

/// Authentication and session lifecycle errors.
class HubSightAuthException extends HubSightApiException {
  const HubSightAuthException({
    required super.code,
    required super.developerMessage,
    super.statusCode,
    super.rawResponse,
    super.details,
  });
}

/// Thrown when session has completely expired and refresh token is invalid or revoked.
class HubSightSessionExpiredException extends HubSightAuthException {
  const HubSightSessionExpiredException([
    String developerMessage =
        'Session expired and refresh token could not renew access.',
  ]) : super(
          code: HubSightErrorCode.authSessionExpired,
          statusCode: 401,
          developerMessage: developerMessage,
        );
}

/// Thrown when system administrator has toggled the Kill-Switch (HTTP 503 Service Unavailable).
class HubSightMaintenanceException extends HubSightException {
  final int retryAfterSeconds;

  const HubSightMaintenanceException({
    this.retryAfterSeconds = 300,
    super.developerMessage =
        'App API access is temporarily paused for maintenance.',
    super.rawResponse,
  }) : super(
          code: HubSightErrorCode.systemMaintenance,
          statusCode: 503,
        );

  factory HubSightMaintenanceException.fromJson(
      Map<String, dynamic> json, int retryAfter) {
    return HubSightMaintenanceException(
      retryAfterSeconds: retryAfter,
      developerMessage: json['message_en'] as String? ??
          json['message'] as String? ??
          'System under maintenance',
      rawResponse: json,
    );
  }
}

/// Configuration container (.hscfg) decryption or formatting failure.
class HubSightConfigException extends HubSightException {
  const HubSightConfigException({
    required super.code,
    required super.developerMessage,
    super.rawResponse,
  });
}

/// Network transport failure (connection timeout, DNS failure, host unreachable).
class HubSightNetworkException extends HubSightException {
  const HubSightNetworkException({
    required super.code,
    required super.developerMessage,
    super.statusCode,
  });
}

/// Camera surveillance streaming or status error.
class HubSightCameraException extends HubSightApiException {
  const HubSightCameraException({
    required super.code,
    required super.developerMessage,
    super.statusCode,
    super.rawResponse,
    super.details,
  });
}

/// Archive recording, timeline, or NVR playback error.
class HubSightArchiveException extends HubSightApiException {
  const HubSightArchiveException({
    required super.code,
    required super.developerMessage,
    super.statusCode,
    super.rawResponse,
    super.details,
  });
}

/// Notification and push token error.
class HubSightNotificationException extends HubSightApiException {
  const HubSightNotificationException({
    required super.code,
    required super.developerMessage,
    super.statusCode,
    super.rawResponse,
    super.details,
  });
}

// Backward-compatible type aliases
typedef ApiException = HubSightApiException;
typedef AuthException = HubSightAuthException;
typedef MaintenanceException = HubSightMaintenanceException;
typedef SessionExpiredException = HubSightSessionExpiredException;
typedef NetworkException = HubSightNetworkException;
