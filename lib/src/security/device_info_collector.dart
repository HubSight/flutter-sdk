import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Device metadata compliant with HubSight Client Device Metadata Contract.
class HubSightDeviceMetadata {
  final String fingerprint;
  final String deviceLabel;
  final String clientType;
  final String platform;
  final String osVersion;
  final String model;
  final String manufacturer;
  final String appVersion;
  final String language;
  final String timezone;

  const HubSightDeviceMetadata({
    required this.fingerprint,
    required this.deviceLabel,
    required this.clientType,
    required this.platform,
    required this.osVersion,
    required this.model,
    required this.manufacturer,
    required this.appVersion,
    required this.language,
    required this.timezone,
  });

  Map<String, dynamic> toMap() {
    return {
      'fingerprint': fingerprint,
      'device_label': deviceLabel,
      'client_type': clientType,
      'platform': platform,
      'os_version': osVersion,
      'model': model,
      'manufacturer': manufacturer,
      'app_version': appVersion,
      'language': language,
      'timezone': timezone,
    };
  }

  Map<String, String> toHeaders() {
    return {
      'X-Device-Fingerprint': fingerprint,
      'X-Device-Label': deviceLabel,
      'X-Client-Type': clientType,
    };
  }
}

/// Collector to detect device information, generate stable fingerprint, and produce metadata.
class DeviceInfoCollector {
  final DeviceInfoPlugin _deviceInfo;

  DeviceInfoCollector({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  Future<HubSightDeviceMetadata> collect() async {
    String appVersion = '1.0.0';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
    } catch (_) {}

    String fingerprint = '';
    String model = '';
    String manufacturer = '';
    String osVersion = '';
    String platformName = '';
    String clientType = 'mobile_ios';

    try {
      if (Platform.isIOS) {
        final ios = await _deviceInfo.iosInfo;
        platformName = 'iOS';
        clientType = 'mobile_ios';
        model = ios.utsname.machine;
        manufacturer = 'Apple';
        osVersion = ios.systemVersion;
        final rawId = ios.identifierForVendor ?? 'ios_default_id';
        fingerprint = sha256.convert(utf8.encode(rawId)).toString();
      } else if (Platform.isAndroid) {
        final android = await _deviceInfo.androidInfo;
        platformName = 'Android';
        clientType = 'mobile_android';
        model = android.model;
        manufacturer = android.manufacturer;
        osVersion = android.version.release;
        final rawId = '${android.id}_${android.hardware}';
        fingerprint = sha256.convert(utf8.encode(rawId)).toString();
      } else if (Platform.isMacOS) {
        final mac = await _deviceInfo.macOsInfo;
        platformName = 'macOS';
        clientType = 'desktop_mac';
        model = mac.model;
        manufacturer = 'Apple';
        osVersion = '${mac.majorVersion}.${mac.minorVersion}';
        fingerprint = sha256
            .convert(utf8.encode(mac.systemGUID ?? 'mac_default'))
            .toString();
      } else if (Platform.isWindows) {
        final win = await _deviceInfo.windowsInfo;
        platformName = 'Windows';
        clientType = 'desktop_windows';
        model = win.computerName;
        manufacturer = 'PC';
        osVersion = '${win.majorVersion}.${win.minorVersion}';
        fingerprint = sha256.convert(utf8.encode(win.deviceId)).toString();
      } else if (Platform.isLinux) {
        final linux = await _deviceInfo.linuxInfo;
        platformName = 'Linux';
        clientType = 'desktop_linux';
        model = linux.name;
        manufacturer = 'Linux';
        osVersion = linux.versionId ?? '';
        fingerprint = sha256
            .convert(utf8.encode(linux.machineId ?? 'linux_default'))
            .toString();
      }
    } catch (_) {
      platformName = Platform.operatingSystem;
      clientType = 'unknown';
      fingerprint = sha256.convert(utf8.encode(platformName)).toString();
    }

    final timezone = DateTime.now().timeZoneName;
    final locale = Platform.localeName;
    final deviceLabel =
        '$manufacturer $model ($platformName $osVersion) • App v$appVersion'
            .trim();

    return HubSightDeviceMetadata(
      fingerprint: fingerprint,
      deviceLabel: deviceLabel,
      clientType: clientType,
      platform: platformName,
      osVersion: osVersion,
      model: model,
      manufacturer: manufacturer,
      appVersion: appVersion,
      language: locale,
      timezone: timezone,
    );
  }
}
