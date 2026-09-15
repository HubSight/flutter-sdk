/// Single stream request item within a Multi-View batch WebRTC negotiation.
class BatchWebRTCItem {
  final String cameraId;
  final String sdpOffer;

  const BatchWebRTCItem({
    required this.cameraId,
    required this.sdpOffer,
  });

  factory BatchWebRTCItem.fromJson(Map<String, dynamic> json) {
    final offer = (json['sdp_offer'] ?? json['offer']) as String? ?? '';
    return BatchWebRTCItem(
      cameraId: json['camera_id'] as String? ?? '',
      sdpOffer: offer,
    );
  }

  Map<String, dynamic> toJson() => {
        'camera_id': cameraId,
        'sdp_offer': sdpOffer,
        'offer': sdpOffer,
      };
}

/// Result item returned by the gateway for a single camera in a batch WebRTC request.
class BatchWebRTCResultItem {
  final String cameraId;
  final String? sdpAnswer;
  final String? poolStreamName;
  final String? poolConnIndex;
  final String? error;

  const BatchWebRTCResultItem({
    required this.cameraId,
    this.sdpAnswer,
    this.poolStreamName,
    this.poolConnIndex,
    this.error,
  });

  bool get isSuccess => (error == null || error!.isEmpty) && sdpAnswer != null;

  factory BatchWebRTCResultItem.fromJson(Map<String, dynamic> json) {
    return BatchWebRTCResultItem(
      cameraId: json['camera_id'] as String? ?? '',
      sdpAnswer: json['sdp_answer'] as String?,
      poolStreamName: json['pool_stream_name'] as String?,
      poolConnIndex: json['pool_conn_index']?.toString(),
      error: json['error'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'camera_id': cameraId,
        if (sdpAnswer != null) 'sdp_answer': sdpAnswer,
        if (poolStreamName != null) 'pool_stream_name': poolStreamName,
        if (poolConnIndex != null) 'pool_conn_index': poolConnIndex,
        if (error != null) 'error': error,
      };
}

/// Active camera lease specification for batch heartbeat and release requests.
class BatchHeartbeatItem {
  final String cameraId;
  final String streamName;

  const BatchHeartbeatItem({
    required this.cameraId,
    required this.streamName,
  });

  factory BatchHeartbeatItem.fromJson(Map<String, dynamic> json) {
    return BatchHeartbeatItem(
      cameraId: json['camera_id'] as String? ?? '',
      streamName: json['stream_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'camera_id': cameraId,
        'stream_name': streamName,
      };
}

/// Response returned by the batch heartbeat endpoint.
class BatchHeartbeatResponse {
  final String status;
  final int renewed;

  const BatchHeartbeatResponse({
    required this.status,
    required this.renewed,
  });

  factory BatchHeartbeatResponse.fromJson(Map<String, dynamic> json) {
    return BatchHeartbeatResponse(
      status: json['status'] as String? ?? 'ok',
      renewed: (json['renewed'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'renewed': renewed,
      };
}

/// Response returned by the batch release endpoint.
class BatchReleaseResponse {
  final String status;
  final int released;

  const BatchReleaseResponse({
    required this.status,
    required this.released,
  });

  factory BatchReleaseResponse.fromJson(Map<String, dynamic> json) {
    return BatchReleaseResponse(
      status: json['status'] as String? ?? 'ok',
      released: (json['released'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'released': released,
      };
}
