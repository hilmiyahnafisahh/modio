import '../constants/api_constants.dart'; // Daftar alamat/endpoint API
import 'api_service.dart'; // Layanan HTTP dasar untuk memanggil backend

/// Meminta analisis laporan laba rugi bulanan, lewat proxy backend
/// (backend/main.py) yang memanggil Gemini. Kunci API tidak pernah ada
/// di sisi app — lihat backend untuk detailnya.
///
/// Semua angka di [ringkasan] sudah dihitung app dari basis data. AI
/// hanya menafsirkan, tidak menghitung ulang.
class AiAnalysisService { // Layanan analisis laporan keuangan via AI
  final ApiService _api; // Klien HTTP yang dipakai untuk memanggil backend

  AiAnalysisService({ApiService? api}) : _api = api ?? ApiService(); // Pakai ApiService yang diberikan atau buat baru

  Future<String> analisisLaporan(Map<String, dynamic> ringkasan) async { // Kirim ringkasan laporan ke backend untuk dianalisis AI
    final Map<String, dynamic> hasil = await _api.post( // Panggil endpoint analisis laporan
      ApiConstants.aiAnalyzeReport,
      ringkasan,
    );
    return hasil['analisis'] as String? ?? ''; // Ambil teks analisis, kosong jika tidak ada
  }
}
