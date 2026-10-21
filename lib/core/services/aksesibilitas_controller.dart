import 'package:flutter/material.dart'; // Import Flutter untuk ValueNotifier & kelas dasar UI
import 'package:flutter/services.dart'; // Import untuk fitur getaran (HapticFeedback)
import 'package:sqflite/sqflite.dart'; // Import driver database SQLite

import '../database/database_helper.dart'; // Helper untuk membuka koneksi database aplikasi

/// ─────────────────────────────────────────────────────────────────
/// AKSESIBILITAS CONTROLLER  –  Pengaturan Kontras Tinggi, Teks Tebal,
/// Getaran, dan Kurangi Animasi.
///
/// Pola sama persis dengan ThemeController: ValueNotifier per opsi,
/// disimpan ke tabel `pengaturan`, dimuat sekali saat aplikasi mulai.
/// Empat notifier terpisah (bukan satu objek gabungan) supaya widget
/// yang hanya peduli satu opsi tidak ikut membangun ulang saat opsi
/// lain berubah.
/// ─────────────────────────────────────────────────────────────────
class AksesibilitasController { // Kelas pengatur opsi aksesibilitas seluruh aplikasi
  AksesibilitasController._(); // Constructor privat agar hanya bisa dibuat dari dalam kelas ini sendiri
  static final AksesibilitasController instance = AksesibilitasController._(); // Instance tunggal (singleton) yang dipakai di seluruh aplikasi

  final ValueNotifier<bool> kontrasTinggi = ValueNotifier<bool>(false); // Status aktif/tidaknya mode kontras tinggi, default mati
  final ValueNotifier<bool> teksTebal = ValueNotifier<bool>(false); // Status aktif/tidaknya teks tebal, default mati
  final ValueNotifier<bool> getaran = ValueNotifier<bool>(true); // Status aktif/tidaknya getaran, default menyala
  final ValueNotifier<bool> kurangiAnimasi = ValueNotifier<bool>(false); // Status aktif/tidaknya pengurangan animasi, default mati

  static const String _kKontrasTinggi = 'aksesibilitas_kontras_tinggi'; // Kunci penyimpanan untuk opsi kontras tinggi di tabel pengaturan
  static const String _kTeksTebal = 'aksesibilitas_teks_tebal'; // Kunci penyimpanan untuk opsi teks tebal
  static const String _kGetaran = 'aksesibilitas_getaran'; // Kunci penyimpanan untuk opsi getaran
  static const String _kKurangiAnimasi = 'aksesibilitas_kurangi_animasi'; // Kunci penyimpanan untuk opsi kurangi animasi

  Future<Database> get _db async => DatabaseHelper.instance.database; // Getter singkat untuk mengambil koneksi database

  Future<void> muat() async { // Memuat semua nilai pengaturan aksesibilitas dari database
    final Database db = await _db; // Membuka/menunggu koneksi database
    final List<Map<String, Object?>> baris = await db.query( // Mengambil semua baris pengaturan yang kuncinya cocok
      'pengaturan', // Nama tabel yang dibaca
      where: 'kunci IN (?, ?, ?, ?)', // Filter: hanya baris dengan salah satu dari 4 kunci ini
      whereArgs: [_kKontrasTinggi, _kTeksTebal, _kGetaran, _kKurangiAnimasi], // Nilai pengganti tanda tanya di atas
    );
    for (final Map<String, Object?> row in baris) { // Ulangi setiap baris hasil query
      final bool aktif = row['nilai'] == '1'; // Nilai '1' berarti opsi aktif (true), selain itu nonaktif
      switch (row['kunci']) { // Periksa kunci baris ini untuk tahu opsi mana yang diperbarui
        case _kKontrasTinggi: // Jika kunci cocok dengan kontras tinggi
          kontrasTinggi.value = aktif; // Perbarui nilai notifier kontras tinggi
        case _kTeksTebal: // Jika kunci cocok dengan teks tebal
          teksTebal.value = aktif; // Perbarui nilai notifier teks tebal
        case _kGetaran: // Jika kunci cocok dengan getaran
          getaran.value = aktif; // Perbarui nilai notifier getaran
        case _kKurangiAnimasi: // Jika kunci cocok dengan kurangi animasi
          kurangiAnimasi.value = aktif; // Perbarui nilai notifier kurangi animasi
      }
    }
  }

  Future<void> _simpan(String kunci, bool nilai) async { // Fungsi bantu privat untuk menyimpan satu pasangan kunci-nilai
    final Database db = await _db; // Membuka/menunggu koneksi database
    await db.insert( // Menyisipkan (atau menimpa) baris pengaturan
      'pengaturan', // Nama tabel tujuan
      {'kunci': kunci, 'nilai': nilai ? '1' : '0'}, // Data yang disimpan: kunci dan nilai boolean diubah jadi string '1'/'0'
      conflictAlgorithm: ConflictAlgorithm.replace, // Jika kunci sudah ada, timpa baris lama dengan yang baru
    );
  }

  Future<void> ubahKontrasTinggi(bool v) async { // Mengubah dan menyimpan opsi kontras tinggi
    kontrasTinggi.value = v; // Perbarui nilai notifier agar UI langsung ikut berubah
    await _simpan(_kKontrasTinggi, v); // Simpan nilai baru ke database agar tidak hilang
  }

  Future<void> ubahTeksTebal(bool v) async { // Mengubah dan menyimpan opsi teks tebal
    teksTebal.value = v; // Perbarui nilai notifier
    await _simpan(_kTeksTebal, v); // Simpan nilai baru ke database
  }

  Future<void> ubahGetaran(bool v) async { // Mengubah dan menyimpan opsi getaran
    getaran.value = v; // Perbarui nilai notifier
    await _simpan(_kGetaran, v); // Simpan nilai baru ke database
  }

  Future<void> ubahKurangiAnimasi(bool v) async { // Mengubah dan menyimpan opsi kurangi animasi
    kurangiAnimasi.value = v; // Perbarui nilai notifier
    await _simpan(_kKurangiAnimasi, v); // Simpan nilai baru ke database
  }

  /// Dipanggil dari titik interaksi nyata (keypad PIN, sakelar
  /// pengaturan) — bukan disebar ke setiap tap di seluruh aplikasi,
  /// supaya cakupannya tetap bisa dipertanggungjawabkan.
  void getar() { // Memicu getaran singkat jika opsi getaran aktif
    if (getaran.value) HapticFeedback.lightImpact(); // Getar ringan hanya kalau pengguna mengizinkan getaran
  }

  // ── Pola getaran hasil tindakan ──────────────────────────────────
  // Hanya ada dua pola, dipakai sama persis di seluruh aplikasi:
  //   • Berhasil → 1 getaran pendek
  //   • Gagal    → 2 getaran pendek berturut-turut
  // Pola dibedakan dari JUMLAH getaran, bukan kekuatannya. Beda
  // kekuatan (sedang vs kuat) sulit dirasakan di banyak HP, sedangkan
  // jumlah getaran mudah dihitung. Getaran hanya pelengkap: setiap
  // pemanggil tetap wajib mengumumkan status lewat pembaca layar.

  /// Jeda antar dua getaran pola gagal. Cukup panjang untuk terasa
  /// sebagai dua ketukan terpisah, cukup pendek untuk terasa satu pola.
  static const Duration jedaPolaGagal = Duration(milliseconds: 180);

  /// Tindakan berhasil (PIN benar, transaksi tersimpan, dsb).
  void getarBerhasil() { // 1 getaran pendek
    if (getaran.value) HapticFeedback.mediumImpact();
  }

  /// Tindakan gagal atau input tidak valid.
  Future<void> getarGagal() async { // 2 getaran pendek berturut-turut
    if (!getaran.value) return; // Hormati sakelar Getaran di pengaturan
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(jedaPolaGagal);
    await HapticFeedback.heavyImpact();
  }
}
