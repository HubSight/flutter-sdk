import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../media/webrtc_manager.dart';

/// Native WebRTC Video Player widget with status indicators and aspect ratio support.
class HubSightWebRTCView extends StatefulWidget {
  final HubSightWebRTCManager? manager;
  final RTCVideoRenderer? renderer;
  final RTCVideoViewObjectFit objectFit;
  final bool autoStart;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  const HubSightWebRTCView({
    super.key,
    this.manager,
    this.renderer,
    this.objectFit = RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
    this.autoStart = true,
    this.loadingWidget,
    this.errorWidget,
  }) : assert(manager != null || renderer != null,
            'Either manager or renderer must be provided');

  @override
  State<HubSightWebRTCView> createState() => _HubSightWebRTCViewState();
}

class _HubSightWebRTCViewState extends State<HubSightWebRTCView> {
  RTCVideoRenderer? _renderer;
  StreamStatus _status = StreamStatus.idle;

  @override
  void initState() {
    super.initState();
    if (widget.renderer != null) {
      _renderer = widget.renderer;
      _status = StreamStatus.connected;
    } else if (widget.manager != null) {
      _status = widget.manager!.status;
      widget.manager!.onStatusChanged.listen((s) {
        if (mounted) setState(() => _status = s);
      });
      if (widget.autoStart) {
        _startStream();
      }
    }
  }

  Future<void> _startStream() async {
    if (widget.manager == null) return;
    try {
      final r = await widget.manager!.startStream();
      if (mounted) {
        setState(() {
          _renderer = r;
          _status = StreamStatus.connected;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = StreamStatus.failed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == StreamStatus.connecting) {
      return widget.loadingWidget ??
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          );
    }

    if (_status == StreamStatus.failed) {
      return widget.errorWidget ??
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 36),
                  const SizedBox(height: 8),
                  const Text('Lỗi kết nối WebRTC',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _startStream,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
    }

    if (_renderer != null && _renderer!.srcObject != null) {
      return Container(
        color: Colors.black,
        child: RepaintBoundary(
          child: RTCVideoView(
            _renderer!,
            objectFit: widget.objectFit,
            filterQuality: FilterQuality.low,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: const Center(
        child: Text('Đang đợi luồng video...',
            style: TextStyle(color: Colors.white54)),
      ),
    );
  }
}
