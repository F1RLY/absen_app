import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/api_services.dart';
import '../models/attendance.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userName = 'User';
  bool _isSubmitting = false;
  bool _isLoadingCalendar = true;

  DateTime _now = DateTime.now();
  Timer? _clockTimer;

  DateTime _focusedDay = DateTime.now();

  Map<DateTime, DailyAttendance> _attendanceMap = {};
  List<AttendanceRecord> _recentRecords = [];

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadCalendarData();
    // update jam tiap detik biar live seperti di referensi
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await ApiService.getUserName();
    if (mounted) {
      setState(() => _userName = name ?? 'User');
    }
  }

  Future<void> _loadCalendarData() async {
    setState(() => _isLoadingCalendar = true);
    try {
      final api = ApiService();
      final records = await api.getAttendanceHistory();
      final grouped = groupAttendanceByDate(records);

      final sorted = [...records]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (mounted) {
        setState(() {
          _attendanceMap = grouped;
          _recentRecords = sorted.take(3).toList();
          _isLoadingCalendar = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCalendar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DailyAttendance? get _todayAttendance => _attendanceMap[dateOnly(_now)];
  bool get _isTodayLibur => isWeekend(_now);

  String get _greeting {
    final hour = _now.hour;
    if (hour >= 4 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  ({String label, Color color}) get _statusToday {
    if (_isTodayLibur) {
      return (label: 'Hari Libur', color: Colors.grey);
    }
    final data = _todayAttendance;
    if (data != null && data.hasMasuk) {
      final telat = isLate(data.masukTime!);
      if (data.hasKeluar) {
        return telat
            ? (label: 'Absen Lengkap (Telat Masuk)', color: Colors.orange)
            : (label: 'Absen Lengkap', color: Colors.green);
      }
      return telat
          ? (label: 'Sudah Absen Masuk (Telat)', color: Colors.orange)
          : (label: 'Sudah Absen Masuk', color: Colors.blue);
    }
    return (label: 'Belum Absen', color: Colors.red);
  }

  Future<void> _doAbsen(String type) async {
    setState(() => _isSubmitting = true);
    try {
      final api = ApiService();
      final success = await api.submitAttendance(type);
      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Absen $type berhasil!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        await _loadCalendarData();
      } else {
        throw Exception('Gagal absen');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showDayDetail(DateTime day) {
    final data = _attendanceMap[dateOnly(day)];
    final status = getDayStatus(day, data);
    final timeFormat = DateFormat('HH:mm:ss', 'id_ID');
    final dateLabel = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(day);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                status == AttendanceDayStatus.libur
                    ? 'Hari Libur'
                    : status == AttendanceDayStatus.alpa
                        ? 'Tidak Hadir'
                        : status == AttendanceDayStatus.telat
                            ? 'Hadir (Telat)'
                            : status == AttendanceDayStatus.hadir
                                ? 'Hadir'
                                : 'Belum ada data',
                style: TextStyle(
                  color: _dotColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Divider(height: 24),
              _detailRow(Icons.login, Colors.green, 'Absen Masuk',
                  data?.hasMasuk == true ? timeFormat.format(data!.masukTime!) : '-'),
              const SizedBox(height: 8),
              _detailRow(Icons.logout, Colors.orange, 'Absen Keluar',
                  data?.hasKeluar == true ? timeFormat.format(data!.keluarTime!) : '-'),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Color _dotColor(AttendanceDayStatus status) {
    switch (status) {
      case AttendanceDayStatus.hadir:
        return Colors.green;
      case AttendanceDayStatus.telat:
        return Colors.orange;
      case AttendanceDayStatus.alpa:
        return Colors.red;
      case AttendanceDayStatus.libur:
        return Colors.grey;
      case AttendanceDayStatus.none:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        titleSpacing: 12,
        title: Row(
          children: [
            const Icon(Icons.fingerprint, color: Colors.blue, size: 26),
            const SizedBox(width: 8),
            const Text(
              'Attendance Pro',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR Absen',
            onPressed: _isSubmitting
                ? null
                : () => Navigator.pushNamed(context, '/scan'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isSubmitting ? null : _logout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCalendarData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildGreetingCard(),
            const SizedBox(height: 16),
            _buildRecentActivityCard(),
            const SizedBox(height: 16),
            _isLoadingCalendar
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _buildCalendarCard(),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildGreetingCard() {
    final status = _statusToday;
    final timeLabel = DateFormat('HH:mm:ss').format(_now);
    final dateLabel = DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
        .format(_now)
        .toUpperCase();

    final data = _todayAttendance;
    final canMasuk = !_isTodayLibur && data?.hasMasuk != true;
    final canKeluar =
        !_isTodayLibur && data?.hasMasuk == true && data?.hasKeluar != true;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$_greeting, $_userName!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text('Status hari ini: ', style: TextStyle(color: Colors.grey[700])),
              Text(status.label,
                  style: TextStyle(color: status.color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || !canMasuk)
                      ? null
                      : () => _doAbsen('masuk'),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Absen Masuk'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isSubmitting || !canKeluar)
                      ? null
                      : () => _doAbsen('keluar'),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Absen Keluar'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_isTodayLibur)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Hari ini libur — absen dinonaktifkan.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Aktivitas Terbaru',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/history'),
                child: const Text('Lihat Semua',
                    style: TextStyle(color: Colors.blue, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_recentRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada aktivitas.',
                  style: TextStyle(color: Colors.grey[600])),
            )
          else
            ..._recentRecords.map((r) => _activityTile(r)),
        ],
      ),
    );
  }

  Widget _activityTile(AttendanceRecord r) {
    final isMasuk = r.type == 'masuk';
    final timeLabel = DateFormat('HH:mm', 'id_ID').format(r.timestamp);
    final dateLabel = DateFormat('dd MMM', 'id_ID').format(r.timestamp).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isMasuk ? Colors.blue : Colors.orange).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isMasuk ? Icons.login : Icons.logout,
              size: 18,
              color: isMasuk ? Colors.blue : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMasuk ? 'Absen Masuk' : 'Absen Keluar',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(dateLabel,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return _card(
      child: Column(
        children: [
          TableCalendar<DailyAttendance>(
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            locale: 'id_ID',
            daysOfWeekHeight: 20,
            rowHeight: 38,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() => _focusedDay = focusedDay);
              _showDayDetail(selectedDay);
            },
            onPageChanged: (focusedDay) {
              setState(() => _focusedDay = focusedDay);
            },
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Bulan'},
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: false,
              cellMargin: EdgeInsets.all(2),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) =>
                  _dayCell(day, isToday: false),
              todayBuilder: (context, day, focusedDay) =>
                  _dayCell(day, isToday: true),
            ),
          ),
          const Divider(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              _legendItem(Colors.green, 'Hadir', filled: true),
              _legendItem(Colors.orange, 'Telat', filled: true),
              _legendItem(Colors.red, 'Alpa', filled: true),
              _legendItem(Colors.grey, 'Hari Libur', filled: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime day, {required bool isToday}) {
    final data = _attendanceMap[dateOnly(day)];
    final status = getDayStatus(day, data);
    final color = _dotColor(status);

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isToday ? Colors.blue.withOpacity(0.12) : null,
        border: isToday ? Border.all(color: Colors.blue, width: 1.2) : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              color: status == AttendanceDayStatus.libur
                  ? Colors.grey
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          if (status == AttendanceDayStatus.libur)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey, width: 1),
              ),
            )
          else if (color != Colors.transparent)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          else
            const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, {required bool filled}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? color : Colors.transparent,
            border: filled ? null : Border.all(color: color, width: 1.2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}