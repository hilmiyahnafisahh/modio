import '../constants/api_constants.dart';
import 'api_service.dart';

/// Hasil AI menguraikan satu ucapan menjadi data transaksi.
///
/// Semua field bisa null/kosong — AI cuma menebak, pengguna yang
/// memutuskan lewat form peninjauan sebelum data benar-benar tersimpan.
class ParsedTransaction {
  final int? nominal;
  final String? jenis; // 'masuk' atau 'keluar'
  final String? kategori;
  final String catatan;

  const ParsedTransaction({
    this.nominal,
    this.jenis,
    this.kategori,
    required this.catatan,
  });

  factory ParsedTransaction.fromJson(Map<String, dynamic> json) {
    return ParsedTransaction(
      nominal: (json['nominal'] as num?)?.toInt(),
      jenis: json['jenis'] as String?,
      kategori: json['kategori'] as String?,
      catatan: json['catatan'] as String? ?? '',
    );
  }
}

/// Menerjemahkan ucapan bebas menjadi data transaksi terstruktur, lewat
/// proxy backend (backend/main.py) yang memanggil Gemini. Kunci API tidak
/// pernah ada di sisi app — lihat backend untuk detailnya.
class AiParserService {
  final ApiService _api;

  AiParserService({ApiService? api}) : _api = api ?? ApiService();

  Future<ParsedTransaction> uraikanTransaksi({
    required String teks,
    required List<String> kategoriMasuk,
    required List<String> kategoriKeluar,
  }) async {
    final Map<String, dynamic> hasil = await _api.post(
      ApiConstants.aiParseTransaction,
      {
        'teks': teks,
        'kategori_masuk': kategoriMasuk,
        'kategori_keluar': kategoriKeluar,
      },
    );
    return ParsedTransaction.fromJson(hasil);
  }
}
