class AttendanceRecord {
  final int id;
  final int userId;
  final String type;
  final DateTime timestamp;

  AttendanceRecord({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? 'unknown',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
}
