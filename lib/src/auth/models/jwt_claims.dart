import 'dart:convert';

/// Decoded JSON Web Token (JWT) claims emitted by HubSight Auth Gateway.
class HubSightJWTClaims {
  /// Subject identifier (User ID).
  final String userId;

  /// Username of the authenticated user.
  final String username;

  /// Role assigned to the user (e.g., 'admin', 'operator', 'viewer').
  final String role;

  /// Unique session identifier associated with this token.
  final String sessionId;

  /// Token expiration Unix timestamp (in seconds).
  final int? exp;

  /// Token issued-at Unix timestamp (in seconds).
  final int? iat;

  /// Token not-before Unix timestamp (in seconds).
  final int? nbf;

  /// Token issuer.
  final String? iss;

  /// Token intended audience.
  final dynamic aud;

  /// All unparsed raw claims in the JWT payload.
  final Map<String, dynamic> rawClaims;

  const HubSightJWTClaims({
    required this.userId,
    required this.username,
    required this.role,
    required this.sessionId,
    this.exp,
    this.iat,
    this.nbf,
    this.iss,
    this.aud,
    this.rawClaims = const {},
  });

  /// Expiration date/time in UTC.
  DateTime? get expiresAt => exp != null
      ? DateTime.fromMillisecondsSinceEpoch(exp! * 1000, isUtc: true)
      : null;

  /// Issuance date/time in UTC.
  DateTime? get issuedAt => iat != null
      ? DateTime.fromMillisecondsSinceEpoch(iat! * 1000, isUtc: true)
      : null;

  /// Whether this token has passed its expiration time.
  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().toUtc().isAfter(expiry);
  }

  /// Construct claims from decoded JSON map.
  factory HubSightJWTClaims.fromJson(Map<String, dynamic> json) {
    return HubSightJWTClaims(
      userId: json['sub'] as String? ?? json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      exp: (json['exp'] as num?)?.toInt(),
      iat: (json['iat'] as num?)?.toInt(),
      nbf: (json['nbf'] as num?)?.toInt(),
      iss: json['iss'] as String?,
      aud: json['aud'],
      rawClaims: Map<String, dynamic>.unmodifiable(json),
    );
  }

  /// Safely parse and extract claims from a standard signed JWT string.
  ///
  /// Returns `null` if the token is malformed, not a 3-part JWT, or payload cannot be decoded.
  static HubSightJWTClaims? tryParse(String token) {
    final parts = token.trim().split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payloadBytes = base64Url.decode(normalized);
      final jsonString = utf8.decode(payloadBytes);
      final map = jsonDecode(jsonString);
      if (map is Map<String, dynamic>) {
        return HubSightJWTClaims.fromJson(map);
      } else if (map is Map) {
        return HubSightJWTClaims.fromJson(Map<String, dynamic>.from(map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => rawClaims;

  @override
  String toString() =>
      'HubSightJWTClaims(userId: $userId, username: $username, role: $role, sessionId: $sessionId, isExpired: $isExpired)';
}
