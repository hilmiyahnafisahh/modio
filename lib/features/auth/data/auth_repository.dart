import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';

/// ─────────────────────────────────────────────────────────────────
/// AUTH REPOSITORY  –  Penyimpanan dan verifikasi PIN
///
/// PIN tidak pernah disimpan apa adanya. Yang tersimpan adalah hasil
/// pengacakan searah beserta garamnya, sehingga isi basis data yang
/// bocor tidak langsung membuka akun.
///
/// Seluruh verifikasi berjalan di perangkat, tanpa memanggil server.
/// Pengguna tetap dapat masuk ke aplikasinya tanpa koneksi internet.
/// ─────────────────────────────────────────────────────────────────

class AuthRepository {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  Future<Database> get _db async => DatabaseHelper.instance.database;

  static const String _kunciHash = 'pin_hash';
  static const String _kunciGaram = 'pin_salt';
  static const String _kunciGagal = 'pin_failed_attempts';
  static const String _kunciKunciSampai = 'pin_locked_until';
  static const String _kunciBiometrik = 'biometrik_aktif';

  /// Batas percobaan sebelum aplikasi dikunci sementara.
  ///
  /// PIN enam angka hanya punya satu juta kombinasi. Tanpa pembatasan,
  /// seluruh kemungkinan dapat dicoba oleh siapa pun yang memegang
  /// perangkat dalam waktu yang tidak lama.
  static const int maksPercobaan = 5;
  static const int menitPenguncian = 5;

  // ── Status ────────────────────────────────────────────────────────

  Future<bool> sudahAdaPin() async {
    return await _ambil(_kunciHash) != null;
  }

  /// Sisa detik penguncian. Nol berarti tidak sedang terkunci.
  Future<int> sisaPenguncian() async {
    final String? sampai = await _ambil(_kunciKunciSampai);
    if (sampai == null) return 0;

    final DateTime batas = DateTime.parse(sampai);
    final int sisa = batas.difference(DateTime.now().toUtc()).inSeconds;
    return sisa > 0 ? sisa : 0;
  }

  Future<int> sisaPercobaan() async {
    final int gagal = int.tryParse(await _ambil(_kunciGagal) ?? '0') ?? 0;
    final int sisa = maksPercobaan - gagal;
    return sisa > 0 ? sisa : 0;
  }

  // ── Verifikasi dan penyimpanan ────────────────────────────────────

  Future<bool> verifikasiPin(String pin) async {
    final String? hash = await _ambil(_kunciHash);
    final String? garam = await _ambil(_kunciGaram);
    if (hash == null || garam == null) return false;

    final bool cocok = _hash(pin, garam) == hash;

    if (cocok) {
      await _simpan(_kunciGagal, '0');
      await _hapus(_kunciKunciSampai);
    } else {
      final int gagal =
          (int.tryParse(await _ambil(_kunciGagal) ?? '0') ?? 0) + 1;

      if (gagal >= maksPercobaan) {
        await _simpan(_kunciGagal, '0');
        await _simpan(
          _kunciKunciSampai,
          DateTime.now()
              .toUtc()
              .add(const Duration(minutes: menitPenguncian))
              .toIso8601String(),
        );
      } else {
        await _simpan(_kunciGagal, '$gagal');
      }
    }

    return cocok;
  }

  Future<void> simpanPin(String pin) async {
    final String garam = _buatGaram();
    await _simpan(_kunciGaram, garam);
    await _simpan(_kunciHash, _hash(pin, garam));
    await _simpan(_kunciGagal, '0');
    await _hapus(_kunciKunciSampai);
  }

  /// PIN yang terlalu mudah ditebak ditolak.
  ///
  /// Sebagian kecil kombinasi menutup persentase besar dari PIN yang
  /// dipakai orang di dunia nyata, sehingga menebaknya tidak
  /// memerlukan pencobaan sistematis.
  static const List<String> _pinLemah = [
    '123456', '000000', '111111', '222222', '333333', '444444',
    '555555', '666666', '777777', '888888', '999999',
    '123123', '112233', '654321', '121212', '098765', '696969',
  ];

  /// Mengembalikan pesan galat, atau null bila PIN dapat diterima.
  String? periksaKekuatan(String pin) {
    if (pin.length != 6) return 'PIN harus enam angka.';
    if (_pinLemah.contains(pin)) {
      return 'PIN ini terlalu mudah ditebak. Pilih enam angka lain.';
    }

    // Urutan naik atau turun, misalnya 456789 atau 987654
    bool naik = true;
    bool turun = true;
    for (int i = 1; i < pin.length; i++) {
      final int selisih = pin.codeUnitAt(i) - pin.codeUnitAt(i - 1);
      if (selisih != 1) naik = false;
      if (selisih != -1) turun = false;
    }
    if (naik || turun) {
      return 'PIN berurutan mudah ditebak. Pilih enam angka lain.';
    }

    return null;
  }

  // ── Biometrik ─────────────────────────────────────────────────────

  Future<bool> biometrikAktif() async =>
      await _ambil(_kunciBiometrik) == '1';

  Future<void> setBiometrik(bool aktif) =>
      _simpan(_kunciBiometrik, aktif ? '1' : '0');

  // ── Internal ──────────────────────────────────────────────────────

  String _buatGaram() {
    final Random acak = Random.secure();
    final List<int> byte = List<int>.generate(16, (_) => acak.nextInt(256));
    return base64Url.encode(byte);
  }

  String _hash(String pin, String garam) {
    return sha256.convert(utf8.encode('$garam$pin')).toString();
  }

  Future<String?> _ambil(String kunci) async {
    final Database db = await _db;
    final List<Map<String, Object?>> baris = await db.query(
      'pengaturan',
      where: 'kunci = ?',
      whereArgs: [kunci],
      limit: 1,
    );
    return baris.isEmpty ? null : baris.first['nilai'] as String;
  }

  Future<void> _simpan(String kunci, String nilai) async {
    final Database db = await _db;
    await db.insert(
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _hapus(String kunci) async {
    final Database db = await _db;
    await db.delete('pengaturan', where: 'kunci = ?', whereArgs: [kunci]);
  }
}
