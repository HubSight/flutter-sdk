import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../security/device_info_collector.dart';

/// Manager for Firebase Cloud Messaging (FCM) device push tokens lifecycle.
class HubSightFCMManager {
  final HubSightApiClient _client;
  final DeviceInfoCollector _deviceCollector;

  HubSightFCMManager({
    required HubSightApiClient client,
    DeviceInfoCollector? deviceCollector,
  })  : _client = client,
        _deviceCollector = deviceCollector ?? DeviceInfoCollector();

  /// Register FCM device token with HubSight gateway upon login.
  Future<void> registerPushToken(String fcmToken) async {
    if (fcmToken.trim().isEmpty) return;

    final device = await _deviceCollector.collect();
    final payload = {
      'fcm_token': fcmToken.trim(),
      'device_name': device.deviceLabel,
      'platform': device.clientType,
      'app_version': device.appVersion,
      'os_version': device.osVersion,
    };

    await _client.post(Endpoints.pushToken, data: payload);
  }

  /// Unregister FCM device token from HubSight gateway upon logout.
  Future<void> unregisterPushToken(String fcmToken) async {
    if (fcmToken.trim().isEmpty) return;

    await _client.delete(
      Endpoints.pushToken,
      data: {'fcm_token': fcmToken.trim()},
    );
  }
}
