/// ─────────────────────────────────────────────────────────────────
/// API CONSTANTS  –  Semua nilai konstan untuk komunikasi API
///
/// Cara pakai:
///   final url = ApiConstants.baseUrl + ApiConstants.transactions;
/// ─────────────────────────────────────────────────────────────────
library;

class ApiConstants {
  ApiConstants._();

  // ── Base URL ─────────────────────────────────────────────────────
  // Sementara menunjuk ke proxy AI lokal (backend/main.py) yang jalan
  // di IP LAN laptop pengembang — HP harus satu jaringan WiFi dengan
  // laptop supaya bisa mengaksesnya. Ganti dengan URL server produksi
  // yang sebenarnya begitu proxy ini di-deploy ke tempat permanen.
  static const String baseUrl = 'http://10.66.176.70:8000';

  // ── Timeout ──────────────────────────────────────────────────────
  // Batas waktu tunggu koneksi (dalam detik)
  static const int connectTimeoutSeconds = 10;
  static const int receiveTimeoutSeconds = 15;

  // ── Endpoint Transaksi ───────────────────────────────────────────
  static const String transactions   = '/transactions';
  static const String transactionById = '/transactions/:id';

  // ── Endpoint Laporan ─────────────────────────────────────────────
  static const String reports        = '/reports';
  static const String reportSummary  = '/reports/summary';

  // ── Endpoint AI ──────────────────────────────────────────────────
  static const String aiChat         = '/ai/chat';
  static const String aiAnalysis     = '/ai/analysis';
  static const String aiParseTransaction = '/v1/ai/parse-transaction';

  // ── Endpoint Auth ────────────────────────────────────────────────
  static const String login          = '/auth/login';
  static const String logout         = '/auth/logout';
}
