import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// ─────────────────────────────────────────────────────────────────
/// THEME CONTROLLER  –  Pengendali mode tampilan (terang/gelap/sistem)
///
/// Memakai ValueNotifier karena sakelar berada di halaman Profil,
/// sedangkan MaterialApp yang menentukan tema berada di main.dart.
/// Keduanya berjauhan di pohon widget, sehingga setState pada halaman
/// Profil tidak akan menjangkau MaterialApp.
/// ─────────────────────────────────────────────────────────────────
class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Nilai yang didengarkan MaterialApp
  final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  static const String _kunci = 'mode_tampilan';

  /// Dipanggil sekali saat aplikasi mulai
  Future<void> muat() async {
    final db = await DatabaseHelper.instance.database;
    final hasil = await db.query(
      'pengaturan',
      where: 'kunci = ?',
      whereArgs: [_kunci],
      limit: 1,
    );

    if (hasil.isEmpty) return;

    mode.value = switch (hasil.first['nilai']) {
      'terang' => ThemeMode.light,
      'gelap' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> ganti(ThemeMode baru) async {
    mode.value = baru;

    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'pengaturan',
      {
        'kunci': _kunci,
        'nilai': switch (baru) {
          ThemeMode.light => 'terang',
          ThemeMode.dark => 'gelap',
          ThemeMode.system => 'sistem',
        },
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String label(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Mode terang',
        ThemeMode.dark => 'Mode gelap',
        ThemeMode.system => 'Ikuti pengaturan ponsel',
      };
}
