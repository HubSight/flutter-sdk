import 'jwt_claims.dart';
import 'user_profile.dart';

/// Result of a login attempt or 2FA verification.
class AuthResult {
  final bool isSuccess;
  final bool requires2FA;
  final String? preAuthToken;
  final String? accessToken;
  final String? refreshToken;
  final String tokenType;
  final int? expiresIn;
  final bool mustChangePassword;
  final UserProfile? user;
  final String? message;

  const AuthResult({
    required this.isSuccess,
    this.requires2FA = false,
    this.preAuthToken,
    this.accessToken,
    this.refreshToken,
    this.tokenType = 'Bearer',
    this.expiresIn,
    this.mustChangePassword = false,
    this.user,
    this.message,
  });

  /// Parse claims if [accessToken] is a valid JWT.
  HubSightJWTClaims? get claims =>
      accessToken != null ? HubSightJWTClaims.tryParse(accessToken!) : null;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    if (json['requires_2fa'] == true ||
        json['status'] == '2fa_required' ||
        json['status'] == 'two_factor_required' ||
        json['code'] == 'TWO_FACTOR_REQUIRED' ||
        json['code'] == '2FA_REQUIRED') {
      return AuthResult(
        isSuccess: false,
        requires2FA: true,
        preAuthToken: json['pre_auth_token'] as String?,
        message:
            json['message'] as String? ?? 'Yêu cầu xác thực hai bước (2FA).',
      );
    }

    final userJson = json['user'];
    UserProfile? user;
    if (userJson is Map<String, dynamic>) {
      user = UserProfile.fromJson(userJson);
    } else if (userJson is Map) {
      user = UserProfile.fromJson(Map<String, dynamic>.from(userJson));
    }

    return AuthResult(
      isSuccess: true,
      requires2FA: false,
      accessToken: (json['access_token'] ?? json['token']) as String?,
      refreshToken: json['refresh_token'] as String?,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresIn: json['expires_in'] as int?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      user: user,
      message: json['message'] as String?,
    );
  }
}
