import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_services.dart';
import '../models/attendance.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AttendanceRecord> _histories = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final api = ApiService();
      final data = await api.getAttendanceHistory();
      if (mounted) {
        setState(() {
          _histories = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 60, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal memuat data',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loadHistory,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
            : _histories.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada riwayat absen',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _histories.length,
                itemBuilder: (ctx, index) {
                  final record = _histories[index];
                  final isMasuk = record.type == 'masuk';
                  final formattedDate = DateFormat(
                    'dd MMM yyyy, HH:mm:ss',
                    'id_ID', // <-- locale Indonesia
                  ).format(record.timestamp);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isMasuk ? Colors.green : Colors.orange,
                        child: Icon(
                          isMasuk ? Icons.login : Icons.logout,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        isMasuk ? 'Absen Masuk' : 'Absen Keluar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMasuk
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                      ),
                      subtitle: Text(formattedDate),
                      trailing: Icon(
                        isMasuk ? Icons.arrow_upward : Icons.arrow_downward,
                        color: isMasuk ? Colors.green : Colors.orange,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
