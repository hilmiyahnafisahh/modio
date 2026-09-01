import 'dart:math';

/// ULID: pengenal unik 26 karakter yang dibuat di perangkat.
///
/// Dipakai sejak sekarang meski server belum ada. Alasannya: kalau id
/// memakai angka berurutan dari basis data, perangkat tidak bisa
/// membuat id sebelum server merespons — dan seluruh kemampuan mencatat
/// tanpa koneksi runtuh. Mengganti tipe id setelah ada data pengguna
/// jauh lebih mahal daripada memakainya sejak awal.
///
/// Sepuluh karakter pertama adalah waktu, sehingga ULID urut secara
/// kronologis saat diurutkan sebagai teks biasa. Ini yang membuat
/// paginasi riwayat bisa memakai `id < ...` tanpa mengurutkan kolom waktu.
class Ulid {
  Ulid._();

  static const String _abjad = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static final Random _acak = Random.secure();

  static String generate() {
    int waktu = DateTime.now().toUtc().millisecondsSinceEpoch;
    final List<String> hasil = List<String>.filled(26, '0');

    for (int i = 9; i >= 0; i--) {
      hasil[i] = _abjad[waktu % 32];
      waktu ~/= 32;
    }
    for (int i = 10; i < 26; i++) {
      hasil[i] = _abjad[_acak.nextInt(32)];
    }
    return hasil.join();
  }
}
