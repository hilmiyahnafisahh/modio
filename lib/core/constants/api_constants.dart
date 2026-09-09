/// ─────────────────────────────────────────────────────────────────
/// API CONSTANTS  –  Semua nilai konstan untuk komunikasi API
///
/// Cara pakai:
///   final url = ApiConstants.baseUrl + ApiConstants.transactions;
/// ─────────────────────────────────────────────────────────────────
library; // Deklarasi berkas ini sebagai library Dart (diperlukan untuk dartdoc di atas)

class ApiConstants { // Kumpulan konstanta terkait komunikasi API
  ApiConstants._(); // Konstruktor privat, kelas ini hanya wadah statis

  // ── Base URL ─────────────────────────────────────────────────────
  // Sementara menunjuk ke proxy AI lokal (backend/main.py) yang jalan
  // di IP LAN laptop pengembang — HP harus satu jaringan WiFi dengan
  // laptop supaya bisa mengaksesnya. Ganti dengan URL server produksi
  // yang sebenarnya begitu proxy ini di-deploy ke tempat permanen.
  static const String baseUrl = 'http://10.66.177.66:8000'; // Alamat dasar server backend

  // ── Timeout ──────────────────────────────────────────────────────
  // Batas waktu tunggu koneksi (dalam detik)
  static const int connectTimeoutSeconds = 10; // Batas waktu membangun koneksi
  static const int receiveTimeoutSeconds = 15; // Batas waktu menunggu respons data

  // ── Endpoint Transaksi ───────────────────────────────────────────
  static const String transactions   = '/transactions'; // Endpoint daftar transaksi
  static const String transactionById = '/transactions/:id'; // Endpoint satu transaksi berdasarkan id

  // ── Endpoint Laporan ─────────────────────────────────────────────
  static const String reports        = '/reports'; // Endpoint data laporan
  static const String reportSummary  = '/reports/summary'; // Endpoint ringkasan laporan

  // ── Endpoint AI ──────────────────────────────────────────────────
  static const String aiChat         = '/ai/chat'; // Endpoint obrolan dengan AI
  static const String aiAnalysis     = '/ai/analysis'; // Endpoint analisis AI
  static const String aiParseTransaction = '/v1/ai/parse-transaction'; // Endpoint penguraian ucapan menjadi transaksi

  // ── Endpoint Auth ────────────────────────────────────────────────
  static const String login          = '/auth/login'; // Endpoint login
  static const String logout         = '/auth/logout'; // Endpoint logout
}
