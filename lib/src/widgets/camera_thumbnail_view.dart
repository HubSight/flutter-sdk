import 'dart:async';
import 'package:flutter/material.dart';

/// Highly optimized camera snapshot widget with automatic polling and gapless playback.
class HubSightCameraThumbnail extends StatefulWidget {
  final String gatewayUrl;
  final String thumbnailUrl; // e.g. "/api/app/v1/cameras/cam_01/thumbnail"
  final String apiKey;
  final String token;
  final bool isStopped;
  final Duration refreshInterval;
  final BoxFit fit;
  final Widget? stoppedPlaceholder;
  final Widget? errorPlaceholder;

  const HubSightCameraThumbnail({
    super.key,
    required this.gatewayUrl,
    required this.thumbnailUrl,
    required this.apiKey,
    required this.token,
    this.isStopped = false,
    this.refreshInterval = const Duration(seconds: 4),
    this.fit = BoxFit.cover,
    this.stoppedPlaceholder,
    this.errorPlaceholder,
  });

  @override
  State<HubSightCameraThumbnail> createState() => _HubSightCameraThumbnailState();
}

class _HubSightCameraThumbnailState extends State<HubSightCameraThumbnail> {
  Timer? _timer;
  int _timestamp = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant HubSightCameraThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStopped != oldWidget.isStopped ||
        widget.refreshInterval != oldWidget.refreshInterval) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    if (widget.isStopped) return;
    _timer = Timer.periodic(widget.refreshInterval, (_) {
      if (mounted) {
        setState(() {
          _timestamp = DateTime.now().millisecondsSinceEpoch;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isStopped) {
      return widget.stoppedPlaceholder ??
          Container(
            color: Colors.black87,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined, color: Colors.grey, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'Camera tạm dừng',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
    }

    final fullUrl = '${widget.gatewayUrl}${widget.thumbnailUrl}'
        '?api_key=${widget.apiKey}&token=${widget.token}&_t=$_timestamp';

    return Image.network(
      fullUrl,
      fit: widget.fit,
      gaplessPlayback: true, // Prevents black flickering between frames
      errorBuilder: (context, error, stackTrace) {
        return widget.errorPlaceholder ??
            Container(
              color: Colors.black54,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white30, size: 32),
              ),
            );
      },
    );
  }
}
