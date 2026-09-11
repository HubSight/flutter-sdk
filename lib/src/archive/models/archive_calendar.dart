/// HubSight NVR Archive calendar with days containing video recordings.
class ArchiveCalendar {
  final String cameraId;
  final int year;
  final int month;
  final List<String> availableDays;

  const ArchiveCalendar({
    required this.cameraId,
    required this.year,
    required this.month,
    required this.availableDays,
  });

  factory ArchiveCalendar.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['available_days'] ?? json['days'];
    List<String> days = [];
    if (daysRaw is List) {
      days = daysRaw.map((e) => e.toString()).toList();
    }

    return ArchiveCalendar(
      cameraId: json['camera_id'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      month: json['month'] as int? ?? 0,
      availableDays: days,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camera_id': cameraId,
      'year': year,
      'month': month,
      'available_days': availableDays,
    };
  }
}
