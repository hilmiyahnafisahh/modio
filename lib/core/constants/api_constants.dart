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
  // Proxy AI (backend/main.py) yang sudah di-hosting permanen. Tanpa
  // trailing slash — tiap endpoint di bawah sudah diawali '/', jadi
  // trailing slash di sini akan membuat URL gabungan jadi dobel-slash.
  static const String baseUrl = 'https://modio-api.stas-rg.com'; // Alamat dasar server backend

  // ── Timeout ──────────────────────────────────────────────────────
  // Batas waktu tunggu koneksi (dalam detik)
  static const int connectTimeoutSeconds = 20; // Batas waktu membangun koneksi
  static const int receiveTimeoutSeconds = 15; // Batas waktu menunggu respons data

  // ── Endpoint Transaksi ───────────────────────────────────────────
  static const String transactions   = '/transactions'; // Endpoint daftar transaksi
  static const String transactionById = '/transactions/:id'; // Endpoint satu transaksi berdasarkan id

  // ── Endpoint Laporan ─────────────────────────────────────────────
  static const String reports        = '/reports'; // Endpoint data laporan
  static const String reportSummary  = '/reports/summary'; // Endpoint ringkasan laporan

  // ── Endpoint AI ──────────────────────────────────────────────────
  static const String aiChat         = '/ai/chat'; // Endpoint obrolan dengan AI
  static const String aiAnalysis     = '/v1/ai/analysis'; // Endpoint saran AI untuk laporan bulanan
  static const String aiParseTransaction = '/v1/ai/parse-transaction'; // Endpoint penguraian ucapan menjadi transaksi

  // ── Endpoint Auth ────────────────────────────────────────────────
  static const String login          = '/auth/login'; // Endpoint login
  static const String logout         = '/auth/logout'; // Endpoint logout
}
