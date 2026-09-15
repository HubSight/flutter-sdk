library hubsight_sdk;

import 'dart:async';
import 'dart:typed_data';

// Configuration & Decoders
export 'src/config/app_config.dart';
export 'src/config/hscfg_decoder.dart';
export 'src/config/qr_payload.dart';

// Security & Fingerprinting
export 'src/security/secure_storage.dart';
export 'src/security/device_info_collector.dart';

// Network & Errors
export 'src/network/api_client.dart';
export 'src/network/endpoints.dart';
export 'src/network/error_codes.dart';
export 'src/network/exceptions.dart';
export 'src/network/auth_interceptor.dart';

// Auth & Profile
export 'src/auth/auth_manager.dart';
export 'src/auth/models/auth_response.dart';
export 'src/auth/models/jwt_claims.dart';
export 'src/auth/models/user_profile.dart';
export 'src/auth/models/session_item.dart';
export 'src/auth/models/passkey_item.dart';

// Cameras
export 'src/cameras/camera_service.dart';
export 'src/cameras/models/camera.dart';
export 'src/cameras/models/ptz_models.dart';
export 'src/cameras/models/onvif_models.dart';
export 'src/cameras/models/batch_models.dart';

// Media & WebRTC
export 'src/media/webrtc_manager.dart';
export 'src/media/multi_view_session.dart';

// Archive & Playback
export 'src/archive/archive_service.dart';
export 'src/archive/models/archive_calendar.dart';
export 'src/archive/models/archive_segment.dart';
export 'src/archive/models/play_stream.dart';

// Notifications & FCM
export 'src/notifications/notification_service.dart';
export 'src/notifications/fcm_manager.dart';
export 'src/notifications/models/app_notification.dart';

// Realtime Relay
export 'src/realtime/relay_client.dart';
export 'src/realtime/relay_events.dart';

// Lifecycle
export 'src/lifecycle/app_lifecycle_manager.dart';

// UI Widgets
export 'src/widgets/camera_thumbnail_view.dart';
export 'src/widgets/webrtc_video_view.dart';
export 'src/widgets/multi_view_grid.dart';
export 'src/widgets/ptz_pad.dart';

import 'src/config/app_config.dart';
import 'src/config/hscfg_decoder.dart';
import 'src/security/secure_storage.dart';
import 'src/security/device_info_collector.dart';
import 'src/network/api_client.dart';
import 'src/network/exceptions.dart';
import 'src/auth/auth_manager.dart';
import 'src/cameras/camera_service.dart';
import 'src/archive/archive_service.dart';
import 'src/notifications/notification_service.dart';
import 'src/notifications/fcm_manager.dart';
import 'src/realtime/relay_client.dart';
import 'src/media/webrtc_manager.dart';
import 'src/media/multi_view_session.dart';
import 'src/lifecycle/app_lifecycle_manager.dart';

/// Central SDK facade for HubSight CCTV Mobile & Desktop apps.
class HubSightSDK {
  static HubSightSDK? _instance;
  static HubSightSDK get instance {
    if (_instance == null) {
      throw StateError(
        'HubSightSDK has not been initialized. Call HubSightSDK.initialize() or HubSightSDK.fromHscfg() first.',
      );
    }
    return _instance!;
  }

  final HubSightAppConfig config;
  final HubSightSecureStorage storage;
  final DeviceInfoCollector deviceCollector;
  final HubSightApiClient client;
  final HubSightAuthManager auth;
  final HubSightCameraService cameras;
  final HubSightArchiveService archive;
  final HubSightNotificationService notifications;
  final HubSightFCMManager fcm;
  final HubSightRelayClient relay;
  final HubSightLifecycleManager lifecycle;

  final StreamController<MaintenanceException> _maintenanceController =
      StreamController<MaintenanceException>.broadcast();
  final StreamController<void> _sessionExpiredController =
      StreamController<void>.broadcast();

  Stream<MaintenanceException> get onMaintenanceMode =>
      _maintenanceController.stream;
  Stream<void> get onSessionExpired => _sessionExpiredController.stream;

  HubSightSDK._({
    required this.config,
    required this.storage,
    required this.deviceCollector,
    required this.client,
    required this.auth,
    required this.cameras,
    required this.archive,
    required this.notifications,
    required this.fcm,
    required this.relay,
    required this.lifecycle,
  });

  /// Initialize the SDK directly from an existing [HubSightAppConfig].
  static Future<HubSightSDK> initialize({
    required HubSightAppConfig config,
    HubSightSecureStorage? storage,
    DeviceInfoCollector? deviceCollector,
    void Function(MaintenanceException)? onMaintenance,
    void Function()? onSessionExpired,
  }) async {
    final secStorage = storage ?? HubSightSecureStorage();
    await secStorage.saveAppConfig(config);

    final collector = deviceCollector ?? DeviceInfoCollector();

    late HubSightSDK sdk;

    final apiClient = HubSightApiClient(
      baseUrl: config.urls.apiBaseUrl,
      apiKey: config.apiKey,
      storage: secStorage,
      onMaintenance: (m) {
        sdk._maintenanceController.add(m);
        onMaintenance?.call(m);
      },
      onSessionExpired: () {
        sdk._sessionExpiredController.add(null);
        onSessionExpired?.call();
      },
    );

    final authManager = HubSightAuthManager(
      client: apiClient,
      storage: secStorage,
      deviceCollector: collector,
    );

    final cameraService = HubSightCameraService(
      client: apiClient,
      storage: secStorage,
    );

    final archiveService = HubSightArchiveService(client: apiClient);

    final notifService = HubSightNotificationService(client: apiClient);

    final fcmManager = HubSightFCMManager(
      client: apiClient,
      deviceCollector: collector,
    );

    final relayClient = HubSightRelayClient(
      relayUrl: config.urls.relayWsUrl,
      storage: secStorage,
    );

    final lifecycleManager = HubSightLifecycleManager();

    sdk = HubSightSDK._(
      config: config,
      storage: secStorage,
      deviceCollector: collector,
      client: apiClient,
      auth: authManager,
      cameras: cameraService,
      archive: archiveService,
      notifications: notifService,
      fcm: fcmManager,
      relay: relayClient,
      lifecycle: lifecycleManager,
    );

    // Auto-listen to remote session revocation over relay
    relayClient.onSessionRevoked.listen((event) {
      sdk.auth.logout();
      sdk._sessionExpiredController.add(null);
    });

    _instance = sdk;
    return sdk;
  }

  /// Zero-Config Enrollment: Decrypt container [.hscfg] with 6-digit PIN and initialize SDK.
  static Future<HubSightSDK> fromHscfg({
    required Uint8List fileBytes,
    required String pin6Digits,
    bool verifySignature = true,
    HubSightSecureStorage? storage,
    DeviceInfoCollector? deviceCollector,
    void Function(MaintenanceException)? onMaintenance,
    void Function()? onSessionExpired,
  }) async {
    final config = await HscfgDecoder.decrypt(
      fileBytes: fileBytes,
      pin6Digits: pin6Digits,
      verifySignature: verifySignature,
    );

    return initialize(
      config: config,
      storage: storage,
      deviceCollector: deviceCollector,
      onMaintenance: onMaintenance,
      onSessionExpired: onSessionExpired,
    );
  }

  /// Try to restore SDK instance using cached credentials in secure storage.
  static Future<HubSightSDK?> restoreFromStorage({
    HubSightSecureStorage? storage,
    DeviceInfoCollector? deviceCollector,
    void Function(MaintenanceException)? onMaintenance,
    void Function()? onSessionExpired,
  }) async {
    final secStorage = storage ?? HubSightSecureStorage();
    final cachedConfig = await secStorage.getSavedAppConfig();
    if (cachedConfig == null) return null;

    return initialize(
      config: cachedConfig,
      storage: secStorage,
      deviceCollector: deviceCollector,
      onMaintenance: onMaintenance,
      onSessionExpired: onSessionExpired,
    );
  }

  /// Create a new WebRTC streaming controller for a single camera.
  HubSightWebRTCManager createWebRTCManager(String cameraId) {
    return HubSightWebRTCManager(client: client, cameraId: cameraId);
  }

  /// Create a Multi-View session manager for viewing grid cameras with batch WebRTC.
  MultiViewStreamSession createMultiViewSession() {
    return MultiViewStreamSession(client);
  }

  /// Release all resources, sockets, and timers.
  void dispose() {
    relay.dispose();
    auth.dispose();
    lifecycle.dispose();
    _maintenanceController.close();
    _sessionExpiredController.close();
    if (_instance == this) {
      _instance = null;
    }
  }
}
