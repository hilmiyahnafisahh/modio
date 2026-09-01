import 'dart:convert'; // Encode/decode JSON
import 'package:http/http.dart' as http; // Klien HTTP untuk request ke server
import '../constants/api_constants.dart'; // Konstanta URL dasar & timeout API

/// ─────────────────────────────────────────────────────────────────
/// API SERVICE  –  Client HTTP dasar untuk semua request ke server
///
/// Menyediakan method GET, POST, PUT, DELETE dengan:
///   • Header Authorization otomatis
///   • Penanganan error terpusat
///   • Timeout sesuai ApiConstants
///
/// Cara pakai:
///   final service = ApiService();
///   final data = await service.get(ApiConstants.transactions);
/// ─────────────────────────────────────────────────────────────────

class ApiService {
  // Inisialisasi HTTP client dengan timeout
  final http.Client _client; // Klien HTTP yang dipakai untuk semua request

  ApiService({http.Client? client}) : _client = client ?? http.Client(); // Bisa disuntik untuk pengujian, atau buat baru

  // Header default untuk setiap request
  Map<String, String> get _headers => {
    'Content-Type': 'application/json', // Beri tahu server body berformat JSON
    'Accept': 'application/json', // Minta respons berformat JSON
    // TODO: Tambahkan token autentikasi setelah fitur login dibuat
    // 'Authorization': 'Bearer $token',
  };

  // ── GET ──────────────────────────────────────────────────────────
  /// Mengambil data dari server
  Future<Map<String, dynamic>> get(String endpoint) async {
    final uri = Uri.parse(ApiConstants.baseUrl + endpoint); // Gabungkan URL dasar dengan endpoint tujuan

    try {
      final response = await _client
          .get(uri, headers: _headers) // Kirim request GET
          .timeout(
            const Duration(seconds: ApiConstants.connectTimeoutSeconds), // Batasi waktu tunggu respons
          );

      return _handleResponse(response); // Urai dan validasi hasil respons
    } catch (e) {
      throw ApiException('GET $endpoint gagal: $e'); // Bungkus error asli jadi ApiException
    }
  }

  // ── POST ─────────────────────────────────────────────────────────
  /// Mengirim data baru ke server
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final uri = Uri.parse(ApiConstants.baseUrl + endpoint);

    try {
      final response = await _client
          .post(uri, headers: _headers, body: jsonEncode(body)) // Kirim request POST dengan body JSON
          .timeout(
            const Duration(seconds: ApiConstants.connectTimeoutSeconds),
          );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('POST $endpoint gagal: $e');
    }
  }

  // ── Penanganan Response ───────────────────────────────────────────
  /// Mengecek status code dan mengurai JSON response
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) { // Rentang kode 2xx berarti sukses
      // Sukses: urai JSON
      return jsonDecode(response.body) as Map<String, dynamic>; // Ubah teks JSON jadi Map Dart
    } else {
      // Error: lempar exception dengan pesan dari server
      throw ApiException(
        'Server error ${response.statusCode}: ${response.body}', // Sertakan kode status & isi respons
      );
    }
  }

  // Tutup koneksi saat tidak dipakai lagi
  void dispose() => _client.close(); // Bebaskan resource klien HTTP
}

/// Exception khusus untuk error API
class ApiException implements Exception {
  final String message; // Pesan penjelas error
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message'; // Format teks saat exception dicetak/di-log
}
