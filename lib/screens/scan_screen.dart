import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_services.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isScanning = true;
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isProcessing) return;

    final String? qrData = capture.barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) return;

    setState(() {
      _isScanning = false;
      _isProcessing = true;
    });

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Jenis Absen'),
        content: Text('QR terdeteksi: "$qrData"\n\nPilih jenis absen:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'masuk'),
            child: const Text('MASUK', style: TextStyle(color: Colors.green)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keluar'),
            child: const Text('KELUAR', style: TextStyle(color: Colors.orange)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result != null) {
      final type = result;
      try {
        final api = ApiService();
        final response = await api.submitAttendance(type);

        if (!mounted) return;

        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Absen $type berhasil via QR!'),
              backgroundColor: Colors.green,
            )
          );
        } else {
          throw Exception(response['message'] ?? 'Gagal absen');
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Kamera QR Scanner
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Overlay kotak scan
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 100),
          ),
          // Tulisan instruksi
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _isProcessing ? 'Memproses...' : 'Arahkan kamera ke QR Code',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
