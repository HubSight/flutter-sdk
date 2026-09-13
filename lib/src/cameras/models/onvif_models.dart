/// Hardware and firmware details returned by ONVIF device discovery.
class ONVIFDeviceInfo {
  final String manufacturer;
  final String model;
  final String firmwareVersion;
  final String serialNumber;
  final String hardwareId;

  const ONVIFDeviceInfo({
    required this.manufacturer,
    required this.model,
    required this.firmwareVersion,
    required this.serialNumber,
    required this.hardwareId,
  });

  factory ONVIFDeviceInfo.fromJson(Map<String, dynamic> json) {
    return ONVIFDeviceInfo(
      manufacturer: json['manufacturer'] as String? ?? '',
      model: json['model'] as String? ?? '',
      firmwareVersion: json['firmware_version'] as String? ?? '',
      serialNumber: json['serial_number'] as String? ?? '',
      hardwareId: json['hardware_id'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'firmware_version': firmwareVersion,
      'serial_number': serialNumber,
      'hardware_id': hardwareId,
    };
  }
}

/// Media stream profile (video resolution, codec, and RTSP stream URI).
class ONVIFMediaProfile {
  final String token;
  final String name;
  final String videoCodec;
  final int width;
  final int height;
  final int fps;
  final String? streamUri;

  const ONVIFMediaProfile({
    required this.token,
    required this.name,
    required this.videoCodec,
    required this.width,
    required this.height,
    required this.fps,
    this.streamUri,
  });

  factory ONVIFMediaProfile.fromJson(Map<String, dynamic> json) {
    return ONVIFMediaProfile(
      token: json['token'] as String? ?? '',
      name: json['name'] as String? ?? '',
      videoCodec: json['video_codec'] as String? ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      fps: (json['fps'] as num?)?.toInt() ?? 0,
      streamUri: json['stream_uri'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'name': name,
      'video_codec': videoCodec,
      'width': width,
      'height': height,
      'fps': fps,
      if (streamUri != null) 'stream_uri': streamUri,
    };
  }
}

/// Comprehensive ONVIF discovery and inspection report.
class ONVIFProbeResult {
  final bool success;
  final String host;
  final int port;
  final ONVIFDeviceInfo deviceInfo;
  final bool hasPtz;
  final List<ONVIFMediaProfile> profiles;
  final String mainStreamUri;
  final String subStreamUri;
  final String? mainProfileToken;
  final String? errorMessage;

  const ONVIFProbeResult({
    required this.success,
    required this.host,
    required this.port,
    required this.deviceInfo,
    required this.hasPtz,
    required this.profiles,
    required this.mainStreamUri,
    required this.subStreamUri,
    this.mainProfileToken,
    this.errorMessage,
  });

  factory ONVIFProbeResult.fromJson(Map<String, dynamic> json) {
    final devInfoJson = json['device_info'] as Map? ?? {};
    final profilesRaw = json['profiles'] as List? ?? [];

    return ONVIFProbeResult(
      success: json['success'] as bool? ?? false,
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 80,
      deviceInfo:
          ONVIFDeviceInfo.fromJson(Map<String, dynamic>.from(devInfoJson)),
      hasPtz: json['has_ptz'] as bool? ?? false,
      profiles: profilesRaw
          .map((e) =>
              ONVIFMediaProfile.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      mainStreamUri: json['main_stream_uri'] as String? ?? '',
      subStreamUri: json['sub_stream_uri'] as String? ?? '',
      mainProfileToken: json['main_profile_token'] as String?,
      errorMessage: json['error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'host': host,
      'port': port,
      'device_info': deviceInfo.toJson(),
      'has_ptz': hasPtz,
      'profiles': profiles.map((p) => p.toJson()).toList(),
      'main_stream_uri': mainStreamUri,
      'sub_stream_uri': subStreamUri,
      if (mainProfileToken != null) 'main_profile_token': mainProfileToken,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }
}
