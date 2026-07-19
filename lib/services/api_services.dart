import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.100.101/absen_api';

  Future<Map<String, dynamic>> login(String nik, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'nik': nik, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', data['user']['id']);
        await prefs.setString('user_nik', data['user']['nik']);
        await prefs.setString('user_name', data['user']['name']);
        await prefs.setBool('is_logged_in', true);
        return data;
      } else {
        throw Exception(data['message'] ?? 'Login gagal');
      }
    } else {
      throw Exception('Gagal terhubung ke server');
    }
  }

// cek login
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

// ambil id
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

// ambil nama
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_name');
  }

  // logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

// kirim absen
  Future<bool> submitAttendance(String type) async {
    final userId = await ApiService.getUserId();
    if (userId == null) throw Exception('User tidak login');

    final response = await http.post(
      Uri.parse('$baseUrl/absen.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'type': type}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] == true;
    } else {
      throw Exception('Gagal mengirim absen');
    }
  }

// ambil absen
  Future<List<AttendanceRecord>> getAttendanceHistory() async {
    final userId = await ApiService.getUserId();
    if (userId == null) throw Exception('User tidak login');

    final response = await http.get(
      Uri.parse('$baseUrl/history.php?user_id=$userId'),
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => AttendanceRecord.fromJson(item)).toList();
    } else {
      throw Exception('Gagal mengambil riwayat absensi');
    }
  }
}
