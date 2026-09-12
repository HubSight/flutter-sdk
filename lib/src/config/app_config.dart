/// Models representing HubSight decrypted configuration package (.hscfg).
class HubSightUrls {
  final String gatewayUrl;
  final String apiBaseUrl;
  final String relayWsUrl;
  final String webrtcBaseUrl;
  final String webrtcSignalingUrl;
  final int webrtcMediaPort;

  const HubSightUrls({
    required this.gatewayUrl,
    required this.apiBaseUrl,
    required this.relayWsUrl,
    required this.webrtcBaseUrl,
    this.webrtcSignalingUrl = '',
    this.webrtcMediaPort = 8555,
  });

  factory HubSightUrls.fromMap(Map<String, dynamic> map) {
    final gw = (map['gateway_url'] as String? ?? '').trim();
    final signaling = (map['webrtc_signaling_url'] as String? ?? '').trim();
    return HubSightUrls(
      gatewayUrl: gw,
      apiBaseUrl: (map['api_base_url'] as String? ?? '').trim(),
      relayWsUrl: (map['relay_ws_url'] as String? ?? '').trim(),
      webrtcBaseUrl: (map['webrtc_base_url'] as String? ?? '').trim(),
      webrtcSignalingUrl:
          signaling.isNotEmpty ? signaling : (gw.isNotEmpty ? '$gw/webrtc' : ''),
      webrtcMediaPort: map['webrtc_media_port'] is int
          ? map['webrtc_media_port'] as int
          : int.tryParse(map['webrtc_media_port']?.toString() ?? '') ?? 8555,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gateway_url': gatewayUrl,
      'api_base_url': apiBaseUrl,
      'relay_ws_url': relayWsUrl,
      'webrtc_base_url': webrtcBaseUrl,
      'webrtc_signaling_url': webrtcSignalingUrl,
      'webrtc_media_port': webrtcMediaPort,
    };
  }
}

class HubSightClientKey {
  final String clientId;
  final String clientSecret;
  final String clientName;
  final String apiKey;
  final List<String> allowedScopes;

  const HubSightClientKey({
    required this.clientId,
    required this.clientSecret,
    required this.clientName,
    this.apiKey = '',
    this.allowedScopes = const [],
  });

  factory HubSightClientKey.fromMap(Map<String, dynamic> map) {
    final scopesRaw = map['allowed_scopes'];
    List<String> scopes = [];
    if (scopesRaw is List) {
      scopes = scopesRaw.map((e) => e.toString()).toList();
    }
    final apiKeyVal = (map['api_key'] as String? ?? '').trim();
    final clientSecretVal =
        (map['client_secret'] as String? ?? '').trim();
    return HubSightClientKey(
      clientId: (map['client_id'] as String? ?? '').trim(),
      clientSecret: clientSecretVal,
      clientName: (map['client_name'] as String? ?? '').trim(),
      apiKey: apiKeyVal,
      allowedScopes: scopes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'client_id': clientId,
      'client_secret': clientSecret,
      'client_name': clientName,
      'api_key': apiKey,
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
  final String? contentSha256;
  final String? signatureAlgorithm;

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
    this.contentSha256,
    this.signatureAlgorithm,
  });

  factory HubSightConfigMetadata.fromMap(Map<String, dynamic> map) {
    return HubSightConfigMetadata(
      formatVersion:
          (map['format_version'] ?? map['version'] ?? '1.0').toString(),
      configId: (map['config_id'] ?? '').toString(),
      name: (map['name'] ?? map['config_name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      createdBy:
          (map['created_by'] ?? map['created_by_username'] ?? '').toString(),
      createdAtUtc: (map['created_at_utc'] ?? map['created_at'])?.toString(),
      generator: (map['generator'] ?? map['issuer'])?.toString(),
      ed25519PublicKey:
          (map['ed25519_public_key'] ?? map['public_key'])?.toString(),
      signature: (map['signature'] ?? map['digital_signature'])?.toString(),
      contentSha256: map['content_sha256']?.toString(),
      signatureAlgorithm: map['signature_algorithm']?.toString(),
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
      if (contentSha256 != null) 'content_sha256': contentSha256,
      if (signatureAlgorithm != null) 'signature_algorithm': signatureAlgorithm,
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
  String get apiKey {
    if (key.apiKey.isNotEmpty) return key.apiKey;
    if (key.clientId.isNotEmpty) return key.clientId;
    return 'hs_mob_client_default';
  }
}
