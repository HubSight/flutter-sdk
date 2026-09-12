/// Represents a registered FIDO2 / WebAuthn passkey credential.
class PasskeyItem {
  final String id;
  final String name;
  final String? aaguid;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;

  const PasskeyItem({
    required this.id,
    required this.name,
    this.aaguid,
    this.createdAt,
    this.lastUsedAt,
  });

  factory PasskeyItem.fromJson(Map<String, dynamic> json) {
    return PasskeyItem(
      id: json['id'] as String? ?? json['credential_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Passkey',
      aaguid: json['aaguid'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      lastUsedAt: json['last_used_at'] != null
          ? DateTime.tryParse(json['last_used_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (aaguid != null) 'aaguid': aaguid,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (lastUsedAt != null) 'last_used_at': lastUsedAt!.toIso8601String(),
    };
  }
}
