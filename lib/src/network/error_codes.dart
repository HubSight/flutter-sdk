/// Standardized, machine-readable error codes for the HubSight Mobile SDK.
///
/// Complies with industrial standards for high-quality SDK architecture.
/// End-user applications map these codes to their own localized strings
/// rather than displaying hardcoded SDK text directly on the UI.
enum HubSightErrorCode {
  // --- 1. Configuration & Container (.hscfg) ---
  configInvalidPinFormat('CONFIG_INVALID_PIN_FORMAT'),
  configCorrupted('CONFIG_CORRUPTED'),
  configInvalidHeader('CONFIG_INVALID_HEADER'),
  configDecryptionFailed('CONFIG_DECRYPTION_FAILED'),
  configDecompressionFailed('CONFIG_DECOMPRESSION_FAILED'),
  configMissingRequiredFiles('CONFIG_MISSING_REQUIRED_FILES'),
  configMalformedYaml('CONFIG_MALFORMED_YAML'),
  configInvalidSignature('CONFIG_INVALID_SIGNATURE'),

  // --- 2. Network & Transport ---
  networkTimeout('NETWORK_TIMEOUT'),
  networkUnreachable('NETWORK_UNREACHABLE'),
  networkConnectionRefused('NETWORK_CONNECTION_REFUSED'),
  networkCanceled('NETWORK_CANCELED'),
  networkUnknown('NETWORK_UNKNOWN'),

  // --- 3. Authentication & Session ---
  authInvalidCredentials('AUTH_INVALID_CREDENTIALS'),
  authTwoFactorRequired('AUTH_2FA_REQUIRED'),
  authInvalidTwoFactorCode('AUTH_INVALID_2FA_CODE'),
  authRefreshTokenExpired('AUTH_REFRESH_TOKEN_EXPIRED'),
  authRefreshTokenRevoked('AUTH_REFRESH_TOKEN_REVOKED'),
  authSessionRevoked('AUTH_SESSION_REVOKED'),
  authSessionExpired('AUTH_SESSION_EXPIRED'),
  authWeakPassword('AUTH_WEAK_PASSWORD'),
  authChangePasswordFailed('AUTH_CHANGE_PASSWORD_FAILED'),
  authUnauthorized('AUTH_UNAUTHORIZED'),

  // --- 4. Client Key & Access Authorization ---
  appKeyRequired('APP_KEY_REQUIRED'),
  appKeyInvalidOrRevoked('INVALID_APP_KEY'),
  accessForbidden('ACCESS_FORBIDDEN'),

  // --- 5. System & Maintenance ---
  systemMaintenance('APP_API_DISABLED'),
  systemUnavailable('SYSTEM_UNAVAILABLE'),
  systemInternalError('SYSTEM_INTERNAL_ERROR'),

  // --- 6. Surveillance Cameras ---
  cameraNotFound('CAMERA_NOT_FOUND'),
  cameraStopped('CAMERA_STOPPED'),
  cameraStreamNegotiationFailed('CAMERA_STREAM_NEGOTIATION_FAILED'),
  cameraLeaseExpired('CAMERA_LEASE_EXPIRED'),

  // --- 7. Archive & NVR Playback ---
  archiveRecordingNotFound('ARCHIVE_RECORDING_NOT_FOUND'),
  archivePlaybackUrlFailed('ARCHIVE_PLAYBACK_URL_FAILED'),
  archiveInvalidDateRange('ARCHIVE_INVALID_DATE_RANGE'),

  // --- 8. Notifications & Push ---
  notificationPushTokenFailed('NOTIFICATION_PUSH_TOKEN_FAILED'),
  notificationNotFound('NOTIFICATION_NOT_FOUND'),

  // --- 9. Unknown / General ---
  unknownError('UNKNOWN_ERROR');

  final String wireCode;
  const HubSightErrorCode(this.wireCode);

  /// Map Gateway JSON error code and HTTP status code into standardized [HubSightErrorCode].
  static HubSightErrorCode fromBackendCode(String? rawCode, int? statusCode) {
    final clean = (rawCode ?? '').trim().toUpperCase();

    switch (clean) {
      case 'APP_KEY_REQUIRED':
        return HubSightErrorCode.appKeyRequired;
      case 'INVALID_APP_KEY':
        return HubSightErrorCode.appKeyInvalidOrRevoked;
      case 'INVALID_CREDENTIALS':
        return HubSightErrorCode.authInvalidCredentials;
      case '2FA_REQUIRED':
        return HubSightErrorCode.authTwoFactorRequired;
      case 'INVALID_2FA_CODE':
        return HubSightErrorCode.authInvalidTwoFactorCode;
      case 'REFRESH_TOKEN_REQUIRED':
      case 'INVALID_REFRESH_TOKEN':
        return HubSightErrorCode.authRefreshTokenExpired;
      case 'WEAK_PASSWORD':
        return HubSightErrorCode.authWeakPassword;
      case 'CHANGE_PASSWORD_FAILED':
        return HubSightErrorCode.authChangePasswordFailed;
      case 'UNAUTHORIZED':
        return HubSightErrorCode.authUnauthorized;
      case 'APP_API_DISABLED':
        return HubSightErrorCode.systemMaintenance;
      case 'CAMERA_NOT_FOUND':
        return HubSightErrorCode.cameraNotFound;
      case 'CAMERA_STOPPED':
        return HubSightErrorCode.cameraStopped;
      case 'RECORDING_NOT_FOUND':
        return HubSightErrorCode.archiveRecordingNotFound;
      case 'NOTIFICATION_NOT_FOUND':
        return HubSightErrorCode.notificationNotFound;
    }

    // Fallback based on HTTP Status Code
    if (statusCode != null) {
      if (statusCode == 401) return HubSightErrorCode.authUnauthorized;
      if (statusCode == 403) return HubSightErrorCode.accessForbidden;
      if (statusCode == 404) return HubSightErrorCode.unknownError;
      if (statusCode == 503) return HubSightErrorCode.systemMaintenance;
      if (statusCode >= 500) return HubSightErrorCode.systemInternalError;
    }

    return HubSightErrorCode.unknownError;
  }
}

/// Interface for UI developers to resolve [HubSightErrorCode] into localized display messages.
abstract class HubSightErrorResolver {
  String resolve(HubSightErrorCode code);
}
