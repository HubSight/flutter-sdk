import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';

enum StreamStatus {
  idle,
  connecting,
  connected,
  failed,
  stopped,
}

/// WebRTC Stream Controller for a single camera.
class HubSightWebRTCManager {
  final HubSightApiClient _client;
  final String cameraId;

  RTCPeerConnection? _peerConnection;
  RTCVideoRenderer? _renderer;
  String? _streamName;
  Timer? _heartbeatTimer;
  StreamStatus _status = StreamStatus.idle;

  final StreamController<StreamStatus> _statusController =
      StreamController<StreamStatus>.broadcast();

  HubSightWebRTCManager({
    required HubSightApiClient client,
    required this.cameraId,
  }) : _client = client;

  StreamStatus get status => _status;
  Stream<StreamStatus> get onStatusChanged => _statusController.stream;
  RTCVideoRenderer? get renderer => _renderer;

  void _setStatus(StreamStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  /// Initialize renderer and establish WebRTC stream via SDP negotiation.
  Future<RTCVideoRenderer> startStream() async {
    if (_status == StreamStatus.connected && _renderer != null) {
      return _renderer!;
    }

    _setStatus(StreamStatus.connecting);

    try {
      _renderer = RTCVideoRenderer();
      await _renderer!.initialize();

      // Configure PeerConnection (WebRTC router on internal/external gateway)
      final rtcConfig = <String, dynamic>{
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
        'sdpSemantics': 'unified-plan',
      };

      _peerConnection = await createPeerConnection(rtcConfig);

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          _renderer!.srcObject = event.streams[0];
          _setStatus(StreamStatus.connected);
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          _setStatus(StreamStatus.failed);
        }
      };

      // Add receive-only video transceiver
      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      // Create local SDP Offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Negotiate SDP Offer with HubSight Gateway
      final response = await _client.rawDio.post(
        Endpoints.cameraLiveWebRTC(cameraId),
        data: offer.sdp,
        options: Options(
          contentType: 'application/sdp',
          responseType: ResponseType.plain,
        ),
      );

      _streamName = response.headers.value('X-Pool-Stream-Name');

      final answerSdp = response.data.toString();
      if (answerSdp.isEmpty) {
        throw Exception('Empty SDP Answer received from media router');
      }

      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(answerSdp, 'answer'),
      );

      // Start 30-second lease heartbeat
      _startHeartbeat();

      return _renderer!;
    } catch (e) {
      _setStatus(StreamStatus.failed);
      await stopStream();
      rethrow;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_streamName == null) return;
      try {
        await _client.post(
          Endpoints.cameraLiveHeartbeat(cameraId),
          queryParameters: {'stream_name': _streamName},
        );
      } catch (_) {
        // Ignored or logged; next tick will retry
      }
    });
  }

  /// Stop streaming and release pool lease on go2rtc router.
  Future<void> stopStream() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_streamName != null) {
      try {
        await _client.post(
          Endpoints.cameraLiveRelease(cameraId),
          queryParameters: {'stream_name': _streamName},
        );
      } catch (_) {}
      _streamName = null;
    }

    if (_peerConnection != null) {
      try {
        await _peerConnection!.close();
      } catch (_) {}
      _peerConnection = null;
    }

    if (_renderer != null) {
      try {
        await _renderer!.dispose();
      } catch (_) {}
      _renderer = null;
    }

    _setStatus(StreamStatus.stopped);
  }

  void dispose() {
    stopStream();
    _statusController.close();
  }
}
