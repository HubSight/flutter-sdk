/// Standardized, machine-readable error codes for the HubSight Mobile SDK.
///
/// Complies with industrial standards for high-quality SDK architecture.
/// End-user applications map these codes to their own localized strings
/// or use [HubSightDefaultErrorResolver] for pre-built English/Vietnamese messages.
enum HubSightErrorCode {
  // --- 1. Configuration & Container (.hscfg) ---
  configInvalidPinFormat('CONFIG_INVALID_PIN_FORMAT'),
  configInvalidPinLength('CONFIG_INVALID_PIN_LENGTH'),
  configCorrupted('CONFIG_CORRUPTED'),
  configInvalidHeader('CONFIG_INVALID_HEADER'),
  configDecryptionFailed('CONFIG_DECRYPTION_FAILED'),
  configDecompressionFailed('CONFIG_DECOMPRESSION_FAILED'),
  configMissingRequiredFiles('CONFIG_MISSING_REQUIRED_FILES'),
  configMalformedYaml('CONFIG_MALFORMED_YAML'),
  configInvalidSignature('CONFIG_INVALID_SIGNATURE'),
  configNotFound('CONFIG_NOT_FOUND'),
  configPackFailed('CONFIG_PACK_FAILED'),
  firebaseInspectFailed('FIREBASE_INSPECT_FAILED'),

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
  authTwoFactorExpired('AUTH_2FA_EXPIRED'),
  authRefreshTokenExpired('AUTH_REFRESH_TOKEN_EXPIRED'),
  authRefreshTokenRevoked('AUTH_REFRESH_TOKEN_REVOKED'),
  authRefreshTokenRequired('AUTH_REFRESH_TOKEN_REQUIRED'),
  authSessionRevoked('AUTH_SESSION_REVOKED'),
  authSessionExpired('AUTH_SESSION_EXPIRED'),
  authSessionNotFound('AUTH_SESSION_NOT_FOUND'),
  authCannotRevokeCurrent('AUTH_CANNOT_REVOKE_CURRENT_SESSION'),
  authWeakPassword('AUTH_WEAK_PASSWORD'),
  authIncorrectPassword('AUTH_INCORRECT_PASSWORD'),
  authPasswordRequired('AUTH_PASSWORD_REQUIRED'),
  authChangePasswordFailed('AUTH_CHANGE_PASSWORD_FAILED'),
  authMustChangePassword('AUTH_MUST_CHANGE_PASSWORD'),
  authPasskeyFailed('AUTH_PASSKEY_FAILED'),
  authUnauthorized('AUTH_UNAUTHORIZED'),

  // --- 4. Client Key & Access Authorization ---
  appKeyRequired('APP_KEY_REQUIRED'),
  appKeyInvalidOrRevoked('INVALID_APP_KEY'),
  accessForbidden('ACCESS_FORBIDDEN'),

  // --- 5. System, Storage & Maintenance ---
  systemMaintenance('APP_API_DISABLED'),
  systemUnavailable('SYSTEM_UNAVAILABLE'),
  systemInternalError('SYSTEM_INTERNAL_ERROR'),
  databaseError('DATABASE_ERROR'),
  storageError('STORAGE_ERROR'),
  storageUnavailable('STORAGE_UNAVAILABLE'),

  // --- 6. Surveillance Cameras & Devices ---
  cameraNotFound('CAMERA_NOT_FOUND'),
  cameraStopped('CAMERA_STOPPED'),
  cameraStreamNegotiationFailed('CAMERA_STREAM_NEGOTIATION_FAILED'),
  cameraLeaseExpired('CAMERA_LEASE_EXPIRED'),
  streamNotFound('STREAM_NOT_FOUND'),
  poolUnavailable('POOL_UNAVAILABLE'),
  onvifProbeFailed('ONVIF_PROBE_FAILED'),
  onvifNotEnabled('ONVIF_NOT_ENABLED'),
  onvifPtzNotSupported('ONVIF_PTZ_NOT_SUPPORTED'),
  onvifActionFailed('ONVIF_ACTION_FAILED'),

  // --- 7. Archive & NVR Playback ---
  archiveRecordingNotFound('ARCHIVE_RECORDING_NOT_FOUND'),
  archivePlaybackUrlFailed('ARCHIVE_PLAYBACK_URL_FAILED'),
  archiveInvalidDateRange('ARCHIVE_INVALID_DATE_RANGE'),

  // --- 8. Notifications & Push ---
  notificationPushTokenFailed('NOTIFICATION_PUSH_TOKEN_FAILED'),
  notificationNotFound('NOTIFICATION_NOT_FOUND'),
  pushTokenRequired('PUSH_TOKEN_REQUIRED'),

  // --- 9. Generic Input & Resource ---
  invalidInput('INVALID_INPUT'),
  notFound('NOT_FOUND'),
  conflict('CONFLICT'),
  tooManyRequests('TOO_MANY_REQUESTS'),

  // --- 10. Unknown / General ---
  unknownError('UNKNOWN_ERROR');

  final String wireCode;
  const HubSightErrorCode(this.wireCode);

  /// Map Gateway JSON error code and HTTP status code into standardized [HubSightErrorCode].
  static HubSightErrorCode fromBackendCode(String? rawCode, int? statusCode) {
    final clean = (rawCode ?? '').trim().toUpperCase();

    switch (clean) {
      // App Key & Client Key
      case 'APP_KEY_REQUIRED':
      case 'CLIENT_KEY_REQUIRED':
        return HubSightErrorCode.appKeyRequired;
      case 'INVALID_APP_KEY':
      case 'INVALID_CLIENT_KEY':
        return HubSightErrorCode.appKeyInvalidOrRevoked;

      // Auth & Credentials
      case 'INVALID_CREDENTIALS':
      case 'AUTH_INVALID_CREDENTIALS':
        return HubSightErrorCode.authInvalidCredentials;
      case '2FA_REQUIRED':
      case 'TWO_FACTOR_REQUIRED':
      case 'AUTH_2FA_REQUIRED':
        return HubSightErrorCode.authTwoFactorRequired;
      case 'INVALID_2FA_CODE':
      case 'TWO_FACTOR_INVALID':
      case 'AUTH_INVALID_2FA_CODE':
        return HubSightErrorCode.authInvalidTwoFactorCode;
      case 'TWO_FACTOR_EXPIRED':
      case 'AUTH_2FA_EXPIRED':
        return HubSightErrorCode.authTwoFactorExpired;
      case 'REFRESH_TOKEN_REQUIRED':
      case 'AUTH_REFRESH_TOKEN_REQUIRED':
        return HubSightErrorCode.authRefreshTokenRequired;
      case 'INVALID_REFRESH_TOKEN':
      case 'AUTH_REFRESH_TOKEN_EXPIRED':
        return HubSightErrorCode.authRefreshTokenExpired;
      case 'WEAK_PASSWORD':
      case 'AUTH_WEAK_PASSWORD':
        return HubSightErrorCode.authWeakPassword;
      case 'INCORRECT_PASSWORD':
      case 'AUTH_INCORRECT_PASSWORD':
        return HubSightErrorCode.authIncorrectPassword;
      case 'PASSWORD_REQUIRED':
      case 'AUTH_PASSWORD_REQUIRED':
        return HubSightErrorCode.authPasswordRequired;
      case 'CHANGE_PASSWORD_FAILED':
      case 'AUTH_CHANGE_PASSWORD_FAILED':
        return HubSightErrorCode.authChangePasswordFailed;
      case 'MUST_CHANGE_PASSWORD':
      case 'AUTH_MUST_CHANGE_PASSWORD':
        return HubSightErrorCode.authMustChangePassword;
      case 'PASSKEY_VERIFICATION_FAILED':
      case 'AUTH_PASSKEY_FAILED':
        return HubSightErrorCode.authPasskeyFailed;
      case 'UNAUTHORIZED':
      case 'AUTH_REQUIRED':
      case 'INVALID_TOKEN':
      case 'AUTH_UNAUTHORIZED':
        return HubSightErrorCode.authUnauthorized;
      case 'FORBIDDEN':
      case 'ACCESS_FORBIDDEN':
        return HubSightErrorCode.accessForbidden;

      // Sessions
      case 'SESSION_NOT_FOUND':
      case 'AUTH_SESSION_NOT_FOUND':
        return HubSightErrorCode.authSessionNotFound;
      case 'CANNOT_REVOKE_CURRENT_SESSION':
      case 'AUTH_CANNOT_REVOKE_CURRENT_SESSION':
        return HubSightErrorCode.authCannotRevokeCurrent;

      // Maintenance & System
      case 'APP_API_DISABLED':
        return HubSightErrorCode.systemMaintenance;
      case 'SERVICE_UNAVAILABLE':
        return HubSightErrorCode.systemUnavailable;
      case 'INTERNAL_SERVER_ERROR':
      case 'INTERNAL_ERROR':
      case 'SYSTEM_INTERNAL_ERROR':
        return HubSightErrorCode.systemInternalError;
      case 'DATABASE_ERROR':
        return HubSightErrorCode.databaseError;
      case 'STORAGE_ERROR':
        return HubSightErrorCode.storageError;
      case 'STORAGE_UNAVAILABLE':
        return HubSightErrorCode.storageUnavailable;

      // Devices & Cameras
      case 'CAMERA_NOT_FOUND':
      case 'DEVICE_NOT_FOUND':
        return HubSightErrorCode.cameraNotFound;
      case 'CAMERA_STOPPED':
      case 'DEVICE_STOPPED':
        return HubSightErrorCode.cameraStopped;
      case 'STREAM_NOT_FOUND':
        return HubSightErrorCode.streamNotFound;
      case 'POOL_UNAVAILABLE':
        return HubSightErrorCode.poolUnavailable;
      case 'ONVIF_PROBE_FAILED':
        return HubSightErrorCode.onvifProbeFailed;
      case 'ONVIF_NOT_ENABLED':
        return HubSightErrorCode.onvifNotEnabled;
      case 'ONVIF_PTZ_NOT_SUPPORTED':
        return HubSightErrorCode.onvifPtzNotSupported;
      case 'ONVIF_ACTION_FAILED':
        return HubSightErrorCode.onvifActionFailed;

      // Archive & Recording
      case 'RECORDING_NOT_FOUND':
      case 'ARCHIVE_RECORDING_NOT_FOUND':
        return HubSightErrorCode.archiveRecordingNotFound;

      // Notifications
      case 'NOTIFICATION_NOT_FOUND':
        return HubSightErrorCode.notificationNotFound;
      case 'PUSH_TOKEN_REQUIRED':
        return HubSightErrorCode.pushTokenRequired;

      // Config & PIN
      case 'CONFIG_NOT_FOUND':
        return HubSightErrorCode.configNotFound;
      case 'CONFIG_PACK_FAILED':
        return HubSightErrorCode.configPackFailed;
      case 'INVALID_PIN_LENGTH':
      case 'CONFIG_INVALID_PIN_LENGTH':
        return HubSightErrorCode.configInvalidPinLength;
      case 'INVALID_PIN_FORMAT':
      case 'CONFIG_INVALID_PIN_FORMAT':
        return HubSightErrorCode.configInvalidPinFormat;
      case 'FIREBASE_INSPECT_FAILED':
        return HubSightErrorCode.firebaseInspectFailed;

      // Generic
      case 'INVALID_INPUT':
        return HubSightErrorCode.invalidInput;
      case 'NOT_FOUND':
      case 'ROUTE_NOT_FOUND':
      case 'ASSET_NOT_FOUND':
        return HubSightErrorCode.notFound;
      case 'CONFLICT':
        return HubSightErrorCode.conflict;
      case 'TOO_MANY_REQUESTS':
        return HubSightErrorCode.tooManyRequests;
    }

    // Fallback based on HTTP Status Code
    if (statusCode != null) {
      if (statusCode == 400) return HubSightErrorCode.invalidInput;
      if (statusCode == 401) return HubSightErrorCode.authUnauthorized;
      if (statusCode == 403) return HubSightErrorCode.accessForbidden;
      if (statusCode == 404) return HubSightErrorCode.notFound;
      if (statusCode == 409) return HubSightErrorCode.conflict;
      if (statusCode == 429) return HubSightErrorCode.tooManyRequests;
      if (statusCode == 503) return HubSightErrorCode.systemMaintenance;
      if (statusCode >= 500) return HubSightErrorCode.systemInternalError;
    }

    return HubSightErrorCode.unknownError;
  }

  /// Get default localized human-readable error description.
  /// Pass `locale: 'vi'` for Vietnamese, or default `'en'` for English.
  String description([String locale = 'en']) {
    return HubSightDefaultErrorResolver(locale: locale).resolve(this);
  }
}

/// Interface for UI applications to resolve [HubSightErrorCode] into localized display messages.
abstract class HubSightErrorResolver {
  String resolve(HubSightErrorCode code);
}

/// Built-in error message resolver for HubSight SDK supporting English ('en') and Vietnamese ('vi').
class HubSightDefaultErrorResolver implements HubSightErrorResolver {
  final String locale;

  const HubSightDefaultErrorResolver({this.locale = 'en'});

  @override
  String resolve(HubSightErrorCode code) {
    final isVi = locale.toLowerCase().startsWith('vi');
    if (isVi) {
      return _viMessages[code] ??
          'Đã xảy ra lỗi không xác định (${code.wireCode}).';
    }
    return _enMessages[code] ??
        'An unexpected error occurred (${code.wireCode}).';
  }

  static const Map<HubSightErrorCode, String> _enMessages = {
    // Config
    HubSightErrorCode.configInvalidPinFormat:
        'Security PIN must contain digits only.',
    HubSightErrorCode.configInvalidPinLength:
        'Security PIN must be exactly 6 digits.',
    HubSightErrorCode.configCorrupted:
        'Configuration container is corrupted or invalid.',
    HubSightErrorCode.configInvalidHeader:
        'Configuration container header is invalid.',
    HubSightErrorCode.configDecryptionFailed:
        'Failed to decrypt configuration container. Please verify your PIN.',
    HubSightErrorCode.configDecompressionFailed:
        'Failed to decompress configuration archive.',
    HubSightErrorCode.configMissingRequiredFiles:
        'Configuration package is missing required profile files.',
    HubSightErrorCode.configMalformedYaml:
        'Configuration YAML file is malformed.',
    HubSightErrorCode.configInvalidSignature:
        'Configuration security signature validation failed.',
    HubSightErrorCode.configNotFound: 'App configuration file not found.',
    HubSightErrorCode.configPackFailed:
        'Failed to package and encrypt configuration file.',
    HubSightErrorCode.firebaseInspectFailed:
        'Failed to inspect Firebase project configuration.',

    // Network
    HubSightErrorCode.networkTimeout: 'Network connection timed out.',
    HubSightErrorCode.networkUnreachable:
        'Unable to reach server. Please check your internet connection.',
    HubSightErrorCode.networkConnectionRefused: 'Connection refused by server.',
    HubSightErrorCode.networkCanceled: 'Network request was canceled.',
    HubSightErrorCode.networkUnknown: 'Network transport failure.',

    // Auth
    HubSightErrorCode.authInvalidCredentials: 'Invalid username or password.',
    HubSightErrorCode.authTwoFactorRequired:
        'Two-factor authentication (2FA) is required.',
    HubSightErrorCode.authInvalidTwoFactorCode:
        'Invalid two-factor authentication code.',
    HubSightErrorCode.authTwoFactorExpired:
        'Two-factor authentication code has expired.',
    HubSightErrorCode.authRefreshTokenExpired:
        'Session refresh token has expired or is invalid. Please log in again.',
    HubSightErrorCode.authRefreshTokenRevoked:
        'Session refresh token was revoked.',
    HubSightErrorCode.authRefreshTokenRequired: 'Refresh token is required.',
    HubSightErrorCode.authSessionRevoked: 'Your login session was terminated.',
    HubSightErrorCode.authSessionExpired:
        'Your login session has expired. Please log in again.',
    HubSightErrorCode.authSessionNotFound:
        'Session not found or already terminated.',
    HubSightErrorCode.authCannotRevokeCurrent:
        'Cannot revoke your current active session.',
    HubSightErrorCode.authWeakPassword:
        'New password does not meet security requirements (minimum 8 characters).',
    HubSightErrorCode.authIncorrectPassword: 'Incorrect current password.',
    HubSightErrorCode.authPasswordRequired: 'Password is required.',
    HubSightErrorCode.authChangePasswordFailed:
        'Failed to update account password.',
    HubSightErrorCode.authMustChangePassword:
        'You must change your password before continuing.',
    HubSightErrorCode.authPasskeyFailed:
        'Biometric / Passkey verification failed.',
    HubSightErrorCode.authUnauthorized:
        'Authentication is required to access this resource.',
    HubSightErrorCode.accessForbidden:
        'You do not have permission to perform this action.',

    // Keys
    HubSightErrorCode.appKeyRequired: 'App API Key is required.',
    HubSightErrorCode.appKeyInvalidOrRevoked:
        'App API Key is invalid or has been revoked.',

    // System
    HubSightErrorCode.systemMaintenance:
        'App connection is temporarily paused for system maintenance.',
    HubSightErrorCode.systemUnavailable: 'Service temporarily unavailable.',
    HubSightErrorCode.systemInternalError:
        'An internal server error occurred. Please try again later.',
    HubSightErrorCode.databaseError: 'Database connection or query error.',
    HubSightErrorCode.storageError: 'Storage operation failed.',
    HubSightErrorCode.storageUnavailable:
        'Storage service is temporarily unavailable.',

    // Cameras
    HubSightErrorCode.cameraNotFound: 'Camera device not found.',
    HubSightErrorCode.cameraStopped: 'Camera device is currently stopped.',
    HubSightErrorCode.cameraStreamNegotiationFailed:
        'Failed to negotiate WebRTC video stream.',
    HubSightErrorCode.cameraLeaseExpired:
        'Camera live stream lease has expired.',
    HubSightErrorCode.streamNotFound: 'Camera live stream not found.',
    HubSightErrorCode.poolUnavailable:
        'Connection pool service is unavailable.',
    HubSightErrorCode.onvifProbeFailed:
        'Failed to connect to ONVIF service on this device.',
    HubSightErrorCode.onvifNotEnabled:
        'ONVIF service is not enabled for this camera.',
    HubSightErrorCode.onvifPtzNotSupported:
        'Camera device does not support PTZ controls.',
    HubSightErrorCode.onvifActionFailed:
        'Failed to execute ONVIF PTZ movement.',

    // Archive
    HubSightErrorCode.archiveRecordingNotFound: 'Video recording not found.',
    HubSightErrorCode.archivePlaybackUrlFailed:
        'Failed to generate video streaming URL.',
    HubSightErrorCode.archiveInvalidDateRange:
        'Invalid archive date range specified.',

    // Notifications
    HubSightErrorCode.notificationPushTokenFailed:
        'Failed to register push notification token.',
    HubSightErrorCode.notificationNotFound: 'Notification not found.',
    HubSightErrorCode.pushTokenRequired: 'Push notification token is required.',

    // Generic
    HubSightErrorCode.invalidInput: 'Invalid request data.',
    HubSightErrorCode.notFound: 'Requested resource was not found.',
    HubSightErrorCode.conflict: 'Resource conflict or duplicate entry.',
    HubSightErrorCode.tooManyRequests:
        'Too many requests. Please try again in a moment.',
    HubSightErrorCode.unknownError: 'An unexpected error occurred.',
  };

  static const Map<HubSightErrorCode, String> _viMessages = {
    // Config
    HubSightErrorCode.configInvalidPinFormat:
        'Mã PIN bảo mật chỉ được chứa các ký số từ 0 đến 9.',
    HubSightErrorCode.configInvalidPinLength:
        'Mã PIN bảo mật phải có đúng 6 chữ số.',
    HubSightErrorCode.configCorrupted:
        'Tệp cấu hình bị hỏng hoặc không hợp lệ.',
    HubSightErrorCode.configInvalidHeader:
        'Định dạng header tệp cấu hình không hợp lệ.',
    HubSightErrorCode.configDecryptionFailed:
        'Giải mã tệp cấu hình thất bại. Vui lòng kiểm tra lại mã PIN.',
    HubSightErrorCode.configDecompressionFailed:
        'Giải nén gói dữ liệu cấu hình thất bại.',
    HubSightErrorCode.configMissingRequiredFiles:
        'Gói cấu hình thiếu các tệp hồ sơ bắt buộc.',
    HubSightErrorCode.configMalformedYaml:
        'Tệp YAML cấu hình bị sai định dạng cú pháp.',
    HubSightErrorCode.configInvalidSignature:
        'Chữ ký bảo mật của tệp cấu hình không hợp lệ.',
    HubSightErrorCode.configNotFound: 'Không tìm thấy cấu hình ứng dụng.',
    HubSightErrorCode.configPackFailed:
        'Không thể đóng gói và mã hóa file cấu hình ứng dụng.',
    HubSightErrorCode.firebaseInspectFailed:
        'Không thể kiểm tra thông tin dự án Firebase.',

    // Network
    HubSightErrorCode.networkTimeout:
        'Kết nối mạng quá thời gian chờ (timeout).',
    HubSightErrorCode.networkUnreachable:
        'Không thể kết nối đến máy chủ. Vui lòng kiểm tra đường truyền.',
    HubSightErrorCode.networkConnectionRefused: 'Máy chủ từ chối kết nối.',
    HubSightErrorCode.networkCanceled: 'Yêu cầu mạng đã bị hủy.',
    HubSightErrorCode.networkUnknown: 'Lỗi truyền tải mạng.',

    // Auth
    HubSightErrorCode.authInvalidCredentials:
        'Tên đăng nhập hoặc mật khẩu không chính xác.',
    HubSightErrorCode.authTwoFactorRequired:
        'Tài khoản yêu cầu xác thực hai yếu tố (2FA).',
    HubSightErrorCode.authInvalidTwoFactorCode:
        'Mã xác thực 2FA không chính xác.',
    HubSightErrorCode.authTwoFactorExpired: 'Mã xác thực 2FA đã hết hạn.',
    HubSightErrorCode.authRefreshTokenExpired:
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    HubSightErrorCode.authRefreshTokenRevoked:
        'Mã làm mới phiên đã bị thu hồi.',
    HubSightErrorCode.authRefreshTokenRequired:
        'Thiếu mã làm mới phiên đăng nhập.',
    HubSightErrorCode.authSessionRevoked:
        'Phiên đăng nhập của bạn đã bị thu hồi.',
    HubSightErrorCode.authSessionExpired:
        'Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại.',
    HubSightErrorCode.authSessionNotFound:
        'Phiên làm việc không tồn tại hoặc đã kết thúc.',
    HubSightErrorCode.authCannotRevokeCurrent:
        'Không thể thu hồi phiên đăng nhập hiện tại bạn đang sử dụng.',
    HubSightErrorCode.authWeakPassword:
        'Mật khẩu mới không đáp ứng yêu cầu (tối thiểu 8 ký tự).',
    HubSightErrorCode.authIncorrectPassword:
        'Mật khẩu hiện tại không chính xác.',
    HubSightErrorCode.authPasswordRequired: 'Vui lòng nhập mật khẩu.',
    HubSightErrorCode.authChangePasswordFailed:
        'Đổi mật khẩu tài khoản thất bại.',
    HubSightErrorCode.authMustChangePassword:
        'Bạn phải đổi mật khẩu trước khi tiếp tục sử dụng hệ thống.',
    HubSightErrorCode.authPasskeyFailed:
        'Xác thực sinh trắc học / Passkey thất bại.',
    HubSightErrorCode.authUnauthorized:
        'Yêu cầu đăng nhập để truy cập tài nguyên này.',
    HubSightErrorCode.accessForbidden:
        'Bạn không có quyền thực hiện thao tác này.',

    // Keys
    HubSightErrorCode.appKeyRequired: 'Thiếu mã App API Key.',
    HubSightErrorCode.appKeyInvalidOrRevoked:
        'Mã App API Key không hợp lệ hoặc đã bị khóa.',

    // System
    HubSightErrorCode.systemMaintenance:
        'Hệ thống đang tạm bảo trì kết nối ứng dụng.',
    HubSightErrorCode.systemUnavailable: 'Dịch vụ tạm thời không khả dụng.',
    HubSightErrorCode.systemInternalError:
        'Đã xảy ra lỗi hệ thống nội bộ. Vui lòng thử lại sau.',
    HubSightErrorCode.databaseError: 'Lỗi kết nối hoặc truy vấn cơ sở dữ liệu.',
    HubSightErrorCode.storageError:
        'Lỗi trong quá trình đọc hoặc ghi dữ liệu lưu trữ.',
    HubSightErrorCode.storageUnavailable:
        'Hệ thống lưu trữ MinIO/S3 hiện chưa sẵn sàng.',

    // Cameras
    HubSightErrorCode.cameraNotFound:
        'Không tìm thấy thiết bị camera trong hệ thống.',
    HubSightErrorCode.cameraStopped:
        'Thiết bị camera hiện đang tạm dừng hoạt động.',
    HubSightErrorCode.cameraStreamNegotiationFailed:
        'Thương lượng luồng video WebRTC thất bại.',
    HubSightErrorCode.cameraLeaseExpired:
        'Thời hạn thuê luồng phát video đã hết hạn.',
    HubSightErrorCode.streamNotFound:
        'Không tìm thấy luồng phát trực tiếp của camera.',
    HubSightErrorCode.poolUnavailable:
        'Dịch vụ điều phối kết nối luồng không phản hồi.',
    HubSightErrorCode.onvifProbeFailed:
        'Không thể kết nối ONVIF với thiết bị này.',
    HubSightErrorCode.onvifNotEnabled:
        'Chưa kích hoạt giao thức ONVIF cho camera này.',
    HubSightErrorCode.onvifPtzNotSupported:
        'Thiết bị camera này không hỗ trợ quay quét PTZ.',
    HubSightErrorCode.onvifActionFailed:
        'Thực thi lệnh điều khiển PTZ thất bại.',

    // Archive
    HubSightErrorCode.archiveRecordingNotFound:
        'Không tìm thấy bản ghi video yêu cầu.',
    HubSightErrorCode.archivePlaybackUrlFailed:
        'Không thể sinh đường dẫn phát video.',
    HubSightErrorCode.archiveInvalidDateRange:
        'Khoảng thời gian tra cứu bản ghi không hợp lệ.',

    // Notifications
    HubSightErrorCode.notificationPushTokenFailed:
        'Đăng ký nhận thông báo đẩy thất bại.',
    HubSightErrorCode.notificationNotFound: 'Không tìm thấy thông báo yêu cầu.',
    HubSightErrorCode.pushTokenRequired: 'Thiếu mã đăng ký nhận thông báo đẩy.',

    // Generic
    HubSightErrorCode.invalidInput: 'Dữ liệu yêu cầu không hợp lệ.',
    HubSightErrorCode.notFound: 'Không tìm thấy tài nguyên yêu cầu.',
    HubSightErrorCode.conflict: 'Dữ liệu bị trùng lặp hoặc xung đột.',
    HubSightErrorCode.tooManyRequests:
        'Quá nhiều yêu cầu. Vui lòng thử lại sau giây lát.',
    HubSightErrorCode.unknownError: 'Đã xảy ra lỗi không xác định.',
  };
}
