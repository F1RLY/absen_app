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
  List<AttendanceRecord> _allHistories = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // --- Filter state ---
  String _typeFilter = 'semua'; // semua | masuk | keluar
  int? _filterMonth; // null = semua bulan
  int? _filterYear; // null = semua tahun

  static const _monthNames = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

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
          _allHistories = data;
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

  List<int> get _availableYears {
    final years = _allHistories.map((r) => r.timestamp.year).toSet().toList();
    if (years.isEmpty) years.add(DateTime.now().year);
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<AttendanceRecord> get _filteredHistories {
    return _allHistories.where((r) {
      if (_typeFilter != 'semua' && r.type != _typeFilter) return false;
      if (_filterMonth != null && r.timestamp.month != _filterMonth)
        return false;
      if (_filterYear != null && r.timestamp.year != _filterYear) return false;
      return true;
    }).toList();
  }

  /// Mengelompokkan record terfilter menjadi Map<tanggal, records>,
  /// urut tanggal terbaru dulu, dan di dalam tanggal urut waktu naik
  /// (masuk lalu keluar).
  Map<DateTime, List<AttendanceRecord>> get _groupedHistories {
    final Map<DateTime, List<AttendanceRecord>> grouped = {};
    for (final r in _filteredHistories) {
      final key = dateOnly(r.timestamp);
      grouped.putIfAbsent(key, () => []).add(r);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return grouped;
  }

  bool get _hasActiveFilter =>
      _typeFilter != 'semua' || _filterMonth != null || _filterYear != null;

  void _resetFilters() {
    setState(() {
      _typeFilter = 'semua';
      _filterMonth = null;
      _filterYear = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupedEntries = _groupedHistories.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadHistory),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage.isNotEmpty
                  ? _buildErrorState()
                  : groupedEntries.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                      itemCount: groupedEntries.length,
                      itemBuilder: (ctx, index) {
                        final entry = groupedEntries[index];
                        return _buildDateSection(entry.key, entry.value);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter jenis absen
          Row(
            children: [
              _typeChip('semua', 'Semua'),
              const SizedBox(width: 8),
              _typeChip('masuk', 'Masuk'),
              const SizedBox(width: 8),
              _typeChip('keluar', 'Keluar'),
            ],
          ),
          const SizedBox(height: 10),
          // Filter bulan & tahun
          Row(
            children: [
              Expanded(child: _monthDropdown()),
              const SizedBox(width: 8),
              Expanded(child: _yearDropdown()),
              if (_hasActiveFilter) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Reset filter',
                  icon: const Icon(Icons.filter_alt_off, size: 20),
                  onPressed: _resetFilters,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String value, String label) {
    final selected = _typeFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => setState(() => _typeFilter = value),
      selectedColor: Colors.blue,
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _dropdownContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }

  Widget _monthDropdown() {
    return _dropdownContainer(
      DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _filterMonth,
          isDense: true,
          isExpanded: true,
          hint: const Text('Semua Bulan', style: TextStyle(fontSize: 13)),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Semua Bulan', style: TextStyle(fontSize: 13)),
            ),
            ...List.generate(12, (i) => i + 1).map(
              (m) => DropdownMenuItem<int?>(
                value: m,
                child: Text(
                  _monthNames[m - 1],
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _filterMonth = value),
        ),
      ),
    );
  }

  Widget _yearDropdown() {
    return _dropdownContainer(
      DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: _filterYear,
          isDense: true,
          isExpanded: true,
          hint: const Text('Semua Tahun', style: TextStyle(fontSize: 13)),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Semua Tahun', style: TextStyle(fontSize: 13)),
            ),
            ..._availableYears.map(
              (y) => DropdownMenuItem<int?>(
                value: y,
                child: Text('$y', style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: (value) => setState(() => _filterYear = value),
        ),
      ),
    );
  }

  Widget _buildDateSection(DateTime date, List<AttendanceRecord> records) {
    final headerLabel = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              headerLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: List.generate(records.length, (i) {
                final r = records[i];
                return Column(
                  children: [
                    _recordTile(r),
                    if (i != records.length - 1)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey.shade200,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordTile(AttendanceRecord r) {
    final isMasuk = r.type == 'masuk';
    final timeLabel = DateFormat('HH:mm:ss', 'id_ID').format(r.timestamp);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isMasuk ? Colors.green : Colors.orange,
        child: Icon(
          isMasuk ? Icons.login : Icons.logout,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        isMasuk ? 'Absen Masuk' : 'Absen Keluar',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isMasuk ? Colors.green[800] : Colors.orange[800],
        ),
      ),
      subtitle: Text(timeLabel),
      trailing: Icon(
        isMasuk ? Icons.arrow_upward : Icons.arrow_downward,
        color: isMasuk ? Colors.green : Colors.orange,
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.error, size: 60, color: Colors.red, semanticLabel: 'error'),
        const SizedBox(height: 16),
        const Center(
          child: Text('Gagal memuat data', style: TextStyle(fontSize: 18)),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton(
            onPressed: _loadHistory,
            child: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Icon(Icons.history, size: 60, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _hasActiveFilter
                ? 'Tidak ada data untuk filter ini'
                : 'Belum ada riwayat absen',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ),
        if (_hasActiveFilter) ...[
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _resetFilters,
              child: const Text('Reset Filter'),
            ),
          ),
        ],
      ],
    );
  }
}
