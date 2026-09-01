import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../../../core/utils/ulid.dart';
import 'transaction_model.dart';

/// Rentang waktu untuk menyaring riwayat
enum PeriodeFilter { semua, hariIni, mingguIni, bulanIni }

extension PeriodeFilterX on PeriodeFilter {
  String get label => switch (this) {
        PeriodeFilter.semua => 'Semua waktu',
        PeriodeFilter.hariIni => 'Hari ini',
        PeriodeFilter.mingguIni => 'Minggu ini',
        PeriodeFilter.bulanIni => 'Bulan ini',
      };

  /// Batas awal periode dalam waktu setempat. null berarti tanpa batas.
  DateTime? get mulai {
    final DateTime now = DateTime.now();
    return switch (this) {
      PeriodeFilter.semua => null,
      PeriodeFilter.hariIni => DateTime(now.year, now.month, now.day),
      PeriodeFilter.mingguIni => DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1)),
      PeriodeFilter.bulanIni => DateTime(now.year, now.month, 1),
    };
  }
}

/// Satu-satunya pintu ke basis data.
///
/// Layar TIDAK BOLEH memanggil SQLite langsung. Kalau nanti sinkronisasi
/// server ditambahkan, hanya berkas ini yang berubah — bukan setiap layar.
///
/// ATURAN PENTING: setiap query yang menyentuh transaksi wajib menyaring
/// berdasarkan mode. Melewatkannya membuat saldo usaha dan organisasi
/// tercampur — persis masalah yang fitur ini seharusnya selesaikan, dan
/// pengguna tunanetra tidak punya cara melihat bahwa angkanya salah.
class TransaksiRepository {
  Future<Database> get _db async => DatabaseHelper.instance.database;

  // ── Mode pembukuan ────────────────────────────────────────────────

  /// Mengganti mode aktif dan mengembalikan ringkasan mode yang baru.
  ///
  /// Ringkasan ikut dikembalikan supaya pemanggil bisa langsung
  /// mengumumkan saldo mode tujuan. Tanpa itu, pengguna hanya mendengar
  /// "sekarang mode Organisasi" tanpa cara memastikan ia benar berpindah.
  // ── Transaksi ─────────────────────────────────────────────────────

  /// Menyimpan transaksi baru pada mode yang sedang aktif.
  Future<TransactionItem> simpan({
    required String title,
    required int nominal,
    required TransactionType type,
    required String method,
    String kategori = 'Lainnya',
    String? catatan,
    String sumberInput = 'manual',
    DateTime? waktu,
  }) async {
    if (nominal <= 0) {
      throw ArgumentError('Nominal harus lebih besar dari nol.');
    }

    final DateTime sekarang = DateTime.now().toUtc();
    final TransactionItem transaksi = TransactionItem(
      id: Ulid.generate(),
      title: title,
      nominal: nominal,
      method: method,
      kategori: kategori,
      type: type,
      catatan: catatan,
      sumberInput: sumberInput,
      occurredAt: waktu?.toUtc() ?? sekarang,
    );

    final Database db = await _db;
    await db.insert('transaksi', {
      ...transaksi.toMap(),
      'created_at': sekarang.toIso8601String(),
      'updated_at': sekarang.toIso8601String(),
    });

    return transaksi;
  }

  /// Riwayat transaksi, terbaru dulu.
  ///
  /// [batas] null berarti tanpa batas — dipakai halaman riwayat penuh.
  /// [periode] menyaring berdasarkan waktu kejadian.
  /// [tanggalKhusus] bila diisi, menyaring ke satu hari kalender itu
  /// saja (misalnya tanggal yang dipilih lewat kalender), dan
  /// mengabaikan [periode] sepenuhnya — beda dari preset yang selalu
  /// relatif terhadap sekarang, tanggal ini bisa hari mana pun di masa
  /// lalu.
  /// [type] null berarti pemasukan dan pengeluaran keduanya.
  /// [cari] menyaring berdasarkan judul atau kategori.
  Future<List<TransactionItem>> riwayat({
    int? batas = 30,
    String? sebelumId,
    PeriodeFilter periode = PeriodeFilter.semua,
    DateTime? tanggalKhusus,
    TransactionType? type,
    String? cari,
  }) async {
    final Database db = await _db;

    final List<String> syarat = ['deleted_at IS NULL'];
    final List<Object?> nilai = <Object?>[];

    if (sebelumId != null) {
      syarat.add('id < ?');
      nilai.add(sebelumId);
    }

    // Batas periode dihitung dari waktu setempat lalu diubah ke UTC
    // agar cocok dengan format penyimpanan.
    if (tanggalKhusus != null) {
      final DateTime awal = DateTime(
        tanggalKhusus.year,
        tanggalKhusus.month,
        tanggalKhusus.day,
      );
      final DateTime akhir = awal.add(const Duration(days: 1));
      syarat.add('occurred_at >= ? AND occurred_at < ?');
      nilai.add(awal.toUtc().toIso8601String());
      nilai.add(akhir.toUtc().toIso8601String());
    } else {
      final DateTime? mulai = periode.mulai;
      if (mulai != null) {
        syarat.add('occurred_at >= ?');
        nilai.add(mulai.toUtc().toIso8601String());
      }
    }

    if (type != null) {
      syarat.add('type = ?');
      nilai.add(type.name);
    }

    if (cari != null && cari.trim().isNotEmpty) {
      syarat.add('(title LIKE ? OR kategori LIKE ?)');
      final String pola = '%${cari.trim()}%';
      nilai.add(pola);
      nilai.add(pola);
    }

    final List<Map<String, Object?>> baris = await db.query(
      'transaksi',
      where: syarat.join(' AND '),
      whereArgs: nilai,
      orderBy: 'id DESC',
      limit: batas,
    );

    return baris
        .map((b) => TransactionItem.fromMap(b.cast<String, dynamic>()))
        .toList();
  }

  /// Total pemasukan dan pengeluaran untuk sekumpulan transaksi yang
  /// sudah disaring.
  ///
  /// Dihitung di Dart, bukan lewat query terpisah, agar angkanya selalu
  /// cocok dengan daftar yang sedang ditampilkan.
  ({int masuk, int keluar, int selisih}) hitungTotal(
    List<TransactionItem> daftar,
  ) {
    int masuk = 0;
    int keluar = 0;
    for (final TransactionItem t in daftar) {
      if (t.type == TransactionType.masuk) {
        masuk += t.nominal;
      } else {
        keluar += t.nominal;
      }
    }
    return (masuk: masuk, keluar: keluar, selisih: masuk - keluar);
  }

  /// Ringkasan saldo dan aktivitas hari ini.
  Future<FinancialSummary> ringkasanHariIni() async {
    final Database db = await _db;

    final DateTime sekarang = DateTime.now();
    final DateTime mulai =
        DateTime(sekarang.year, sekarang.month, sekarang.day);
    final DateTime selesai = mulai.add(const Duration(days: 1));

    final List<Map<String, Object?>> total = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'masuk'  THEN nominal END), 0) AS masuk,
        COALESCE(SUM(CASE WHEN type = 'keluar' THEN nominal END), 0) AS keluar
      FROM transaksi
      WHERE deleted_at IS NULL
    ''');

    final List<Map<String, Object?>> hariIni = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'masuk'  THEN nominal END), 0) AS masuk,
        COALESCE(SUM(CASE WHEN type = 'keluar' THEN nominal END), 0) AS keluar,
        COUNT(*) AS jumlah
      FROM transaksi
      WHERE deleted_at IS NULL
        AND occurred_at >= ? AND occurred_at < ?
    ''', [
      mulai.toUtc().toIso8601String(),
      selesai.toUtc().toIso8601String(),
    ]);

    final int saldoAwal = int.tryParse(
          await ambilPengaturan('saldo_awal') ?? '0',
        ) ??
        0;

    return FinancialSummary(
      saldo: saldoAwal +
          (total.first['masuk'] as num).toInt() -
          (total.first['keluar'] as num).toInt(),
      pemasukanHariIni: (hariIni.first['masuk'] as num).toInt(),
      pengeluaranHariIni: (hariIni.first['keluar'] as num).toInt(),
      jumlahTransaksi: (hariIni.first['jumlah'] as num).toInt(),
    );
  }

  /// Daftar nama kategori untuk jenis transaksi tertentu.
  Future<List<String>> kategoriUntuk(TransactionType type) async {
    final Database db = await _db;
    final List<Map<String, Object?>> baris = await db.query(
      'kategori',
      columns: ['nama'],
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'id',
    );
    return baris.map((b) => b['nama']! as String).toList();
  }

  /// Menambah kategori baru untuk jenis transaksi tertentu.
  ///
  /// Nama kategori yang sudah ada (sama persis, jenis sama) tidak
  /// dianggap galat — [ConflictAlgorithm.ignore] membuat baris duplikat
  /// diam-diam tidak disisipkan, sehingga pemanggil selalu bisa
  /// langsung memakai [nama] sebagai kategori terpilih tanpa perlu
  /// membedakan "baru dibuat" dari "sudah ada sebelumnya".
  Future<void> tambahKategori(String nama, TransactionType type) async {
    final String bersih = nama.trim();
    if (bersih.isEmpty) {
      throw ArgumentError('Nama kategori tidak boleh kosong.');
    }
    final Database db = await _db;
    await db.insert(
      'kategori',
      {'nama': bersih, 'type': type.name},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Memperbarui transaksi yang sudah disimpan.
  /// 
  /// Hanya field yang disediakan yang akan diperbarui; field lainnya
  /// tetap sama. Field updated_at selalu diperbarui.
  Future<void> perbarui({
    required String id,
    String? title,
    int? nominal,
    TransactionType? type,
    String? method,
    String? kategori,
    String? catatan,
    DateTime? waktu,
  }) async {
    if (nominal != null && nominal <= 0) {
      throw ArgumentError('Nominal harus lebih besar dari nol.');
    }

    final Database db = await _db;
    final Map<String, Object?> data = {
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'pending',
    };

    if (title != null) data['title'] = title;
    if (nominal != null) data['nominal'] = nominal;
    if (type != null) data['type'] = type.name;
    if (method != null) data['method'] = method;
    if (kategori != null) data['kategori'] = kategori;
    if (catatan != null) data['catatan'] = catatan;
    if (waktu != null) data['occurred_at'] = waktu.toUtc().toIso8601String();

    await db.update(
      'transaksi',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Penghapusan lunak. Data keuangan tidak pernah dibuang permanen —
  /// pengguna harus bisa menelusuri kembali apa yang pernah tercatat.
  Future<void> hapus(String id) async {
    final Database db = await _db;
    await db.update(
      'transaksi',
      {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Pengaturan ────────────────────────────────────────────────────

  Future<String?> ambilPengaturan(String kunci) async {
    final Database db = await _db;
    final List<Map<String, Object?>> baris = await db.query(
      'pengaturan',
      where: 'kunci = ?',
      whereArgs: [kunci],
      limit: 1,
    );
    return baris.isEmpty ? null : baris.first['nilai'] as String;
  }

  Future<void> simpanPengaturan(String kunci, String nilai) async {
    final Database db = await _db;
    await db.insert(
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> simpanSaldoAwal(int nominal) =>
      simpanPengaturan('saldo_awal', nominal.toString());
}
