/// Model representing an active user login session across devices.
class SessionItem {
  final String id;
  final String clientId;
  final bool isPwa;
  final bool isCurrent;
  final DateTime expiresAt;
  final DateTime createdAt;

  // Geolocation fields
  final String? geoCity;
  final String? geoCountry;
  final String? geoRegion;
  final double? geoLatitude;
  final double? geoLongitude;
  final double? geoAccuracy;

  // Audit & Device fields
  final String? ipAddress;
  final String? userAgent;
  final String? deviceFingerprint;
  final String? deviceLabel;
  final String? clientType;
  final bool? isNewDevice;
  final bool? isActive;
  final DateTime? lastActiveAt;
  final DateTime? revokedAt;
  final String? revokeReason;

  const SessionItem({
    required this.id,
    required this.clientId,
    required this.isPwa,
    required this.isCurrent,
    required this.expiresAt,
    required this.createdAt,
    this.geoCity,
    this.geoCountry,
    this.geoRegion,
    this.geoLatitude,
    this.geoLongitude,
    this.geoAccuracy,
    this.ipAddress,
    this.userAgent,
    this.deviceFingerprint,
    this.deviceLabel,
    this.clientType,
    this.isNewDevice,
    this.isActive,
    this.lastActiveAt,
    this.revokedAt,
    this.revokeReason,
  });

  factory SessionItem.fromJson(Map<String, dynamic> json) {
    return SessionItem(
      id: json['id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      isPwa: json['is_pwa'] as bool? ?? false,
      isCurrent: json['is_current'] as bool? ?? false,
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      geoCity: json['geo_city'] as String?,
      geoCountry: json['geo_country'] as String?,
      geoRegion: json['geo_region'] as String?,
      geoLatitude: (json['geo_latitude'] as num?)?.toDouble(),
      geoLongitude: (json['geo_longitude'] as num?)?.toDouble(),
      geoAccuracy: (json['geo_accuracy'] as num?)?.toDouble(),
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      deviceFingerprint: json['device_fingerprint'] as String?,
      deviceLabel: json['device_label'] as String?,
      clientType: json['client_type'] as String?,
      isNewDevice: json['is_new_device'] as bool?,
      isActive: json['is_active'] as bool?,
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'] as String)
          : null,
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'] as String)
          : null,
      revokeReason: json['revoke_reason'] as String?,
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
      if (geoCity != null) 'geo_city': geoCity,
      if (geoCountry != null) 'geo_country': geoCountry,
      if (geoRegion != null) 'geo_region': geoRegion,
      if (geoLatitude != null) 'geo_latitude': geoLatitude,
      if (geoLongitude != null) 'geo_longitude': geoLongitude,
      if (geoAccuracy != null) 'geo_accuracy': geoAccuracy,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (userAgent != null) 'user_agent': userAgent,
      if (deviceFingerprint != null) 'device_fingerprint': deviceFingerprint,
      if (deviceLabel != null) 'device_label': deviceLabel,
      if (clientType != null) 'client_type': clientType,
      if (isNewDevice != null) 'is_new_device': isNewDevice,
      if (isActive != null) 'is_active': isActive,
      if (lastActiveAt != null)
        'last_active_at': lastActiveAt!.toIso8601String(),
      if (revokedAt != null) 'revoked_at': revokedAt!.toIso8601String(),
      if (revokeReason != null) 'revoke_reason': revokeReason,
    };
  }
}
