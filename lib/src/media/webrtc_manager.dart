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
        'iceTransportPolicy': 'all',
        'tcpCandidatePolicy': 'enabled',
      };

      _peerConnection = await createPeerConnection(rtcConfig);

      _peerConnection!.onTrack = (RTCTrackEvent event) async {
        if (event.track.kind == 'video') {
          if (event.streams.isNotEmpty) {
            _renderer!.srcObject = event.streams[0];
          } else {
            _renderer!.srcObject ??=
                await createLocalMediaStream('hubsight_stream');
            _renderer!.srcObject!.addTrack(event.track);
          }
          _setStatus(StreamStatus.connected);
        }
      };

      _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
          _setStatus(StreamStatus.connected);
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          _setStatus(StreamStatus.failed);
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

      // Munge SDP to prefer H.264 hardware decoding, add bandwidth, and enable RTCP feedback
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

  /// Query real-time WebRTC receiver statistics (packet loss, fps, jitter, bitrate).
  Future<List<StatsReport>?> getStats() async {
    return _peerConnection?.getStats();
  }

  /// Enhances the SDP Offer:
  /// 1. Prioritizes H.264 codecs so ZLMediaKit delivers direct RTSP passthrough.
  /// 2. Injects high bandwidth allocation (b=AS:4000) so ZLMediaKit never throttles or drops frames.
  /// 3. Injects RTCP feedback (NACK, PLI, FIR, REMB) for H.264 payload types to recover dropped packets and request keyframes immediately on loss.
  static String _preferH264(String sdp) {
    final delimiter = sdp.contains('\r\n') ? '\r\n' : '\n';
    final lines = sdp.split(delimiter);
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

    if (h264Payloads.isNotEmpty) {
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
    }

    final enhancedLines = <String>[];
    for (int i = 0; i < lines.length; i++) {
      enhancedLines.add(lines[i]);
      if (i == mVideoIndex) {
        // Allocate 4000 kbps (4 Mbps) to ensure crystal-clear 720p/1080p 25-30fps stream
        enhancedLines.add('b=AS:4000');
        enhancedLines.add('b=TIAS:4000000');
      }
    }

    // Ensure RTCP feedback is enabled for every H264 payload
    for (final pt in h264Payloads) {
      final nack = 'a=rtcp-fb:$pt nack';
      final pli = 'a=rtcp-fb:$pt nack pli';
      final fir = 'a=rtcp-fb:$pt ccm fir';
      final remb = 'a=rtcp-fb:$pt goog-remb';

      if (!enhancedLines.contains(nack)) enhancedLines.add(nack);
      if (!enhancedLines.contains(pli)) enhancedLines.add(pli);
      if (!enhancedLines.contains(fir)) enhancedLines.add(fir);
      if (!enhancedLines.contains(remb)) enhancedLines.add(remb);
    }

    return enhancedLines.join(delimiter);
  }
}
