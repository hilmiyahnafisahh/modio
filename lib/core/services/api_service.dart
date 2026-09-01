import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

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
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // Header default untuk setiap request
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    // TODO: Tambahkan token autentikasi setelah fitur login dibuat
    // 'Authorization': 'Bearer $token',
  };

  // ── GET ──────────────────────────────────────────────────────────
  /// Mengambil data dari server
  Future<Map<String, dynamic>> get(String endpoint) async {
    final uri = Uri.parse(ApiConstants.baseUrl + endpoint);

    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(
            const Duration(seconds: ApiConstants.connectTimeoutSeconds),
          );

      return _handleResponse(response);
    } catch (e) {
      throw ApiException('GET $endpoint gagal: $e');
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
          .post(uri, headers: _headers, body: jsonEncode(body))
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
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Sukses: urai JSON
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // Error: lempar exception dengan pesan dari server
      throw ApiException(
        'Server error ${response.statusCode}: ${response.body}',
      );
    }
  }

  // Tutup koneksi saat tidak dipakai lagi
  void dispose() => _client.close();
}

/// Exception khusus untuk error API
class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}
