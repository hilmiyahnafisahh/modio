/// ─────────────────────────────────────────────────────────────────
/// API CONSTANTS  –  Semua nilai konstan untuk komunikasi APIt
///
/// Cara pakai:
///   final url = ApiConstants.baseUrl + ApiConstants.transactions;
/// ─────────────────────────────────────────────────────────────────
library; // Deklarasi berkas ini sebagai library Dart (diperlukan untuk dartdoc di atas)

class ApiConstants { // Kumpulan konstanta terkait komunikasi API
  ApiConstants._(); // Konstruktor privat, kelas ini hanya wadah statis

  // ── Base URL ─────────────────────────────────────────────────────
  // Sementara menunjuk ke proxy AI lokal (backend/main.py, jalankan
  // `docker compose up` di folder backend). HP tersambung kabel USB dan
  // port diteruskan dengan `adb reverse tcp:8000 tcp:8000`, jadi
  // 127.0.0.1 di HP sampai ke laptop. Ganti dengan URL server produksi
  // begitu endpoint analyze-report sudah di-deploy ke sana.
  static const String baseUrl = 'http://127.0.0.1:8000'; // Alamat dasar server backend

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
  static const String aiAnalysis     = '/ai/analysis'; // Endpoint analisis AI
  static const String aiParseTransaction = '/v1/ai/parse-transaction'; // Endpoint penguraian ucapan menjadi transaksi
  static const String aiAnalyzeReport = '/v1/ai/analyze-report'; // Endpoint analisis laporan laba rugi bulanan

  // ── Endpoint Auth ────────────────────────────────────────────────
  static const String login          = '/auth/login'; // Endpoint login
  static const String logout         = '/auth/logout'; // Endpoint logout
}
