import '../../../core/constants/api_constants.dart'; // Daftar alamat/endpoint API
import '../../../core/services/api_service.dart'; // Layanan HTTP dasar untuk memanggil backend
import 'report_model.dart'; // Model LaporanBulanan & RincianKategori

/// Saran AI untuk satu laporan bulanan.
///
/// Isinya hanya kalimat saran TANPA angka. Angka laporan tetap dihitung
/// di HP oleh LaporanRepository; backend membuang saran yang menyebut
/// angka, supaya pengguna tunanetra tidak mendengar nominal yang
/// mungkin keliru dari model bahasa.
class AnalisisAi { // Struktur data hasil analisis laporan oleh AI
  final String judul; // Frasa singkat yang merangkum kondisi bulan itu
  final List<String> saran; // Dua sampai tiga saran praktis
  final String nada; // 'positif', 'negatif', atau 'netral'

  const AnalisisAi({
    required this.judul,
    required this.saran,
    required this.nada,
  });

  factory AnalisisAi.fromJson(Map<String, dynamic> json) { // Buat objek dari data JSON respons API
    return AnalisisAi(
      judul: json['judul'] as String? ?? '',
      saran: (json['saran'] as List<dynamic>? ?? const [])
          .whereType<String>() // Abaikan isi yang bukan teks
          .toList(),
      nada: json['nada'] as String? ?? 'netral',
    );
  }
}

/// Meminta saran keuangan dari AI lewat proxy backend (backend/main.py)
/// yang memanggil Gemini. Yang dikirim hanya ringkasan per kategori,
/// bukan daftar transaksi satu per satu.
class AiAnalysisService { // Layanan analisis laporan bulanan via AI
  final ApiService _api; // Klien HTTP yang dipakai untuk memanggil backend

  AiAnalysisService({ApiService? api}) : _api = api ?? ApiService(); // Pakai ApiService yang diberikan atau buat baru

  Future<AnalisisAi> analisisLaporan(LaporanBulanan laporan) async { // Kirim ringkasan laporan ke backend untuk dianalisis
    final Map<String, dynamic> hasil = await _api.post(
      ApiConstants.aiAnalysis,
      {
        'periode': laporan.labelPeriode,
        'total_pendapatan': laporan.totalPendapatan,
        'total_beban': laporan.totalBeban,
        'jumlah_transaksi': laporan.jumlahTransaksi,
        'pendapatan_bulan_lalu': laporan.pendapatanBulanLalu,
        'beban_bulan_lalu': laporan.bebanBulanLalu,
        'rincian_pendapatan': laporan.rincianPendapatan.map(_kategori).toList(),
        'rincian_beban': laporan.rincianBeban.map(_kategori).toList(),
      },
    );
    return AnalisisAi.fromJson(hasil); // Ubah respons JSON menjadi objek AnalisisAi
  }

  Map<String, dynamic> _kategori(RincianKategori k) => { // Ringkasan satu kategori, tanpa detail transaksi
        'nama': k.nama,
        'total': k.total,
        'jumlah_transaksi': k.jumlahTransaksi,
      };
}
