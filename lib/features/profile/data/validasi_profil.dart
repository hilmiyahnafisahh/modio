/// Aturan isian profil, dipakai bersama oleh halaman registrasi (langkah 1)
/// dan halaman Informasi Profil supaya keduanya menolak hal yang sama.
library;

// ── Aturan validasi ────────────────────────────────────────────────
// Fungsi publik supaya bisa diuji langsung. Mengembalikan pesan galat
// singkat (disambung setelah nama field), atau null bila valid.

String? validasiWajib(String v) => v.isEmpty ? 'wajib diisi' : null;

final RegExp _polaEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

String? validasiEmail(String v) {
  if (v.isEmpty) return 'wajib diisi';
  if (!_polaEmail.hasMatch(v)) return 'belum benar, contoh nama@gmail.com';
  return null;
}

/// Nomor HP Indonesia: 08…, 628…, atau +628…, 10 sampai 13 digit
/// setelah diawali 0. Spasi dan tanda hubung diabaikan.
String? validasiNoHp(String v) {
  if (v.isEmpty) return 'wajib diisi';
  String angka = v.replaceAll(RegExp(r'[\s-]'), '');
  if (angka.startsWith('+62')) angka = '0${angka.substring(3)}';
  if (angka.startsWith('62')) angka = '0${angka.substring(2)}';
  if (!RegExp(r'^08\d{8,11}$').hasMatch(angka)) {
    return 'belum benar, contoh 0812 3456 7890';
  }
  return null;
}
