import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../security/secure_storage.dart';
import 'models/batch_models.dart';
import 'models/camera.dart';
import 'models/onvif_models.dart';
import 'models/ptz_models.dart';

/// Service managing surveillance camera inventory, direct snapshot URLs, and ONVIF PTZ controls.
class HubSightCameraService {
  final HubSightApiClient _client;
  final HubSightSecureStorage _storage;

  HubSightCameraService({
    required HubSightApiClient client,
    required HubSightSecureStorage storage,
  })  : _client = client,
        _storage = storage;

  /// Retrieve all available cameras for this account.
  Future<List<Camera>> listCameras() async {
    final data = await _client.get(Endpoints.cameras);
    final camerasRaw = (data as Map)['cameras'] as List? ?? [];
    return camerasRaw
        .map((e) => Camera.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Retrieve detailed information for a single camera by ID.
  Future<Camera> getCamera(String cameraId) async {
    final data = await _client.get(Endpoints.cameraDetail(cameraId));
    return Camera.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Build a fully authenticated snapshot URL suitable for Flutter Image widgets.
  Future<String> buildThumbnailUrl(
    String cameraId, {
    bool bustCache = true,
  }) async {
    final token = await _storage.getAccessToken() ?? '';
    final ts = bustCache ? '&_t=${DateTime.now().millisecondsSinceEpoch}' : '';
    return '${_client.baseUrl}${Endpoints.cameraThumbnail(cameraId)}'
        '?api_key=${_client.apiKey}&token=$token$ts';
  }

  /// Send Pan/Tilt/Zoom command to an ONVIF Profile S camera.
  ///
  /// [action]: 'move' | 'continuous' | 'relative' | 'stop'
  /// [pan], [tilt], [zoom]: velocity or relative coordinate step between -1.0 and 1.0.
  Future<void> ptz(
    String cameraId, {
    required String action,
    double pan = 0.0,
    double tilt = 0.0,
    double zoom = 0.0,
  }) async {
    await _client.post(
      Endpoints.cameraPTZ(cameraId),
      data: PTZActionInput(
        action: action,
        pan: pan,
        tilt: tilt,
        zoom: zoom,
      ).toJson(),
    );
  }

  /// Start continuous PTZ movement with velocity vectors (-1.0 to 1.0).
  Future<void> continuousMove(
    String cameraId, {
    double pan = 0.0,
    double tilt = 0.0,
    double zoom = 0.0,
  }) {
    return ptz(
      cameraId,
      action: 'continuous',
      pan: pan,
      tilt: tilt,
      zoom: zoom,
    );
  }

  /// Move camera relative by a single step (-1.0 to 1.0).
  Future<void> relativeMove(
    String cameraId, {
    double pan = 0.0,
    double tilt = 0.0,
    double zoom = 0.0,
  }) {
    return ptz(
      cameraId,
      action: 'relative',
      pan: pan,
      tilt: tilt,
      zoom: zoom,
    );
  }

  /// Stop all continuous Pan/Tilt/Zoom movements immediately.
  Future<void> stopPtz(String cameraId) {
    return ptz(cameraId, action: 'stop');
  }

  /// List all preset positions saved on the camera.
  Future<List<PresetItem>> getPresets(String cameraId) async {
    final data = await _client.get(Endpoints.cameraPresets(cameraId));
    final presetsRaw =
        (data is List) ? data : ((data as Map)['presets'] as List? ?? []);
    return presetsRaw
        .map((e) => PresetItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Command camera to rotate to a saved preset position.
  Future<void> gotoPreset(String cameraId, String presetToken) async {
    await _client.post(
      Endpoints.cameraPresets(cameraId),
      data: {
        'action': 'goto',
        'preset_token': presetToken,
      },
    );
  }

  /// Save current camera physical coordinates as a new preset position.
  Future<PresetItem> setPreset(String cameraId, String presetName) async {
    final data = await _client.post(
      Endpoints.cameraPresets(cameraId),
      data: {
        'action': 'set',
        'preset_name': presetName,
      },
    );
    return PresetItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Remove a saved preset point from the camera.
  Future<void> removePreset(String cameraId, String presetToken) async {
    await _client.post(
      Endpoints.cameraPresets(cameraId),
      data: {
        'action': 'remove',
        'preset_token': presetToken,
      },
    );
  }

  /// Probe and auto-discover ONVIF hardware, firmware, stream URIs and PTZ capabilities.
  Future<ONVIFProbeResult> probeONVIF({
    String? cameraId,
    String? host,
    int port = 80,
    String? username,
    String? password,
  }) async {
    final data = await _client.post(
      Endpoints.onvifProbe,
      data: {
        if (cameraId != null && cameraId.isNotEmpty) 'camera_id': cameraId,
        if (host != null && host.isNotEmpty) 'host': host,
        'port': port,
        if (username != null && username.isNotEmpty) 'username': username,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    return ONVIFProbeResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Negotiate multiple WebRTC camera stream offers in a single HTTP roundtrip.
  Future<List<BatchWebRTCResultItem>> batchWebRTC(
    List<BatchWebRTCItem> streams,
  ) async {
    final data = await _client.post(
      Endpoints.batchLiveWebRTC,
      data: {
        'streams': streams.map((s) => s.toJson()).toList(),
      },
    );
    final list = (data as Map)['streams'] as List? ?? [];
    return list
        .map((e) =>
            BatchWebRTCResultItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Send unified heartbeat ping for active camera streams.
  Future<BatchHeartbeatResponse> batchHeartbeat({
    List<BatchHeartbeatItem>? leases,
    List<String>? cameraIds,
  }) async {
    final payload = <String, dynamic>{
      if (leases != null) 'leases': leases.map((l) => l.toJson()).toList(),
      if (cameraIds != null) 'camera_ids': cameraIds,
    };

    final data = await _client.post(
      Endpoints.batchLiveHeartbeat,
      data: payload,
    );
    return BatchHeartbeatResponse.fromJson(
        Map<String, dynamic>.from(data as Map));
  }

  /// Release multiple stream leases concurrently when leaving Multi-View grid.
  Future<BatchReleaseResponse> batchRelease({
    List<BatchHeartbeatItem>? leases,
    List<String>? cameraIds,
  }) async {
    final payload = <String, dynamic>{
      if (leases != null) 'leases': leases.map((l) => l.toJson()).toList(),
      if (cameraIds != null) 'camera_ids': cameraIds,
    };

    final data = await _client.post(
      Endpoints.batchLiveRelease,
      data: payload,
    );
    return BatchReleaseResponse.fromJson(
        Map<String, dynamic>.from(data as Map));
  }
}
