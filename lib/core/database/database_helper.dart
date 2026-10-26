import 'package:path/path.dart' as p; // Utilitas gabung path file
import 'package:sqflite/sqflite.dart'; // Paket basis data SQLite untuk Flutter

import '../akuntansi/coa.dart'; // Bagan akun bawaan & aturan migrasi kategori

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
  static const int _versi = 4; // Nomor versi skema saat ini (3: kategori = akun COA, 4: akun Konsumsi)

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
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        nama      TEXT NOT NULL,
        type      TEXT NOT NULL CHECK (type IN ('masuk','keluar')),
        kode      TEXT,
        kelompok  TEXT NOT NULL DEFAULT '',
        UNIQUE (nama, type)
      )
    '''); // Buat tabel kategori (= akun COA), nama+type harus unik bersama

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

    for (final AkunBawaan a in akunBawaan) { // Tambahkan tiap akun COA bawaan ke batch
      batch.insert('kategori', {
        'nama': a.nama,
        'type': a.type,
        'kode': a.kode,
        'kelompok': a.kelompok.kode,
      });
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

    if (lama < 3) { // Versi 3: kategori menjadi akun COA (SAK EMKM)
      await db.transaction((txn) async {
        await txn.execute('ALTER TABLE kategori ADD COLUMN kode TEXT');
        await txn.execute(
          "ALTER TABLE kategori ADD COLUMN kelompok TEXT NOT NULL DEFAULT ''",
        );

        // Ganti nama kategori bawaan lama, di tabel kategori DAN di
        // setiap transaksi yang memakainya (transaksi menyimpan nama
        // kategori sebagai teks). UPDATE OR IGNORE + DELETE menangani
        // pengguna yang kebetulan sudah membuat kategori dengan nama
        // baru itu sendiri: barisnya digabung, bukan bentrok UNIQUE.
        for (final (String lamaNama, String type, String baru)
            in gantiNamaKategoriLama) {
          await txn.rawUpdate(
            'UPDATE OR IGNORE kategori SET nama = ? WHERE nama = ? AND type = ?',
            [baru, lamaNama, type],
          );
          await txn.delete(
            'kategori',
            where: 'nama = ? AND type = ?',
            whereArgs: [lamaNama, type],
          );
          await txn.update(
            'transaksi',
            {'kategori': baru},
            where: 'kategori = ? AND type = ?',
            whereArgs: [lamaNama, type],
          );
        }

        await _pastikanAkunBawaan(txn);

        for (final (String nama, String type, KelompokAkun kelompok)
            in kelompokKategoriLama) {
          await txn.update(
            'kategori',
            {'kelompok': kelompok.kode},
            where: 'nama = ? AND type = ?',
            whereArgs: [nama, type],
          );
        }

        // Sisa kategori buatan pengguna diberi kelompok bawaan per jenis.
        for (final String type in ['masuk', 'keluar']) {
          await txn.update(
            'kategori',
            {
              'kelompok':
                  KelompokAkun.bawaanUntuk(masuk: type == 'masuk').kode,
            },
            where: "kelompok = '' AND type = ?",
            whereArgs: [type],
          );
        }
      });
    }

    if (lama < 4) { // Versi 4: akun baru 6-108 Konsumsi
      await db.transaction(_pastikanAkunBawaan);
    }
  }

  /// Memastikan semua akun bawaan ada, lalu mengisi kode & kelompoknya.
  /// Aman dijalankan berulang; dipakai setiap kali bagan akun bertambah.
  /// Kategori buatan pengguna yang kebetulan bernama sama dengan akun
  /// baru ikut diberi kode & kelompok akun itu.
  Future<void> _pastikanAkunBawaan(DatabaseExecutor txn) async {
    for (final AkunBawaan a in akunBawaan) {
      await txn.insert(
        'kategori',
        {'nama': a.nama, 'type': a.type},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await txn.update(
        'kategori',
        {'kode': a.kode, 'kelompok': a.kelompok.kode},
        where: 'nama = ? AND type = ?',
        whereArgs: [a.nama, a.type],
      );
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
