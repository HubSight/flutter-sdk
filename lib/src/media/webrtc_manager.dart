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
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
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

      // Create local SDP Offer with receive-only video constraints
      final offer = await _peerConnection!.createOffer({
        'mandatory': {
          'OfferToReceiveVideo': true,
          'OfferToReceiveAudio': false,
        },
        'optional': [],
      });

      // Munge SDP to prefer H.264 hardware decoding and avoid server transcoding lag
      final mungedSdp = _preferH264(offer.sdp ?? '');
      final sessionDescription = RTCSessionDescription(mungedSdp, 'offer');
      await _peerConnection!.setLocalDescription(sessionDescription);

      // Negotiate SDP Offer with HubSight Gateway
      final response = await _client.rawDio.post(
        Endpoints.cameraLiveWebRTC(cameraId),
        data: sessionDescription.sdp,
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

  /// Rearranges the m=video line in SDP to prioritize H.264 codecs first.
  /// This ensures ZLMediaKit delivers direct passthrough from RTSP and triggers
  /// hardware-accelerated decoding (VideoToolbox / MediaCodec) without CPU transcoding.
  static String _preferH264(String sdp) {
    final lines = sdp.split('\r\n');
    final mVideoIndex = lines.indexWhere((l) => l.startsWith('m=video '));
    if (mVideoIndex == -1) return sdp;

    final h264Payloads = <String>[];
    for (final line in lines) {
      if (line.startsWith('a=rtpmap:') &&
          line.toUpperCase().contains('H264/90000')) {
        final parts = line.substring('a=rtpmap:'.length).split(' ');
        if (parts.isNotEmpty) {
          h264Payloads.add(parts[0]);
        }
      }
    }

    if (h264Payloads.isEmpty) return sdp;

    final mLineParts = lines[mVideoIndex].split(' ');
    if (mLineParts.length > 3) {
      final header = mLineParts.sublist(0, 3);
      final existingPayloads = mLineParts.sublist(3);

      final newPayloads = [
        ...h264Payloads.where((p) => existingPayloads.contains(p)),
        ...existingPayloads.where((p) => !h264Payloads.contains(p)),
      ];

      lines[mVideoIndex] = '${header.join(' ')} ${newPayloads.join(' ')}';
    }

    return lines.join('\r\n');
  }
}
