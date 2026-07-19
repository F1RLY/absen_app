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

/// Menampung absen masuk & keluar untuk satu tanggal tertentu.
class DailyAttendance {
  final DateTime date;
  final DateTime? masukTime;
  final DateTime? keluarTime;

  DailyAttendance({required this.date, this.masukTime, this.keluarTime});

  bool get hasMasuk => masukTime != null;
  bool get hasKeluar => keluarTime != null;
  bool get isEmpty => !hasMasuk && !hasKeluar;
}

/// Normalisasi DateTime jadi key tanpa jam/menit/detik, dipakai sebagai
/// key di Map dan untuk dicocokkan dengan tanggal yang dipilih di kalender.
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Status kehadiran untuk satu tanggal, dipakai untuk marker kalender.
enum AttendanceDayStatus { hadir, alpa, libur, none }

/// Weekend = Sabtu & Minggu dianggap hari libur (belum termasuk
/// tanggal merah nasional — bisa ditambahkan nanti kalau perlu).
bool isWeekend(DateTime day) =>
    day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

/// Menentukan status suatu tanggal:
/// - libur   : jatuh di akhir pekan
/// - hadir   : ada record absen masuk
/// - alpa    : sudah lewat (sebelum hari ini), hari kerja, tidak ada absen
/// - none    : hari ini/masa depan yang belum ada absen (netral, bukan alpa)
AttendanceDayStatus getDayStatus(DateTime day, DailyAttendance? data) {
  final target = dateOnly(day);
  final today = dateOnly(DateTime.now());

  if (isWeekend(target)) return AttendanceDayStatus.libur;
  if (data != null && data.hasMasuk) return AttendanceDayStatus.hadir;
  if (target.isBefore(today)) return AttendanceDayStatus.alpa;
  return AttendanceDayStatus.none;
}

/// Mengelompokkan list record (yang formatnya flat: satu baris per absen)
/// menjadi Map<tanggal, DailyAttendance> supaya gampang ditampilkan
/// di kalender (1 tanggal = 1 entri berisi masuk & keluar).
Map<DateTime, DailyAttendance> groupAttendanceByDate(
  List<AttendanceRecord> records,
) {
  final Map<DateTime, DailyAttendance> grouped = {};

  for (final record in records) {
    final key = dateOnly(record.timestamp);
    final existing = grouped[key];

    if (record.type == 'masuk') {
      grouped[key] = DailyAttendance(
        date: key,
        masukTime: record.timestamp,
        keluarTime: existing?.keluarTime,
      );
    } else if (record.type == 'keluar') {
      grouped[key] = DailyAttendance(
        date: key,
        masukTime: existing?.masukTime,
        keluarTime: record.timestamp,
      );
    }
  }

  return grouped;
}
