import 'package:flutter/material.dart'; // Untuk ThemeMode dan ValueNotifier
import 'package:sqflite/sqflite.dart'; // Untuk akses basis data SQLite

import '../database/database_helper.dart'; // Helper koneksi database aplikasi

/// ─────────────────────────────────────────────────────────────────
/// THEME CONTROLLER  –  Pengendali mode tampilan (terang/gelap/sistem)
///
/// Memakai ValueNotifier karena sakelar berada di halaman Profil,
/// sedangkan MaterialApp yang menentukan tema berada di main.dart.
/// Keduanya berjauhan di pohon widget, sehingga setState pada halaman
/// Profil tidak akan menjangkau MaterialApp.
/// ─────────────────────────────────────────────────────────────────
class ThemeController { // Pengendali mode tema aplikasi (singleton)
  ThemeController._(); // Konstruktor privat untuk pola singleton
  static final ThemeController instance = ThemeController._(); // Satu-satunya instance controller

  /// Nilai yang didengarkan MaterialApp
  final ValueNotifier<ThemeMode> mode = // Mode tema aktif, bisa didengarkan perubahannya
      ValueNotifier<ThemeMode>(ThemeMode.system); // Default mengikuti pengaturan sistem

  static const String _kunci = 'mode_tampilan'; // Kunci penyimpanan mode tema di database

  /// Dipanggil sekali saat aplikasi mulai
  Future<void> muat() async { // Muat mode tema tersimpan dari database
    final db = await DatabaseHelper.instance.database; // Ambil koneksi database
    final hasil = await db.query( // Query nilai mode tema tersimpan
      'pengaturan',
      where: 'kunci = ?', // Filter berdasarkan kolom kunci
      whereArgs: [_kunci], // Nilai kunci yang dicari
      limit: 1, // Ambil maksimal satu baris
    );

    if (hasil.isEmpty) return; // Belum ada pengaturan tersimpan, pakai default

    mode.value = switch (hasil.first['nilai']) { // Terjemahkan teks tersimpan menjadi ThemeMode
      'terang' => ThemeMode.light,
      'gelap' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> ganti(ThemeMode baru) async { // Ubah dan simpan mode tema baru
    mode.value = baru; // Perbarui nilai agar UI langsung berubah

    final db = await DatabaseHelper.instance.database; // Ambil koneksi database
    await db.insert( // Simpan mode tema baru ke database
      'pengaturan',
      {
        'kunci': _kunci,
        'nilai': switch (baru) { // Terjemahkan ThemeMode menjadi teks tersimpan
          ThemeMode.light => 'terang',
          ThemeMode.dark => 'gelap',
          ThemeMode.system => 'sistem',
        },
      },
      conflictAlgorithm: ConflictAlgorithm.replace, // Timpa data lama jika kunci sudah ada
    );
  }

  String label(ThemeMode m) => switch (m) { // Teks label yang ditampilkan untuk tiap mode
        ThemeMode.light => 'Mode terang',
        ThemeMode.dark => 'Mode gelap',
        ThemeMode.system => 'Ikuti pengaturan ponsel',
      };
}
