import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../cameras/camera_service.dart';
import '../cameras/models/ptz_models.dart';
import '../network/api_client.dart';
import '../network/endpoints.dart';

/// Touch-sensitive PTZ D-Pad Controller Widget for HubSight CCTV cameras.
///
/// Supports 8-way continuous pan/tilt movement, center immediate stop,
/// continuous zoom in/out, and optional preset navigation.
class HubSightPtzPad extends StatelessWidget {
  /// Unique identifier of the camera being controlled.
  final String cameraId;

  /// Optional SDK camera service to execute PTZ actions.
  final HubSightCameraService? cameraService;

  /// Optional API client to execute PTZ actions.
  final HubSightApiClient? client;

  /// Optional Dio instance for raw HTTP PTZ commands.
  final Dio? dio;

  /// Optional gateway URL used when [dio] is provided.
  final String? gatewayUrl;

  /// Custom PTZ action callback for testing or custom transport.
  final Future<void> Function({
    required String action,
    double pan,
    double tilt,
    double zoom,
  })? onAction;

  /// Error callback triggered when a command fails.
  final void Function(Object error)? onError;

  /// Saved preset positions to show in the controller.
  final List<PresetItem>? presets;

  /// Callback when a preset chip is tapped.
  final ValueChanged<PresetItem>? onPresetSelected;

  /// Speed for horizontal and vertical cardinal moves (-1.0 to 1.0).
  final double cardinalSpeed;

  /// Speed for diagonal moves (-1.0 to 1.0).
  final double diagonalSpeed;

  /// Speed for zoom actions.
  final double zoomSpeed;

  /// Controller background color.
  final Color? backgroundColor;

  /// Background color of direction buttons.
  final Color? buttonColor;

  /// Border color of direction buttons.
  final Color? buttonBorderColor;

  /// Icon color of direction buttons.
  final Color? iconColor;

  /// Background color of the center stop button.
  final Color? stopButtonColor;

  /// Icon color of the center stop button.
  final Color? stopIconColor;

  /// Direction button size (width and height).
  final double buttonSize;

  /// Direction icon size.
  final double iconSize;

  /// Gap spacing between buttons.
  final double spacing;

  /// Outer padding of the pad container.
  final EdgeInsetsGeometry padding;

  /// Border radius of the pad container.
  final double borderRadius;

  const HubSightPtzPad({
    super.key,
    required this.cameraId,
    this.cameraService,
    this.client,
    this.dio,
    this.gatewayUrl,
    this.onAction,
    this.onError,
    this.presets,
    this.onPresetSelected,
    this.cardinalSpeed = 0.7,
    this.diagonalSpeed = 0.5,
    this.zoomSpeed = 0.5,
    this.backgroundColor,
    this.buttonColor,
    this.buttonBorderColor,
    this.iconColor,
    this.stopButtonColor,
    this.stopIconColor,
    this.buttonSize = 46.0,
    this.iconSize = 24.0,
    this.spacing = 8.0,
    this.padding = const EdgeInsets.all(12.0),
    this.borderRadius = 20.0,
  });

  Future<void> _sendPtzAction({
    required String action,
    double pan = 0.0,
    double tilt = 0.0,
    double zoom = 0.0,
  }) async {
    try {
      if (onAction != null) {
        await onAction!(action: action, pan: pan, tilt: tilt, zoom: zoom);
      } else if (cameraService != null) {
        if (action == 'stop') {
          await cameraService!.stopPtz(cameraId);
        } else {
          await cameraService!.ptz(
            cameraId,
            action: action,
            pan: pan,
            tilt: tilt,
            zoom: zoom,
          );
        }
      } else if (client != null) {
        await client!.post(
          Endpoints.cameraPTZ(cameraId),
          data: {
            'action': action,
            'pan': pan,
            'tilt': tilt,
            'zoom': zoom,
            'timeout': 5,
          },
        );
      } else if (dio != null && gatewayUrl != null) {
        final cleanGateway = gatewayUrl!.endsWith('/')
            ? gatewayUrl!.substring(0, gatewayUrl!.length - 1)
            : gatewayUrl!;
        await dio!.post(
          '$cleanGateway/api/app/v1/cameras/$cameraId/ptz',
          data: {
            'action': action,
            'pan': pan,
            'tilt': tilt,
            'zoom': zoom,
            'timeout': 5,
          },
        );
      }
    } catch (e) {
      if (onError != null) {
        onError!(e);
      } else {
        debugPrint('PTZ command error: $e');
      }
    }
  }

  Widget _buildDirectionBtn({
    required IconData icon,
    required double pan,
    required double tilt,
  }) {
    final effectiveBtnColor =
        buttonColor ?? const Color.fromRGBO(255, 255, 255, 0.12);
    final effectiveBorderColor = buttonBorderColor ?? Colors.white24;
    final effectiveIconColor = iconColor ?? Colors.white;

    return GestureDetector(
      onTapDown: (_) =>
          _sendPtzAction(action: 'continuous', pan: pan, tilt: tilt),
      onTapUp: (_) => _sendPtzAction(action: 'stop'),
      onTapCancel: () => _sendPtzAction(action: 'stop'),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: effectiveBtnColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: effectiveBorderColor),
        ),
        child: Icon(icon, color: effectiveIconColor, size: iconSize),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBgColor =
        backgroundColor ?? const Color.fromRGBO(0, 0, 0, 0.85);
    final effectiveStopBtnColor =
        stopButtonColor ?? const Color.fromRGBO(255, 82, 82, 0.25);
    final effectiveStopIconColor = stopIconColor ?? Colors.redAccent;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: North-West, Up, North-East
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirectionBtn(
                icon: Icons.north_west,
                pan: -diagonalSpeed,
                tilt: diagonalSpeed,
              ),
              SizedBox(width: spacing),
              _buildDirectionBtn(
                icon: Icons.keyboard_arrow_up,
                pan: 0.0,
                tilt: cardinalSpeed,
              ),
              SizedBox(width: spacing),
              _buildDirectionBtn(
                icon: Icons.north_east,
                pan: diagonalSpeed,
                tilt: diagonalSpeed,
              ),
            ],
          ),
          SizedBox(height: spacing),

          // Row 2: Left, Stop, Right
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirectionBtn(
                icon: Icons.keyboard_arrow_left,
                pan: -cardinalSpeed,
                tilt: 0.0,
              ),
              SizedBox(width: spacing),
              GestureDetector(
                onTap: () => _sendPtzAction(action: 'stop'),
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: effectiveStopBtnColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.stop,
                    color: effectiveStopIconColor,
                    size: iconSize * 0.85,
                  ),
                ),
              ),
              SizedBox(width: spacing),
              _buildDirectionBtn(
                icon: Icons.keyboard_arrow_right,
                pan: cardinalSpeed,
                tilt: 0.0,
              ),
            ],
          ),
          SizedBox(height: spacing),

          // Row 3: South-West, Down, South-East
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirectionBtn(
                icon: Icons.south_west,
                pan: -diagonalSpeed,
                tilt: -diagonalSpeed,
              ),
              SizedBox(width: spacing),
              _buildDirectionBtn(
                icon: Icons.keyboard_arrow_down,
                pan: 0.0,
                tilt: -cardinalSpeed,
              ),
              SizedBox(width: spacing),
              _buildDirectionBtn(
                icon: Icons.south_east,
                pan: diagonalSpeed,
                tilt: -diagonalSpeed,
              ),
            ],
          ),
          SizedBox(height: spacing * 1.5),

          // Zoom In / Out
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTapDown: (_) =>
                    _sendPtzAction(action: 'zoom_in', zoom: zoomSpeed),
                onTapUp: (_) => _sendPtzAction(action: 'stop'),
                onTapCancel: () => _sendPtzAction(action: 'stop'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Zoom +',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: spacing),
              GestureDetector(
                onTapDown: (_) =>
                    _sendPtzAction(action: 'zoom_out', zoom: -zoomSpeed),
                onTapUp: (_) => _sendPtzAction(action: 'stop'),
                onTapCancel: () => _sendPtzAction(action: 'stop'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.zoom_out, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Zoom -',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Optional Presets selector
          if (presets != null && presets!.isNotEmpty) ...[
            SizedBox(height: spacing * 1.5),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: presets!.map((preset) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: ActionChip(
                      label: Text(
                        preset.name,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: Colors.white12,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      onPressed: () {
                        if (onPresetSelected != null) {
                          onPresetSelected!(preset);
                        } else if (cameraService != null) {
                          cameraService!
                              .gotoPreset(cameraId, preset.token)
                              .catchError((e) {
                            if (onError != null) {
                              onError!(e);
                            } else {
                              debugPrint('Preset goto error: $e');
                            }
                          });
                        } else if (client != null) {
                          client!.post(
                            Endpoints.cameraPresets(cameraId),
                            data: {
                              'action': 'goto',
                              'preset_token': preset.token,
                            },
                          ).catchError((e) {
                            if (onError != null) {
                              onError!(e);
                            } else {
                              debugPrint('Preset goto error: $e');
                            }
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
