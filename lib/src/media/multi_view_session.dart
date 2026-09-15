import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';

/// Multi-View batch WebRTC orchestrator for high-performance camera grid viewing.
class MultiViewStreamSession {
  final HubSightApiClient _client;
  final Map<String, RTCPeerConnection> _activeConnections = {};
  final Map<String, RTCVideoRenderer> _renderers = {};
  final Map<String, String> _streamNames = {};

  Timer? _heartbeatTimer;
  bool _isRunning = false;

  MultiViewStreamSession(this._client);

  bool get isRunning => _isRunning;
  List<String> get activeCameraIds => _activeConnections.keys.toList();
  RTCVideoRenderer? getRenderer(String cameraId) => _renderers[cameraId];

  /// Start simultaneous WebRTC streams using a single batch negotiation request.
  Future<void> startStreams(List<String> cameraIds) async {
    if (cameraIds.isEmpty) return;

    // 1. Stop any currently active streams first
    await stopAll();

    _isRunning = true;
    final batchRequests = <Map<String, dynamic>>[];

    // 2. Initialize local PeerConnections & renderers concurrently
    for (final camId in cameraIds) {
      try {
        final pc = await createPeerConnection({
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'},
          ],
          'sdpSemantics': 'unified-plan',
        });

        final renderer = RTCVideoRenderer();
        await renderer.initialize();

        pc.onTrack = (event) {
          if (event.track.kind == 'video' && event.streams.isNotEmpty) {
            renderer.srcObject = event.streams[0];
          }
        };

        // Add recvonly video transceiver
        await pc.addTransceiver(
          kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
        );

        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);

        _activeConnections[camId] = pc;
        _renderers[camId] = renderer;

        batchRequests.add({
          'camera_id': camId,
          'sdp_offer': offer.sdp,
        });
      } catch (e) {
        // Continue with other cameras if one local setup fails
      }
    }

    if (batchRequests.isEmpty) return;

    // 3. Send single batch request to HubSight Gateway
    try {
      final response = await _client.post(
        Endpoints.batchLiveWebRTC,
        data: {'streams': batchRequests},
      );

      final streamsResult = (response as Map)['streams'] as List? ?? [];
      for (final item in streamsResult) {
        final resMap = Map<String, dynamic>.from(item as Map);
        final camId = resMap['camera_id'] as String?;
        final answerSdp = resMap['sdp_answer'] as String?;
        final streamName = resMap['pool_stream_name'] as String?;

        if (camId != null &&
            answerSdp != null &&
            _activeConnections.containsKey(camId)) {
          if (streamName != null) {
            _streamNames[camId] = streamName;
          }
          final pc = _activeConnections[camId]!;
          await pc
              .setRemoteDescription(RTCSessionDescription(answerSdp, 'answer'));
        }
      }

      // 4. Start 30-second unified batch heartbeat timer
      _startHeartbeat();
    } catch (e) {
      await stopAll();
      rethrow;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      final leases = <Map<String, String>>[];
      _streamNames.forEach((camId, streamName) {
        leases.add({
          'camera_id': camId,
          'stream_name': streamName,
        });
      });

      if (leases.isEmpty) return;

      try {
        await _client.post(
          Endpoints.batchLiveHeartbeat,
          data: {
            'leases': leases,
            'camera_ids': _streamNames.keys.toList(),
          },
        );
      } catch (_) {
        // Next tick will retry
      }
    });
  }

  /// Stop all streams and release all active go2rtc leases in a single batch request.
  Future<void> stopAll() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isRunning = false;

    // 1. Send batch release request
    final leases = <Map<String, String>>[];
    _streamNames.forEach((camId, streamName) {
      leases.add({
        'camera_id': camId,
        'stream_name': streamName,
      });
    });

    if (leases.isNotEmpty) {
      try {
        await _client.post(
          Endpoints.batchLiveRelease,
          data: {
            'leases': leases,
            'camera_ids': _streamNames.keys.toList(),
          },
        );
      } catch (_) {}
    }

    // 2. Dispose all peer connections and video renderers
    for (final pc in _activeConnections.values) {
      try {
        await pc.close();
      } catch (_) {}
    }
    for (final renderer in _renderers.values) {
      try {
        await renderer.dispose();
      } catch (_) {}
    }

    _activeConnections.clear();
    _renderers.clear();
    _streamNames.clear();
  }

  void dispose() {
    stopAll();
  }
}
