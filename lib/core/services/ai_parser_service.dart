import '../constants/api_constants.dart'; // Daftar alamat/endpoint API
import 'api_service.dart'; // Layanan HTTP dasar untuk memanggil backend

/// Hasil AI menguraikan satu ucapan menjadi data transaksi.
///
/// Semua field bisa null/kosong — AI cuma menebak, pengguna yang
/// memutuskan lewat form peninjauan sebelum data benar-benar tersimpan.
class ParsedTransaction { // Struktur data hasil penguraian ucapan oleh AI
  final int? nominal; // Nominal transaksi yang terdeteksi, bisa kosong
  final String? jenis; // 'masuk' atau 'keluar'
  final String? kategori; // Kategori transaksi yang terdeteksi, bisa kosong
  final String catatan; // Catatan tambahan hasil penguraian

  const ParsedTransaction({ // Konstruktor, hanya catatan yang wajib diisi
    this.nominal,
    this.jenis,
    this.kategori,
    required this.catatan,
  });

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) { // Buat objek dari data JSON respons API
    return ParsedTransaction(
      nominal: (json['nominal'] as num?)?.toInt(), // Ubah angka JSON menjadi int, aman jika null
      jenis: json['jenis'] as String?,
      kategori: json['kategori'] as String?,
      catatan: json['catatan'] as String? ?? '', // Default string kosong jika tidak ada
    );
  }
}

/// Menerjemahkan ucapan bebas menjadi data transaksi terstruktur, lewat
/// proxy backend (backend/main.py) yang memanggil Gemini. Kunci API tidak
/// pernah ada di sisi app — lihat backend untuk detailnya.
class AiParserService { // Layanan penguraian ucapan menjadi data transaksi via AI
  final ApiService _api; // Klien HTTP yang dipakai untuk memanggil backend

  AiParserService({ApiService? api}) : _api = api ?? ApiService(); // Pakai ApiService yang diberikan atau buat baru

  Future<ParsedTransaction> uraikanTransaksi({ // Kirim teks ucapan ke backend untuk diuraikan AI
    required String teks, // Teks ucapan pengguna yang akan diuraikan
    required List<String> kategoriMasuk, // Daftar kategori pemasukan yang dikenal
    required List<String> kategoriKeluar, // Daftar kategori pengeluaran yang dikenal
  }) async {
    final Map<String, dynamic> hasil = await _api.post( // Panggil endpoint AI parsing transaksi
      ApiConstants.aiParseTransaction,
      {
        'teks': teks,
        'kategori_masuk': kategoriMasuk,
        'kategori_keluar': kategoriKeluar,
      },
    );
    return ParsedTransaction.fromJson(hasil); // Ubah respons JSON menjadi objek ParsedTransaction
  }
}
