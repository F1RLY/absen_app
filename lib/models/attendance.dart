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

class DailyAttendance {
  final DateTime date;
  final DateTime? masukTime;
  final DateTime? keluarTime;

  DailyAttendance({required this.date, this.masukTime, this.keluarTime});

  bool get hasMasuk => masukTime != null;
  bool get hasKeluar => keluarTime != null;
  bool get isEmpty => !hasMasuk && !hasKeluar;
}

DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

enum AttendanceDayStatus { hadir, telat, alpa, libur, none }

bool isWeekend(DateTime day) =>
    day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

const int lateThresholdHour = 8;
const int lateThresholdMinute = 0;

bool isLate(DateTime masukTime) {
  final threshold = DateTime(
    masukTime.year,
    masukTime.month,
    masukTime.day,
    lateThresholdHour,
    lateThresholdMinute,
  );
  return masukTime.isAfter(threshold);
}

AttendanceDayStatus getDayStatus(DateTime day, DailyAttendance? data) {
  final target = dateOnly(day);
  final today = dateOnly(DateTime.now());

  if (isWeekend(target)) return AttendanceDayStatus.libur;
  if (data != null && data.hasMasuk) {
    return isLate(data.masukTime!)
        ? AttendanceDayStatus.telat
        : AttendanceDayStatus.hadir;
  }
  if (target.isBefore(today)) return AttendanceDayStatus.alpa;
  return AttendanceDayStatus.none;
}

Map<DateTime, DailyAttendance> groupAttendanceByDate(
  List<AttendanceRecord> records,
) {
  final Map<DateTime, DailyAttendance> grouped = {};

  for (final record in records) {
    final key = dateOnly(record.timestamp);
    final existing = grouped[key];

    if (record.type == 'masuk') {
      final earliest =
          (existing?.masukTime == null ||
              record.timestamp.isBefore(existing!.masukTime!))
          ? record.timestamp
          : existing.masukTime;
      grouped[key] = DailyAttendance(
        date: key,
        masukTime: earliest,
        keluarTime: existing?.keluarTime,
      );
    } else if (record.type == 'keluar') {
      final latest =
          (existing?.keluarTime == null ||
              record.timestamp.isAfter(existing!.keluarTime!))
          ? record.timestamp
          : existing.keluarTime;
      grouped[key] = DailyAttendance(
        date: key,
        masukTime: existing?.masukTime,
        keluarTime: latest,
      );
    }
  }

  return grouped;
}
