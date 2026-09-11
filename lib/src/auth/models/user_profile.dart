/// HubSight User Profile and permissions.
class UserProfile {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String locale;
  final String timezone;
  final String theme;
  final List<String> permissions;
  final bool mustChangePassword;
  final Map<String, bool> pushPreferences;

  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.locale = 'vi',
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.theme = 'system',
    this.permissions = const [],
    this.mustChangePassword = false,
    this.pushPreferences = const {},
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    List<String> perms = [];
    if (json['permissions'] is List) {
      perms = (json['permissions'] as List).map((e) => e.toString()).toList();
    }

    Map<String, bool> pushPrefs = {};
    if (json['push_preferences'] is Map) {
      final map = json['push_preferences'] as Map;
      map.forEach((k, v) {
        pushPrefs[k.toString()] = v == true;
      });
    }

    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      locale: json['locale'] as String? ?? 'vi',
      timezone: json['timezone'] as String? ?? 'Asia/Ho_Chi_Minh',
      theme: json['theme'] as String? ?? 'system',
      permissions: perms,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      pushPreferences: pushPrefs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'role': role,
      'locale': locale,
      'timezone': timezone,
      'theme': theme,
      'permissions': permissions,
      'must_change_password': mustChangePassword,
      'push_preferences': pushPreferences,
    };
  }

  bool hasPermission(String perm) {
    if (permissions.contains('*') || role == 'admin') return true;
    return permissions.contains(perm);
  }
}
