import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Basis data lokal. Satu berkas di penyimpanan privat aplikasi.
///
/// ATURAN WAKTU: semua kolom waktu disimpan sebagai teks ISO 8601 dalam
/// UTC. Konversi ke waktu setempat hanya terjadi saat ditampilkan.
/// Menyimpan waktu lokal langsung akan mengacaukan urutan transaksi
/// begitu pengguna berpindah zona atau perangkat mengoreksi jamnya.
///
/// ATURAN UANG: nominal disimpan INTEGER rupiah utuh. Tidak ada REAL
/// untuk uang — pembulatan desimal membuat Rp100.000 tersimpan sebagai
/// 99999,99999.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _namaBerkas = 'modio.db';
  static const int _versi = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _buka();

  Future<Database> _buka() async {
    final String jalur = p.join(await getDatabasesPath(), _namaBerkas);
    return openDatabase(
      jalur,
      version: _versi,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _buatSkema,
      onUpgrade: _naikkanVersi,
    );
  }

  Future<void> _buatSkema(Database db, int versi) async {
    await db.execute('''
      CREATE TABLE transaksi (
        id            TEXT    PRIMARY KEY,
        title         TEXT    NOT NULL,
        nominal       INTEGER NOT NULL CHECK (nominal > 0),
        method        TEXT    NOT NULL,
        kategori      TEXT    NOT NULL DEFAULT 'Lainnya',
        type          TEXT    NOT NULL CHECK (type IN ('masuk','keluar')),
        catatan       TEXT,
        sumber_input  TEXT    NOT NULL DEFAULT 'manual',
        occurred_at   TEXT    NOT NULL,
        created_at    TEXT    NOT NULL,
        updated_at    TEXT    NOT NULL,
        deleted_at    TEXT,
        sync_status   TEXT    NOT NULL DEFAULT 'pending'
                              CHECK (sync_status IN
                                ('pending','syncing','synced','failed'))
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_transaksi_waktu
        ON transaksi (deleted_at, occurred_at DESC)
    ''');

    await db.execute('''
      CREATE TABLE kategori (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        nama  TEXT NOT NULL,
        type  TEXT NOT NULL CHECK (type IN ('masuk','keluar')),
        UNIQUE (nama, type)
      )
    ''');

    await db.execute('''
      CREATE TABLE pengaturan (
        kunci TEXT PRIMARY KEY,
        nilai TEXT NOT NULL
      )
    ''');

    await _isiDataAwal(db);
  }

  Future<void> _isiDataAwal(Database db) async {
    final Batch batch = db.batch();

    const List<List<String>> kategoriBawaan = [
      ['Penjualan', 'masuk'],
      ['Jasa', 'masuk'],
      ['Iuran Anggota', 'masuk'],
      ['Donasi', 'masuk'],
      ['Modal Masuk', 'masuk'],
      ['Pemasukan Lain', 'masuk'],
      ['Bahan Baku', 'keluar'],
      ['Transportasi', 'keluar'],
      ['Gaji', 'keluar'],
      ['Sewa', 'keluar'],
      ['Listrik dan Air', 'keluar'],
      ['Peralatan', 'keluar'],
      ['Kegiatan', 'keluar'],
      ['Pengeluaran Lain', 'keluar'],
    ];

    for (final k in kategoriBawaan) {
      batch.insert('kategori', {'nama': k[0], 'type': k[1]});
    }

    batch.insert('pengaturan', {'kunci': 'saldo_awal', 'nilai': '0'});

    await batch.commit(noResult: true);
  }

  /// Dipanggil saat nomor versi skema naik.
  ///
  /// Kosong untuk sekarang, tapi kerangkanya disiapkan: begitu ada
  /// pengguna asli, mengubah tabel tanpa jalur migrasi berarti
  /// menghapus catatan keuangan mereka.
  ///
  /// Catatan: SQLite hanya mengizinkan ADD COLUMN. Mengubah tipe atau
  /// menghapus kolom harus lewat buat-tabel-baru, salin, hapus lama,
  /// ganti nama.
  Future<void> _naikkanVersi(Database db, int lama, int baru) async {
    if (lama < 2) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE transaksi_baru (
            id            TEXT    PRIMARY KEY,
            title         TEXT    NOT NULL,
            nominal       INTEGER NOT NULL CHECK (nominal > 0),
            method        TEXT    NOT NULL,
            kategori      TEXT    NOT NULL DEFAULT 'Lainnya',
            type          TEXT    NOT NULL CHECK (type IN ('masuk','keluar')),
            catatan       TEXT,
            sumber_input  TEXT    NOT NULL DEFAULT 'manual',
            occurred_at   TEXT    NOT NULL,
            created_at    TEXT    NOT NULL,
            updated_at    TEXT    NOT NULL,
            deleted_at    TEXT,
            sync_status   TEXT    NOT NULL DEFAULT 'pending'
                                CHECK (sync_status IN
                                  ('pending','syncing','synced','failed'))
          )
        ''');
        await txn.execute('''
          INSERT INTO transaksi_baru (
            id, title, nominal, method, kategori, type, catatan,
            sumber_input, occurred_at, created_at, updated_at, deleted_at,
            sync_status
          )
          SELECT id, title, nominal, method, kategori, type, catatan,
                 sumber_input, occurred_at, created_at, updated_at,
                 deleted_at, sync_status
          FROM transaksi
        ''');
        await txn.execute('DROP TABLE transaksi');
        await txn.execute('ALTER TABLE transaksi_baru RENAME TO transaksi');
        await txn.execute('''
          CREATE INDEX idx_transaksi_waktu
            ON transaksi (deleted_at, occurred_at DESC)
        ''');

        final List<Map<String, Object?>> saldoLama = await txn.query(
          'pengaturan',
          where: 'kunci IN (?, ?)',
          whereArgs: ['saldo_awal_usaha', 'saldo_awal_organisasi'],
        );
        final int saldoAwal = saldoLama.fold<int>(0, (total, item) {
          return total + (int.tryParse(item['nilai'] as String) ?? 0);
        });
        await txn.insert(
          'pengaturan',
          {'kunci': 'saldo_awal', 'nilai': saldoAwal.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'pengaturan',
          where: 'kunci IN (?, ?, ?)',
          whereArgs: [
            'mode_aktif',
            'saldo_awal_usaha',
            'saldo_awal_organisasi',
          ],
        );
      });
    }
  }

  Future<void> tutup() async {
    await _db?.close();
    _db = null;
  }

  /// Menghapus seluruh isi basis data. Untuk pengujian saja.
  Future<void> resetUntukUji() async {
    final Database db = await database;
    await db.delete('transaksi');
  }
}
