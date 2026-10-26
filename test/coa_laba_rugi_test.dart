import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:modio/core/akuntansi/coa.dart';
import 'package:modio/core/database/database_helper.dart';
import 'package:modio/features/reports/data/laporan_repository.dart';

/// Menguji migrasi kategori lama ke bagan akun (COA) dan susunan
/// laporan laba rugi SAK EMKM, memakai SQLite asli di komputer.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String jalur;

  setUp(() async {
    await DatabaseHelper.instance.tutup();
    jalur = p.join(await getDatabasesPath(), 'modio.db');
    await deleteDatabase(jalur);
  });

  tearDown(() => DatabaseHelper.instance.tutup());

  String utc(int bulan, int hari) =>
      DateTime(2026, bulan, hari, 12).toUtc().toIso8601String();

  test('pengguna baru mendapat seluruh akun bawaan beserta kode & kelompok', () async {
    final db = await DatabaseHelper.instance.database;
    final baris = await db.query('kategori', orderBy: 'id');

    expect(baris.length, akunBawaan.length);
    expect(baris.every((b) => (b['kode'] as String?)?.isNotEmpty ?? false), isTrue);
    expect(
      baris.firstWhere((b) => b['nama'] == 'Pemeliharaan dan Perbaikan')['kelompok'],
      'beban_usaha',
    );
  });

  test('HP versi lama: kategori dimigrasi & laba rugi sesuai SAK EMKM', () async {
    // ── Siapkan basis data versi 2 persis seperti di HP pengguna lama ──
    final lama = await openDatabase(
      jalur,
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE transaksi (
            id TEXT PRIMARY KEY, title TEXT NOT NULL,
            nominal INTEGER NOT NULL CHECK (nominal > 0), method TEXT NOT NULL,
            kategori TEXT NOT NULL DEFAULT 'Lainnya',
            type TEXT NOT NULL CHECK (type IN ('masuk','keluar')),
            catatan TEXT, sumber_input TEXT NOT NULL DEFAULT 'manual',
            occurred_at TEXT NOT NULL, created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL, deleted_at TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending')
        ''');
        await db.execute('''
          CREATE TABLE kategori (
            id INTEGER PRIMARY KEY AUTOINCREMENT, nama TEXT NOT NULL,
            type TEXT NOT NULL CHECK (type IN ('masuk','keluar')),
            UNIQUE (nama, type))
        ''');
        await db.execute(
          'CREATE TABLE pengaturan (kunci TEXT PRIMARY KEY, nilai TEXT NOT NULL)',
        );
      },
    );
    for (final k in [
      ['Penjualan', 'masuk'], ['Jasa', 'masuk'], ['Iuran Anggota', 'masuk'],
      ['Donasi', 'masuk'], ['Modal Masuk', 'masuk'], ['Pemasukan Lain', 'masuk'],
      ['Bahan Baku', 'keluar'], ['Transportasi', 'keluar'], ['Gaji', 'keluar'],
      ['Sewa', 'keluar'], ['Listrik dan Air', 'keluar'], ['Peralatan', 'keluar'],
      ['Kegiatan', 'keluar'], ['Pengeluaran Lain', 'keluar'],
      // Kategori buatan pengguna, termasuk satu yang namanya kebetulan
      // sama dengan akun baru (harus digabung, bukan bentrok).
      ['Kerajinan', 'masuk'], ['Kopi Tamu', 'keluar'],
      ['Transportasi dan Pengiriman', 'keluar'],
    ]) {
      await lama.insert('kategori', {'nama': k[0], 'type': k[1]});
    }
    var n = 0;
    Future<void> trx(String kategori, String type, int nominal, {int bulan = 10}) =>
        lama.insert('transaksi', {
          'id': 'T${n++}', 'title': kategori, 'nominal': nominal,
          'method': 'tunai', 'kategori': kategori, 'type': type,
          'occurred_at': utc(bulan, 15), 'created_at': utc(bulan, 15),
          'updated_at': utc(bulan, 15),
        });
    await trx('Penjualan', 'masuk', 1000000);
    await trx('Jasa', 'masuk', 200000);
    await trx('Kerajinan', 'masuk', 30000);
    await trx('Modal Masuk', 'masuk', 5000000);
    await trx('Donasi', 'masuk', 100000);
    await trx('Bahan Baku', 'keluar', 400000);
    await trx('Gaji', 'keluar', 300000);
    await trx('Peralatan', 'keluar', 50000);
    await trx('Kegiatan', 'keluar', 20000);
    await trx('Kopi Tamu', 'keluar', 10000);
    await trx('Transportasi', 'keluar', 25000);
    await trx('Penjualan', 'masuk', 500000, bulan: 9); // bulan lalu
    await lama.close();

    // ── Buka dengan aplikasi versi baru → migrasi ke versi 3 ──
    final db = await DatabaseHelper.instance.database;

    final namaKategori = (await db.query('kategori')).map((b) => b['nama']).toSet();
    expect(namaKategori, isNot(contains('Jasa')));
    expect(namaKategori, isNot(contains('Modal Masuk')));
    expect(namaKategori, containsAll(akunBawaan.map((a) => a.nama)));
    final transportasi = await db.query('kategori',
        where: 'nama = ?', whereArgs: ['Transportasi dan Pengiriman']);
    expect(transportasi.length, 1);
    expect(transportasi.first['kode'], '6-104');
    final konsumsi = await db.query('kategori',
        where: 'nama = ?', whereArgs: ['Konsumsi']);
    expect(konsumsi.single['kode'], '6-108'); // akun baru versi 4
    expect(konsumsi.single['kelompok'], 'beban_usaha');
    expect(
      (await db.query('kategori', where: 'nama = ?', whereArgs: ['Kopi Tamu']))
          .first['kelompok'],
      'beban_usaha',
    );
    final kategoriTransaksi =
        (await db.query('transaksi')).map((b) => b['kategori']).toSet();
    expect(kategoriTransaksi, containsAll(['Pendapatan Jasa', 'Modal Pemilik', 'Gaji dan Upah', 'Perlengkapan']));

    // ── Laporan laba rugi Oktober ──
    final l = await LaporanRepository().laporanBulan(tahun: 2026, bulan: 10);
    expect(l.pendapatanUsaha, 1230000); // penjualan + jasa + kerajinan
    expect(l.hargaPokok, 400000);
    expect(l.labaKotor, 830000);
    expect(l.bebanUsaha, 405000); // gaji + perlengkapan + kegiatan + kopi + transportasi
    expect(l.labaUsaha, 425000);
    expect(l.pendapatanLain, 100000); // donasi
    expect(l.labaBersih, 525000);
    // Modal 5 juta TIDAK dihitung sebagai pendapatan.
    expect(l.diLuarLabaRugi.single.nama, 'Modal Pemilik');
    expect(l.totalPendapatan, 1330000);
    expect(l.pendapatanBulanLalu, 500000);
    expect(l.narasi, contains('Laba bersih'));
    expect(l.narasi, contains('Di luar laba rugi: Modal Pemilik'));
  });
}
