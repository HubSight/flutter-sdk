import '../network/api_client.dart';
import '../network/endpoints.dart';
import '../security/secure_storage.dart';
import 'models/camera.dart';

/// Service managing surveillance camera inventory and direct snapshot URLs.
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
}
