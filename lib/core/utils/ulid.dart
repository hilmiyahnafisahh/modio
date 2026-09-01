import 'dart:math'; // Untuk Random.secure() pembuat karakter acak

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
class Ulid { // Pembuat pengenal unik ULID
  Ulid._(); // Konstruktor privat, kelas ini hanya wadah statis

  static const String _abjad = '0123456789ABCDEFGHJKMNPQRSTVWXYZ'; // Kumpulan karakter valid untuk ULID (base32)
  static final Random _acak = Random.secure(); // Generator angka acak yang aman secara kriptografi

  static String generate() { // Hasilkan satu ULID baru
    int waktu = DateTime.now().toUtc().millisecondsSinceEpoch; // Waktu sekarang dalam milidetik sejak epoch
    final List<String> hasil = List<String>.filled(26, '0'); // Wadah 26 karakter hasil, awalnya diisi '0'

    for (int i = 9; i >= 0; i--) { // Isi 10 karakter pertama dari komponen waktu, dari belakang
      hasil[i] = _abjad[waktu % 32]; // Ambil sisa bagi 32 sebagai indeks karakter
      waktu ~/= 32; // Geser waktu ke digit base32 berikutnya
    }
    for (int i = 10; i < 26; i++) { // Isi 16 karakter sisanya dengan karakter acak
      hasil[i] = _abjad[_acak.nextInt(32)]; // Pilih karakter acak dari abjad
    }
    return hasil.join(); // Gabungkan seluruh karakter menjadi satu teks ULID
  }
}
