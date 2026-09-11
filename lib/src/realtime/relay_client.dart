import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../security/secure_storage.dart';
import 'relay_events.dart';

/// Realtime Relay client connected via WebSocket / Socket.IO to receive live updates and alerts.
class HubSightRelayClient {
  final String relayUrl;
  final HubSightSecureStorage _storage;

  socket_io.Socket? _socket;
  bool _isConnected = false;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<SessionRevokedEvent> _sessionRevokedController =
      StreamController<SessionRevokedEvent>.broadcast();
  final StreamController<AIAlertEvent> _aiAlertController =
      StreamController<AIAlertEvent>.broadcast();
  final StreamController<CameraStatusEvent> _cameraStatusController =
      StreamController<CameraStatusEvent>.broadcast();

  HubSightRelayClient({
    required this.relayUrl,
    required HubSightSecureStorage storage,
  }) : _storage = storage;

  bool get isConnected => _isConnected;
  Stream<bool> get onConnectionChanged => _connectionController.stream;
  Stream<SessionRevokedEvent> get onSessionRevoked =>
      _sessionRevokedController.stream;
  Stream<AIAlertEvent> get onAIAlert => _aiAlertController.stream;
  Stream<CameraStatusEvent> get onCameraStatus =>
      _cameraStatusController.stream;

  /// Connect to the realtime WebSocket relay server.
  Future<void> connect() async {
    if (_socket != null && _isConnected) return;

    disconnect();

    final token = await _storage.getAccessToken();

    _socket = socket_io.io(
      relayUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          })
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionController.add(false);
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _connectionController.add(false);
    });

    // Realtime session revocation (forced kick-out)
    _socket!.on('session:revoked', (data) {
      if (data is Map) {
        final event =
            SessionRevokedEvent.fromJson(Map<String, dynamic>.from(data));
        _sessionRevokedController.add(event);
      }
    });

    // Realtime AI alert detection
    _socket!.on('ai:event', (data) {
      if (data is Map) {
        final event = AIAlertEvent.fromJson(Map<String, dynamic>.from(data));
        _aiAlertController.add(event);
      }
    });

    // Camera online/offline status changes
    _socket!.on('camera:status', (data) {
      if (data is Map) {
        final event =
            CameraStatusEvent.fromJson(Map<String, dynamic>.from(data));
        _cameraStatusController.add(event);
      }
    });

    _socket!.connect();
  }

  /// Disconnect socket connection and free resources.
  void disconnect() {
    if (_socket != null) {
      try {
        _socket!.disconnect();
        _socket!.dispose();
      } catch (_) {}
      _socket = null;
    }
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _connectionController.close();
    _sessionRevokedController.close();
    _aiAlertController.close();
    _cameraStatusController.close();
  }
}
