import 'package:path/path.dart' as p; // Utilitas gabung path file
import 'package:sqflite/sqflite.dart'; // Paket basis data SQLite untuk Flutter

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
  DatabaseHelper._(); // Constructor privat, hanya dipakai untuk singleton
  static final DatabaseHelper instance = DatabaseHelper._(); // Satu-satunya instance di seluruh aplikasi

  static const String _namaBerkas = 'modio.db'; // Nama berkas basis data
  static const int _versi = 2; // Nomor versi skema saat ini

  Database? _db; // Koneksi basis data, null sebelum pertama kali dibuka

  Future<Database> get database async => _db ??= await _buka(); // Buka sekali saja, pakai ulang selanjutnya

  Future<Database> _buka() async {
    final String jalur = p.join(await getDatabasesPath(), _namaBerkas); // Gabung folder basis data + nama berkas
    return openDatabase(
      jalur,
      version: _versi,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'), // Aktifkan penegakan foreign key
      onCreate: _buatSkema, // Dipanggil saat basis data dibuat pertama kali
      onUpgrade: _naikkanVersi, // Dipanggil saat versi skema naik
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
    '''); // Buat tabel utama transaksi dengan aturan validasi kolom

    await db.execute('''
      CREATE INDEX idx_transaksi_waktu
        ON transaksi (deleted_at, occurred_at DESC)
    '''); // Indeks agar query berdasar waktu & status hapus cepat

    await db.execute('''
      CREATE TABLE kategori (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        nama  TEXT NOT NULL,
        type  TEXT NOT NULL CHECK (type IN ('masuk','keluar')),
        UNIQUE (nama, type)
      )
    '''); // Buat tabel kategori, nama+type harus unik bersama

    await db.execute('''
      CREATE TABLE pengaturan (
        kunci TEXT PRIMARY KEY,
        nilai TEXT NOT NULL
      )
    '''); // Buat tabel pengaturan gaya kunci-nilai

    await _isiDataAwal(db); // Isi kategori bawaan dan saldo awal
  }

  Future<void> _isiDataAwal(Database db) async {
    final Batch batch = db.batch(); // Kumpulkan banyak perintah jadi satu batch untuk efisiensi

    const List<List<String>> kategoriBawaan = [ // Daftar kategori default: [nama, jenis]
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

    for (final k in kategoriBawaan) { // Tambahkan tiap kategori bawaan ke batch
      batch.insert('kategori', {'nama': k[0], 'type': k[1]});
    }

    batch.insert('pengaturan', {'kunci': 'saldo_awal', 'nilai': '0'}); // Saldo awal default 0

    await batch.commit(noResult: true); // Jalankan semua perintah batch sekaligus
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
    if (lama < 2) { // Migrasi ini hanya berlaku dari versi sebelum 2
      await db.transaction((txn) async { // Semua langkah dijalankan sebagai satu transaksi atomik
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
        '''); // Buat tabel baru dengan skema terbaru
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
        '''); // Salin semua data lama ke tabel baru
        await txn.execute('DROP TABLE transaksi'); // Hapus tabel lama
        await txn.execute('ALTER TABLE transaksi_baru RENAME TO transaksi'); // Ganti nama jadi tabel utama
        await txn.execute('''
          CREATE INDEX idx_transaksi_waktu
            ON transaksi (deleted_at, occurred_at DESC)
        '''); // Buat ulang indeks pada tabel baru

        final List<Map<String, Object?>> saldoLama = await txn.query( // Ambil dua baris saldo awal versi lama
          'pengaturan',
          where: 'kunci IN (?, ?)',
          whereArgs: ['saldo_awal_usaha', 'saldo_awal_organisasi'],
        );
        final int saldoAwal = saldoLama.fold<int>(0, (total, item) { // Jumlahkan kedua saldo lama jadi satu
          return total + (int.tryParse(item['nilai'] as String) ?? 0);
        });
        await txn.insert(
          'pengaturan',
          {'kunci': 'saldo_awal', 'nilai': saldoAwal.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace, // Timpa bila kunci sudah ada
        ); // Simpan saldo awal gabungan dengan kunci baru
        await txn.delete(
          'pengaturan',
          where: 'kunci IN (?, ?, ?)',
          whereArgs: [
            'mode_aktif',
            'saldo_awal_usaha',
            'saldo_awal_organisasi',
          ],
        ); // Bersihkan kunci pengaturan lama yang sudah tidak dipakai
      });
    }
  }

  Future<void> tutup() async {
    await _db?.close(); // Tutup koneksi bila sedang terbuka
    _db = null; // Reset agar dibuka ulang saat diakses lagi
  }

  /// Menghapus seluruh isi basis data. Untuk pengujian saja.
  Future<void> resetUntukUji() async {
    final Database db = await database;
    await db.delete('transaksi'); // Hapus semua baris di tabel transaksi
  }
}
