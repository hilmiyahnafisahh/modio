import 'package:sqflite/sqflite.dart'; // Paket basis data SQLite

import '../../../core/akuntansi/coa.dart'; // Kelompok akun COA (SAK EMKM)
import '../../../core/database/database_helper.dart'; // Akses koneksi basis data
import '../../transactions/data/transaction_model.dart'; // Model TransactionItem
import 'report_model.dart'; // Model LaporanBulanan & RincianKategori

/// Perhitungan laporan laba rugi bulanan (SAK EMKM).
///
/// Dipisah dari TransaksiRepository karena tanggung jawabnya berbeda:
/// yang satu mengurus pencatatan, yang ini mengurus peringkasan.
///
/// Seluruh angka dihitung dengan SQL. Tidak ada nilai yang dibangkitkan
/// model bahasa — narasi hanya merangkai angka yang sudah dihitung.
class LaporanRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database; // Ambil koneksi basis data aktif

  /// Laporan laba rugi satu bulan, lengkap dengan pembanding bulan
  /// sebelumnya.
  Future<LaporanBulanan> laporanBulan({
    required int tahun,
    required int bulan,
  }) async {
    final List<RincianKategori> rincian =
        await _rincianKategori(tahun, bulan, denganTransaksi: true); // Semua akun bulan ini, beserta transaksinya
    final List<RincianKategori> rincianLalu = await _rincianKategori( // Akun bulan lalu, cukup totalnya
      bulan == 1 ? tahun - 1 : tahun, // Bila Januari, bulan lalu ada di tahun sebelumnya
      bulan == 1 ? 12 : bulan - 1, // Bila Januari, bulan lalu adalah Desember
      denganTransaksi: false,
    );

    // Pembanding memakai susunan laba rugi yang sama dengan bulan ini,
    // supaya "naik/turun" membandingkan hal yang setara.
    final LaporanBulanan lalu = LaporanBulanan(
      tahun: tahun,
      bulan: bulan,
      jumlahTransaksi: rincianLalu.fold(0, (n, r) => n + r.jumlahTransaksi),
      rincian: rincianLalu,
    );

    return LaporanBulanan(
      tahun: tahun,
      bulan: bulan,
      jumlahTransaksi: rincian.fold(0, (n, r) => n + r.jumlahTransaksi),
      rincian: rincian,
      // Null bila bulan lalu memang tidak punya transaksi, agar narasi
      // tidak menyebut perbandingan yang tidak bermakna.
      pendapatanBulanLalu: lalu.jumlahTransaksi == 0 ? null : lalu.totalPendapatan,
      bebanBulanLalu: lalu.jumlahTransaksi == 0 ? null : lalu.totalBeban,
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

  /// Total per kategori untuk satu bulan, terbesar dulu.
  ///
  /// Kelompok akun diambil dari tabel kategori (transaksi menyimpan
  /// nama kategori sebagai teks). Kategori yang sudah dihapus atau tidak
  /// ditemukan jatuh ke kelompok bawaan per jenis transaksi.
  Future<List<RincianKategori>> _rincianKategori(
    int tahun,
    int bulan, {
    required bool denganTransaksi,
  }) async {
    final Database db = await _db;
    final (String mulai, String selesai) = _batasBulanUtc(tahun, bulan);

    // Step 1: ringkasan per kategori, beserta kelompok akunnya
    final List<Map<String, Object?>> baris = await db.rawQuery('''
      SELECT t.kategori      AS kategori,
             t.type          AS type,
             k.kelompok      AS kelompok,
             SUM(t.nominal)  AS total,
             COUNT(*)        AS jumlah
      FROM transaksi t
      LEFT JOIN kategori k ON k.nama = t.kategori AND k.type = t.type
      WHERE t.deleted_at IS NULL
        AND t.occurred_at >= ? AND t.occurred_at < ?
      GROUP BY t.kategori, t.type
      ORDER BY total DESC
    ''', [mulai, selesai]);

    // Step 2: untuk setiap kategori, ambil detail transaksinya bila perlu
    final List<RincianKategori> hasil = [];
    for (final b in baris) { // Ulangi untuk setiap kategori yang ditemukan
      final String namaKat = b['kategori']! as String;
      final String type = b['type']! as String;

      List<TransactionItem> items = const [];
      if (denganTransaksi) {
        final List<Map<String, Object?>> detailBaris = await db.query( // Ambil semua transaksi milik kategori ini
          'transaksi',
          where: 'deleted_at IS NULL AND type = ? '
              'AND kategori = ? AND occurred_at >= ? AND occurred_at < ?',
          whereArgs: [type, namaKat, mulai, selesai],
          orderBy: 'occurred_at DESC',
        );
        items = detailBaris.map(TransactionItem.fromMap).toList(); // Ubah tiap baris jadi objek TransactionItem
      }

      hasil.add(RincianKategori(
        nama: namaKat,
        total: (b['total'] as num).toInt(),
        jumlahTransaksi: (b['jumlah'] as num).toInt(),
        kelompok: KelompokAkun.dariKode(
          b['kelompok'] as String?,
          masuk: type == 'masuk',
        ),
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
}
