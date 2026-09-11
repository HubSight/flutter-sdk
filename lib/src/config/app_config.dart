/// Models representing HubSight decrypted configuration package (.hscfg).
class HubSightUrls {
  final String gatewayUrl;
  final String apiBaseUrl;
  final String relayWsUrl;
  final String webrtcBaseUrl;

  const HubSightUrls({
    required this.gatewayUrl,
    required this.apiBaseUrl,
    required this.relayWsUrl,
    required this.webrtcBaseUrl,
  });

  factory HubSightUrls.fromMap(Map<String, dynamic> map) {
    return HubSightUrls(
      gatewayUrl: (map['gateway_url'] as String? ?? '').trim(),
      apiBaseUrl: (map['api_base_url'] as String? ?? '').trim(),
      relayWsUrl: (map['relay_ws_url'] as String? ?? '').trim(),
      webrtcBaseUrl: (map['webrtc_base_url'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gateway_url': gatewayUrl,
      'api_base_url': apiBaseUrl,
      'relay_ws_url': relayWsUrl,
      'webrtc_base_url': webrtcBaseUrl,
    };
  }
}

class HubSightClientKey {
  final String clientId;
  final String clientSecret;
  final String clientName;
  final List<String> allowedScopes;

  const HubSightClientKey({
    required this.clientId,
    required this.clientSecret,
    required this.clientName,
    this.allowedScopes = const [],
  });

  factory HubSightClientKey.fromMap(Map<String, dynamic> map) {
    final scopesRaw = map['allowed_scopes'];
    List<String> scopes = [];
    if (scopesRaw is List) {
      scopes = scopesRaw.map((e) => e.toString()).toList();
    }
    return HubSightClientKey(
      clientId: (map['client_id'] as String? ?? '').trim(),
      clientSecret: (map['client_secret'] as String? ?? '').trim(),
      clientName: (map['client_name'] as String? ?? '').trim(),
      allowedScopes: scopes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'client_secret': clientSecret,
      'client_name': clientName,
      'allowed_scopes': allowedScopes,
    };
  }
}

class HubSightConfigMetadata {
  final String formatVersion;
  final String configId;
  final String name;
  final String description;
  final String createdBy;
  final String? createdAtUtc;
  final String? generator;
  final String? ed25519PublicKey;
  final String? signature;

  const HubSightConfigMetadata({
    required this.formatVersion,
    required this.configId,
    required this.name,
    this.description = '',
    this.createdBy = '',
    this.createdAtUtc,
    this.generator,
    this.ed25519PublicKey,
    this.signature,
  });

  factory HubSightConfigMetadata.fromMap(Map<String, dynamic> map) {
    return HubSightConfigMetadata(
      formatVersion: map['format_version'] as String? ?? '1.0',
      configId: map['config_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdBy: map['created_by'] as String? ?? '',
      createdAtUtc: map['created_at_utc'] as String?,
      generator: map['generator'] as String?,
      ed25519PublicKey: map['ed25519_public_key'] as String?,
      signature: map['signature'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'format_version': formatVersion,
      'config_id': configId,
      'name': name,
      'description': description,
      'created_by': createdBy,
      'created_at_utc': createdAtUtc,
      'generator': generator,
      'ed25519_public_key': ed25519PublicKey,
      'signature': signature,
    };
  }
}

class HubSightAppConfig {
  final HubSightUrls urls;
  final HubSightClientKey key;
  final HubSightConfigMetadata metadata;
  final String? googleServicesJson;
  final String? googleServiceInfoPlist;
  final String? caCertPem;

  const HubSightAppConfig({
    required this.urls,
    required this.key,
    required this.metadata,
    this.googleServicesJson,
    this.googleServiceInfoPlist,
    this.caCertPem,
  });

  /// The primary API Key used for `X-API-Key` headers
  String get apiKey => key.clientId;
}
