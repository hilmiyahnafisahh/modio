import 'package:sqflite/sqflite.dart'; // Paket basis data SQLite

import '../../../core/database/database_helper.dart'; // Akses koneksi basis data
import '../../../core/services/ai_analysis_service.dart'; // Analisis laporan oleh AI lewat backend
import '../../transactions/data/transaction_model.dart'; // Model TransactionItem & TransactionType
import 'report_model.dart'; // Model LaporanBulanan & RincianKategori

/// Perhitungan laporan bulanan.
///
/// Dipisah dari TransaksiRepository karena tanggung jawabnya berbeda:
/// yang satu mengurus pencatatan, yang ini mengurus peringkasan.
///
/// Seluruh angka dihitung dengan SQL. Tidak ada nilai yang dibangkitkan
/// model bahasa — narasi hanya merangkai angka yang sudah dihitung.
class LaporanRepository {
  LaporanRepository({AiAnalysisService? ai}) : _ai = ai ?? AiAnalysisService(); // Bisa disuntik untuk pengujian, atau buat baru

  final AiAnalysisService _ai; // Layanan analisis AI lewat backend

  Future<Database> get _db async => DatabaseHelper.instance.database; // Ambil koneksi basis data aktif

  /// Laporan satu bulan, lengkap dengan pembanding bulan sebelumnya.
  Future<LaporanBulanan> laporanBulan({
    required int tahun,
    required int bulan,
  }) async {
    final _Total bulanIni = await _hitungTotal(tahun, bulan); // Hitung total masuk/keluar bulan ini
    final _Total bulanLalu = await _hitungTotal( // Hitung total bulan sebelumnya untuk pembanding
      bulan == 1 ? tahun - 1 : tahun, // Bila Januari, bulan lalu ada di tahun sebelumnya
      bulan == 1 ? 12 : bulan - 1, // Bila Januari, bulan lalu adalah Desember
    );

    final List<RincianKategori> pendapatan = await _rincianKategori( // Rincian per kategori untuk pemasukan
      tahun,
      bulan,
      TransactionType.masuk,
    );
    final List<RincianKategori> beban = await _rincianKategori( // Rincian per kategori untuk pengeluaran
      tahun,
      bulan,
      TransactionType.keluar,
    );

    return LaporanBulanan(
      tahun: tahun,
      bulan: bulan,
      totalPendapatan: bulanIni.masuk,
      totalBeban: bulanIni.keluar,
      jumlahTransaksi: bulanIni.jumlah,
      rincianPendapatan: pendapatan,
      rincianBeban: beban,
      // Null bila bulan lalu memang tidak punya transaksi, agar narasi
      // tidak menyebut perbandingan yang tidak bermakna.
      pendapatanBulanLalu: bulanLalu.jumlah == 0 ? null : bulanLalu.masuk,
      bebanBulanLalu: bulanLalu.jumlah == 0 ? null : bulanLalu.keluar,
    );
  }

  /// Daftar bulan yang punya transaksi, terbaru dulu.
  /// Dipakai untuk pemilih periode agar hanya menampilkan bulan
  /// yang benar-benar ada isinya.
  Future<List<({int tahun, int bulan})>> bulanTersedia() async {
    final Database db = await _db;

    final List<Map<String, Object?>> baris = await db.query( // Ambil semua tanggal transaksi yang belum dihapus
      'transaksi',
      columns: ['occurred_at'],
      where: 'deleted_at IS NULL',
      orderBy: 'occurred_at DESC',
    );

    // Pengelompokan dilakukan di Dart karena occurred_at disimpan UTC,
    // sedangkan bulan yang dimaksud pengguna adalah bulan setempat.
    final Set<String> terlihat = <String>{}; // Simpan kunci "tahun-bulan" yang sudah tercatat
    final List<({int tahun, int bulan})> hasil = []; // Daftar hasil unik tahun+bulan

    for (final Map<String, Object?> b in baris) {
      final DateTime lokal =
          DateTime.parse(b['occurred_at']! as String).toLocal(); // Ubah waktu UTC tersimpan ke waktu lokal
      final String kunci = '${lokal.year}-${lokal.month}'; // Kunci unik per tahun-bulan
      if (terlihat.add(kunci)) { // add() true bila kunci ini baru pertama ditemukan
        hasil.add((tahun: lokal.year, bulan: lokal.month));
      }
    }

    // Bulan berjalan selalu tersedia meski belum ada transaksi.
    final DateTime now = DateTime.now();
    if (!hasil.any((e) => e.tahun == now.year && e.bulan == now.month)) { // Cek bulan ini sudah ada di daftar
      hasil.insert(0, (tahun: now.year, bulan: now.month)); // Sisipkan di posisi paling atas
    }

    return hasil;
  }

  // ── Internal ──────────────────────────────────────────────────────

  Future<_Total> _hitungTotal(int tahun, int bulan) async {
    final Database db = await _db;
    final (String mulai, String selesai) = _batasBulanUtc(tahun, bulan); // Rentang waktu UTC awal-akhir bulan

    final List<Map<String, Object?>> hasil = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'masuk'  THEN nominal END), 0) AS masuk,
        COALESCE(SUM(CASE WHEN type = 'keluar' THEN nominal END), 0) AS keluar,
        COUNT(*) AS jumlah
      FROM transaksi
      WHERE deleted_at IS NULL
        AND occurred_at >= ? AND occurred_at < ?
    ''', [mulai, selesai]);
    // Query di atas: jumlahkan nominal masuk dan keluar terpisah,
    // plus hitung total baris, dalam satu kali baca tabel.

    return _Total(
      masuk: (hasil.first['masuk'] as num).toInt(),
      keluar: (hasil.first['keluar'] as num).toInt(),
      jumlah: (hasil.first['jumlah'] as num).toInt(),
    );
  }

  Future<List<RincianKategori>> _rincianKategori(
    int tahun,
    int bulan,
    TransactionType type,
  ) async {
    final Database db = await _db;
    final (String mulai, String selesai) = _batasBulanUtc(tahun, bulan);

    // Step 1: ringkasan per kategori
    final List<Map<String, Object?>> baris = await db.rawQuery('''
      SELECT kategori,
             SUM(nominal) AS total,
             COUNT(*)     AS jumlah
      FROM transaksi
      WHERE deleted_at IS NULL AND type = ?
        AND occurred_at >= ? AND occurred_at < ?
      GROUP BY kategori
      ORDER BY total DESC
    ''', [type.name, mulai, selesai]);
    // Query di atas: total nominal & jumlah transaksi per kategori,
    // diurutkan dari kategori terbesar ke terkecil.

    // Step 2: untuk setiap kategori, ambil detail transaksinya
    final List<RincianKategori> hasil = [];
    for (final b in baris) { // Ulangi untuk setiap kategori yang ditemukan
      final String namaKat = b['kategori']! as String;

      final List<Map<String, Object?>> detailBaris = await db.query( // Ambil semua transaksi milik kategori ini
        'transaksi',
        where: 'deleted_at IS NULL AND type = ? '
            'AND kategori = ? AND occurred_at >= ? AND occurred_at < ?',
        whereArgs: [type.name, namaKat, mulai, selesai],
        orderBy: 'occurred_at DESC',
      );

      final List<TransactionItem> items =
          detailBaris.map(TransactionItem.fromMap).toList(); // Ubah tiap baris jadi objek TransactionItem

      hasil.add(RincianKategori(
        nama: namaKat,
        total: (b['total'] as num).toInt(),
        jumlahTransaksi: (b['jumlah'] as num).toInt(),
        transaksi: items,
      ));
    }

    return hasil;
  }

  /// Batas awal dan akhir bulan dalam UTC.
  ///
  /// Dihitung dari waktu setempat lalu dikonversi, agar transaksi
  /// pada awal atau akhir bulan tidak jatuh ke bulan yang salah.
  (String, String) _batasBulanUtc(int tahun, int bulan) {
    final DateTime mulai = DateTime(tahun, bulan, 1); // Tanggal 1 bulan ini, waktu lokal
    final DateTime selesai = bulan == 12
        ? DateTime(tahun + 1, 1, 1) // Desember: bulan berikutnya adalah Januari tahun depan
        : DateTime(tahun, bulan + 1, 1);
    return (
      mulai.toUtc().toIso8601String(), // Konversi batas awal ke UTC untuk dibandingkan di SQL
      selesai.toUtc().toIso8601String(),
    );
  }

  /// Analisis laporan bulanan oleh Gemini AI: evaluasi laba rugi,
  /// perencanaan ke depan, dan penilaian kondisi usaha.
  ///
  /// Gemini dipanggil lewat backend (AiAnalysisService), bukan langsung
  /// dari app — kunci API di dalam APK bisa dibongkar siapa pun.
  /// Angka dikirim sudah jadi; AI hanya menafsirkan, tidak menghitung.
  Future<String> analisisLaporanDenganGemini({
    required int tahun,
    required int bulan,
  }) async {
    final LaporanBulanan laporan = await laporanBulan(tahun: tahun, bulan: bulan); // Ambil laporan dari basis data lokal

    if (laporan.jumlahTransaksi == 0) { // Tidak ada data, tidak perlu memanggil AI
      return 'Belum ada transaksi pada ${laporan.labelPeriode}, '
          'jadi belum ada yang bisa dianalisis.';
    }

    List<Map<String, dynamic>> rincian(List<RincianKategori> daftar, int total) => // Ubah rincian kategori jadi data JSON
        daftar
            .map((r) => {
                  'nama': r.nama,
                  'total': r.total,
                  'jumlah_transaksi': r.jumlahTransaksi,
                  'persen': r.persen(total), // Porsi dihitung di app, bukan oleh AI
                })
            .toList();

    try {
      final String hasil = await _ai.analisisLaporan({ // Kirim ringkasan laporan ke backend
        'periode': laporan.labelPeriode,
        'total_pendapatan': laporan.totalPendapatan,
        'total_beban': laporan.totalBeban,
        'laba_bersih': laporan.labaBersih,
        'jumlah_transaksi': laporan.jumlahTransaksi,
        'perubahan_pendapatan': laporan.perubahanPendapatan,
        'perubahan_beban': laporan.perubahanBeban,
        'rincian_pendapatan': rincian(laporan.rincianPendapatan, laporan.totalPendapatan),
        'rincian_beban': rincian(laporan.rincianBeban, laporan.totalBeban),
      });
      return hasil.isEmpty ? 'AI tidak memberikan hasil analisis. Coba lagi.' : hasil; // Jaga-jaga bila balasan kosong
    } catch (_) { // Jika terjadi error apa pun (mis. tidak ada koneksi atau server mati)
      return 'Analisis AI belum bisa dibuat. Pastikan HP tersambung ke '
          'jaringan yang sama dengan server, lalu coba lagi.';
    }
  }
}

class _Total { // Struktur sederhana hasil penjumlahan satu bulan
  final int masuk; // Total pemasukan
  final int keluar; // Total pengeluaran
  final int jumlah; // Jumlah transaksi

  const _Total({
    required this.masuk,
    required this.keluar,
    required this.jumlah,
  });
}