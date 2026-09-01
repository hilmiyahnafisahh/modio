import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

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
class AksesibilitasController {
  AksesibilitasController._();
  static final AksesibilitasController instance = AksesibilitasController._();

  final ValueNotifier<bool> kontrasTinggi = ValueNotifier<bool>(false);
  final ValueNotifier<bool> teksTebal = ValueNotifier<bool>(false);
  final ValueNotifier<bool> getaran = ValueNotifier<bool>(true);
  final ValueNotifier<bool> kurangiAnimasi = ValueNotifier<bool>(false);

  static const String _kKontrasTinggi = 'aksesibilitas_kontras_tinggi';
  static const String _kTeksTebal = 'aksesibilitas_teks_tebal';
  static const String _kGetaran = 'aksesibilitas_getaran';
  static const String _kKurangiAnimasi = 'aksesibilitas_kurangi_animasi';

  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<void> muat() async {
    final Database db = await _db;
    final List<Map<String, Object?>> baris = await db.query(
      'pengaturan',
      where: 'kunci IN (?, ?, ?, ?)',
      whereArgs: [_kKontrasTinggi, _kTeksTebal, _kGetaran, _kKurangiAnimasi],
    );
    for (final Map<String, Object?> row in baris) {
      final bool aktif = row['nilai'] == '1';
      switch (row['kunci']) {
        case _kKontrasTinggi:
          kontrasTinggi.value = aktif;
        case _kTeksTebal:
          teksTebal.value = aktif;
        case _kGetaran:
          getaran.value = aktif;
        case _kKurangiAnimasi:
          kurangiAnimasi.value = aktif;
      }
    }
  }

  Future<void> _simpan(String kunci, bool nilai) async {
    final Database db = await _db;
    await db.insert(
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> ubahKontrasTinggi(bool v) async {
    kontrasTinggi.value = v;
    await _simpan(_kKontrasTinggi, v);
  }

  Future<void> ubahTeksTebal(bool v) async {
    teksTebal.value = v;
    await _simpan(_kTeksTebal, v);
  }

  Future<void> ubahGetaran(bool v) async {
    getaran.value = v;
    await _simpan(_kGetaran, v);
  }

  Future<void> ubahKurangiAnimasi(bool v) async {
    kurangiAnimasi.value = v;
    await _simpan(_kKurangiAnimasi, v);
  }

  /// Dipanggil dari titik interaksi nyata (keypad PIN, sakelar
  /// pengaturan) — bukan disebar ke setiap tap di seluruh aplikasi,
  /// supaya cakupannya tetap bisa dipertanggungjawabkan.
  void getar() {
    if (getaran.value) HapticFeedback.lightImpact();
  }
}
