import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../transactions/data/transaction_model.dart';
import 'report_model.dart';

/// Perhitungan laporan bulanan.
///
/// Dipisah dari TransaksiRepository karena tanggung jawabnya berbeda:
/// yang satu mengurus pencatatan, yang ini mengurus peringkasan.
///
/// Seluruh angka dihitung dengan SQL. Tidak ada nilai yang dibangkitkan
/// model bahasa — narasi hanya merangkai angka yang sudah dihitung.
class LaporanRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  /// Laporan satu bulan, lengkap dengan pembanding bulan sebelumnya.
  Future<LaporanBulanan> laporanBulan({
    required int tahun,
    required int bulan,
  }) async {
    final _Total bulanIni = await _hitungTotal(tahun, bulan);
    final _Total bulanLalu = await _hitungTotal(
      bulan == 1 ? tahun - 1 : tahun,
      bulan == 1 ? 12 : bulan - 1,
    );

    final List<RincianKategori> pendapatan = await _rincianKategori(
      tahun,
      bulan,
      TransactionType.masuk,
    );
    final List<RincianKategori> beban = await _rincianKategori(
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

    final List<Map<String, Object?>> baris = await db.query(
      'transaksi',
      columns: ['occurred_at'],
      where: 'deleted_at IS NULL',
      orderBy: 'occurred_at DESC',
    );

    // Pengelompokan dilakukan di Dart karena occurred_at disimpan UTC,
    // sedangkan bulan yang dimaksud pengguna adalah bulan setempat.
    final Set<String> terlihat = <String>{};
    final List<({int tahun, int bulan})> hasil = [];

    for (final Map<String, Object?> b in baris) {
      final DateTime lokal =
          DateTime.parse(b['occurred_at']! as String).toLocal();
      final String kunci = '${lokal.year}-${lokal.month}';
      if (terlihat.add(kunci)) {
        hasil.add((tahun: lokal.year, bulan: lokal.month));
      }
    }

    // Bulan berjalan selalu tersedia meski belum ada transaksi.
    final DateTime now = DateTime.now();
    if (!hasil.any((e) => e.tahun == now.year && e.bulan == now.month)) {
      hasil.insert(0, (tahun: now.year, bulan: now.month));
    }

    return hasil;
  }

  // ── Internal ──────────────────────────────────────────────────────

  Future<_Total> _hitungTotal(int tahun, int bulan) async {
    final Database db = await _db;
    final (String mulai, String selesai) = _batasBulanUtc(tahun, bulan);

    final List<Map<String, Object?>> hasil = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'masuk'  THEN nominal END), 0) AS masuk,
        COALESCE(SUM(CASE WHEN type = 'keluar' THEN nominal END), 0) AS keluar,
        COUNT(*) AS jumlah
      FROM transaksi
      WHERE deleted_at IS NULL
        AND occurred_at >= ? AND occurred_at < ?
    ''', [mulai, selesai]);

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

    // Step 2: untuk setiap kategori, ambil detail transaksinya
    final List<RincianKategori> hasil = [];
    for (final b in baris) {
      final String namaKat = b['kategori']! as String;

      final List<Map<String, Object?>> detailBaris = await db.query(
        'transaksi',
        where: 'deleted_at IS NULL AND type = ? '
            'AND kategori = ? AND occurred_at >= ? AND occurred_at < ?',
        whereArgs: [type.name, namaKat, mulai, selesai],
        orderBy: 'occurred_at DESC',
      );

      final List<TransactionItem> items =
          detailBaris.map(TransactionItem.fromMap).toList();

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
    final DateTime mulai = DateTime(tahun, bulan, 1);
    final DateTime selesai = bulan == 12
        ? DateTime(tahun + 1, 1, 1)
        : DateTime(tahun, bulan + 1, 1);
    return (
      mulai.toUtc().toIso8601String(),
      selesai.toUtc().toIso8601String(),
    );
  }
}

class _Total {
  final int masuk;
  final int keluar;
  final int jumlah;

  const _Total({
    required this.masuk,
    required this.keluar,
    required this.jumlah,
  });
}
