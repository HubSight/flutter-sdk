import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../media/multi_view_session.dart';
import 'webrtc_video_view.dart';

/// Ready-to-use grid widget rendering multiple cameras simultaneously using batch WebRTC.
class HubSightMultiViewGrid extends StatefulWidget {
  final MultiViewStreamSession session;
  final List<String> cameraIds;
  final int crossAxisCount;
  final double aspectRatio;

  const HubSightMultiViewGrid({
    super.key,
    required this.session,
    required this.cameraIds,
    this.crossAxisCount = 2,
    this.aspectRatio = 16 / 9,
  });

  @override
  State<HubSightMultiViewGrid> createState() => _HubSightMultiViewGridState();
}

class _HubSightMultiViewGridState extends State<HubSightMultiViewGrid> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.session.startStreams(widget.cameraIds);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    widget.session.stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 8),
            Text(
              'Lỗi kết nối multi-view: $_error',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _initSession,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      itemCount: widget.cameraIds.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        childAspectRatio: widget.aspectRatio,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemBuilder: (context, index) {
        final camId = widget.cameraIds[index];
        final renderer = widget.session.getRenderer(camId);

        if (renderer == null) {
          return Container(
            color: Colors.black87,
            child: const Center(
              child:
                  Text('Đang tải...', style: TextStyle(color: Colors.white54)),
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: HubSightWebRTCView(
                renderer: renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  camId,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
