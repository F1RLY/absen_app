import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/api_services.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String type; 

  const FaceVerificationScreen({super.key, required this.type});

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _isProcessing = false;
  String? _errorMessage;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.fast),
  );

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final photo = await _controller!.takePicture();
      final faces = await _faceDetector.processImage(
        InputImage.fromFilePath(photo.path),
      );

      if (faces.isEmpty) {
        setState(() {
          _errorMessage =
              'Wajah tidak terdeteksi. Posisikan wajah di dalam bingkai lalu coba lagi.';
          _isProcessing = false;
        });
        return;
      }

      if (faces.length > 1) {
        setState(() {
          _errorMessage =
              'Terdeteksi lebih dari satu wajah. Pastikan hanya Anda di depan kamera.';
          _isProcessing = false;
        });
        return;
      }

      final api = ApiService();
      final result = await api.submitAttendance(widget.type, File(photo.path));

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal mengirim absen';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.type == 'masuk' ? 'Absen Masuk' : 'Absen Keluar';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Verifikasi Wajah - $label'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError || _controller == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Gagal mengakses kamera: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_controller!),
              Center(
                child: Container(
                  width: 240,
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _errorMessage != null ? Colors.red : Colors.white,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(150),
                  ),
                ),
              ),
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Column(
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    else
                      const Text(
                        'Posisikan wajah Anda di dalam bingkai',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _captureAndVerify,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.camera_alt),
                        label: Text(
                          _isProcessing
                              ? 'Memverifikasi...'
                              : 'Ambil Foto & $label',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
