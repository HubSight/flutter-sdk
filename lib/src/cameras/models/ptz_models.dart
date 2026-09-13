/// Pan/Tilt/Zoom action types for ONVIF camera controls.
enum PTZActionType {
  continuous('continuous'),
  relative('relative'),
  stop('stop');

  final String value;
  const PTZActionType(this.value);
}

/// Request parameters for controlling camera Pan, Tilt, and Zoom.
class PTZActionInput {
  final String action;
  final double pan;
  final double tilt;
  final double zoom;

  const PTZActionInput({
    required this.action,
    this.pan = 0.0,
    this.tilt = 0.0,
    this.zoom = 0.0,
  });

  /// Factory for continuous movement (-1.0 to 1.0 velocity).
  factory PTZActionInput.continuous({
    double pan = 0.0,
    double tilt = 0.0,
    double zoom = 0.0,
  }) {
    return PTZActionInput(
      action: 'continuous',
      pan: pan,
      tilt: tilt,
      zoom: zoom,
    );
  }

  /// Factory for relative movement (-1.0 to 1.0 translation step).
  factory PTZActionInput.relative({
    double pan = 0.0,
    double tilt = 0.0,
    double zoom = 0.0,
  }) {
    return PTZActionInput(
      action: 'relative',
      pan: pan,
      tilt: tilt,
      zoom: zoom,
    );
  }

  /// Factory to stop all physical movements immediately.
  factory PTZActionInput.stop() {
    return const PTZActionInput(action: 'stop');
  }

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'pan': pan,
      'tilt': tilt,
      'zoom': zoom,
    };
  }
}

/// A physical preset position saved on the camera.
class PresetItem {
  final String token;
  final String name;

  const PresetItem({
    required this.token,
    required this.name,
  });

  factory PresetItem.fromJson(Map<String, dynamic> json) {
    return PresetItem(
      token: (json['token'] ?? json['preset_token'] ?? '') as String,
      name: (json['name'] ?? json['preset_name'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'name': name,
    };
  }
}
