import 'package:flutter/material.dart'; // Import Flutter untuk ValueNotifier & kelas dasar UI
import 'package:sqflite/sqflite.dart'; // Import driver database SQLite

import '../database/database_helper.dart'; // Helper untuk membuka koneksi database aplikasi

/// ─────────────────────────────────────────────────────────────────
/// KEAMANAN CONTROLLER  –  Pengaturan PIN, Mode Suara & Autentikasi
/// Biometrik.
///
/// AuthRepository tetap menyimpan PIN itu sendiri — sakelar [pinAktif]
/// di sini hanya menentukan apakah layar kunci PIN ditampilkan setiap
/// aplikasi dibuka, bukan menghapus PIN yang tersimpan. Sisanya adalah
/// metode TAMBAHAN yang ditawarkan di layar kunci di samping PIN:
///   - Mode Suara aktif  → pengguna boleh mengeja PIN lewat ucapan,
///     selain mengetik di keypad, DAN tombol mikrofon pencatat
///     transaksi di halaman lain (Beranda/Riwayat/Laporan/Profil)
///     ikut aktif — mati berarti kedua-duanya nonaktif sekaligus.
///   - Biometrik aktif   → pengguna boleh memakai sidik jari/wajah
///     bawaan perangkat sebagai jalan pintas, tanpa mengetik PIN sama
///     sekali.
/// Keamanan yang tersedia jadi mengikuti sakelar mana yang menyala —
/// bukan dipatok selalu satu cara saja.
/// ─────────────────────────────────────────────────────────────────
class KeamananController { // Kelas pengatur metode masuk tambahan di layar kunci
  KeamananController._(); // Constructor privat agar hanya bisa dibuat dari dalam kelas ini sendiri
  static final KeamananController instance = KeamananController._(); // Instance tunggal (singleton) yang dipakai di seluruh aplikasi

  // Default aktif: sebelum sakelar ini ada, PIN dan fitur suara selalu
  // menyala buat semua pengguna — default true menjaga perilaku lama
  // itu untuk siapa pun yang belum pernah menyentuh sakelarnya.
  final ValueNotifier<bool> pinAktif = ValueNotifier<bool>(true); // Status apakah layar kunci PIN ditampilkan saat aplikasi dibuka
  final ValueNotifier<bool> suaraAktif = ValueNotifier<bool>(true); // Status aktif/tidaknya fitur suara (PIN & catat transaksi)
  final ValueNotifier<bool> biometrikAktif = ValueNotifier<bool>(false); // Status aktif/tidaknya masuk lewat biometrik, default mati

  /// Fitur sidik jari masih dalam pengembangan, jadi dimatikan sementara:
  /// tombol Sidik Jari di layar kunci dan sakelar Autentikasi Biometrik
  /// di Profil disembunyikan, apa pun nilai [biometrikAktif] yang
  /// tersimpan. Ubah ke true begitu fiturnya siap dipakai.
  static const bool biometrikTersedia = false;

  static const String _kPin = 'keamanan_pin_aktif'; // Kunci penyimpanan untuk opsi kunci PIN
  static const String _kSuara = 'keamanan_mode_suara'; // Kunci penyimpanan untuk opsi mode suara
  static const String _kBiometrik = 'keamanan_biometrik'; // Kunci penyimpanan untuk opsi biometrik

  Future<Database> get _db async => DatabaseHelper.instance.database; // Getter singkat untuk mengambil koneksi database

  Future<void> muat() async { // Memuat nilai pengaturan keamanan dari database
    final Database db = await _db; // Membuka/menunggu koneksi database
    final List<Map<String, Object?>> baris = await db.query( // Mengambil semua baris pengaturan yang kuncinya cocok
      'pengaturan', // Nama tabel yang dibaca
      where: 'kunci IN (?, ?, ?)', // Filter: hanya baris dengan salah satu dari 3 kunci ini
      whereArgs: [_kPin, _kSuara, _kBiometrik], // Nilai pengganti tanda tanya di atas
    );
    for (final Map<String, Object?> row in baris) { // Ulangi setiap baris hasil query
      final bool aktif = row['nilai'] == '1'; // Nilai '1' berarti opsi aktif (true), selain itu nonaktif
      switch (row['kunci']) { // Periksa kunci baris ini untuk tahu opsi mana yang diperbarui
        case _kPin: // Jika kunci cocok dengan kunci PIN
          pinAktif.value = aktif; // Perbarui nilai notifier kunci PIN
        case _kSuara: // Jika kunci cocok dengan mode suara
          suaraAktif.value = aktif; // Perbarui nilai notifier mode suara
        case _kBiometrik: // Jika kunci cocok dengan biometrik
          biometrikAktif.value = aktif; // Perbarui nilai notifier biometrik
      }
    }
  }

  Future<void> _simpan(String kunci, bool nilai) async { // Fungsi bantu privat untuk menyimpan satu pasangan kunci-nilai
    final Database db = await _db; // Membuka/menunggu koneksi database
    await db.insert( // Menyisipkan (atau menimpa) baris pengaturan
      'pengaturan', // Nama tabel tujuan
      {'kunci': kunci, 'nilai': nilai ? '1' : '0'}, // Data yang disimpan: kunci dan nilai boolean diubah jadi string '1'/'0'
      conflictAlgorithm: ConflictAlgorithm.replace, // Jika kunci sudah ada, timpa dengan nilai baru
    );
  }

  Future<void> ubahPin(bool v) async { // Mengubah dan menyimpan opsi kunci PIN
    pinAktif.value = v; // Perbarui nilai notifier agar UI langsung ikut berubah
    await _simpan(_kPin, v); // Simpan nilai baru ke database agar tidak hilang
  }

  Future<void> ubahSuara(bool v) async { // Mengubah dan menyimpan opsi mode suara
    suaraAktif.value = v; // Perbarui nilai notifier agar UI langsung ikut berubah
    await _simpan(_kSuara, v); // Simpan nilai baru ke database agar tidak hilang
  }

  Future<void> ubahBiometrik(bool v) async { // Mengubah dan menyimpan opsi biometrik
    biometrikAktif.value = v; // Perbarui nilai notifier
    await _simpan(_kBiometrik, v); // Simpan nilai baru ke database
  }
}
