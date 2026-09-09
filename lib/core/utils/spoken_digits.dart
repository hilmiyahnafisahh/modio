/// ─────────────────────────────────────────────────────────────────
/// SPOKEN DIGITS  –  Mengubah ucapan angka jadi deretan digit PIN.
///
/// Dipakai untuk "Masuk dengan Suara" di layar kunci. SENGAJA tidak
/// lewat AI/backend seperti pencatatan transaksi suara — PIN harus
/// tetap bisa diverifikasi tanpa koneksi internet (lihat catatan di
/// PinLockPage), jadi penguraiannya murni pencocokan kata di perangkat.
/// ─────────────────────────────────────────────────────────────────

/// Peta kata angka Bahasa Indonesia ke digitnya. "kosong" turut
/// dipetakan ke nol — sebagian orang menyebut PIN "nol" sebagai
/// "kosong" sehari-hari.
const Map<String, String> _kataAngka = { // Kamus kata angka ke karakter digit
  'nol': '0', 'kosong': '0',
  'satu': '1',
  'dua': '2',
  'tiga': '3',
  'empat': '4',
  'lima': '5',
  'enam': '6',
  'tujuh': '7',
  'delapan': '8',
  'sembilan': '9',
};

/// Mengurai ucapan seperti "tiga tiga empat lima nol satu" atau "334501"
/// (diucapkan sebagai angka gabungan, kadang dikenali speech-to-text
/// sebagai literal digit) menjadi deretan digit PIN 6 karakter.
///
/// Mengembalikan null jika hasilnya bukan tepat 6 digit — pemanggil
/// menganggap itu sebagai gagal kenali, bukan PIN salah, sehingga
/// pesannya bisa dibedakan ("tidak dikenali" vs "PIN salah").
String? uraikanUcapanPin(String ucapan) { // Ubah teks ucapan jadi deretan 6 digit PIN, atau null jika gagal
  final StringBuffer digitHasil = StringBuffer(); // Penampung digit yang berhasil dikenali, berurutan

  for (final String kata in ucapan.toLowerCase().split(RegExp(r'\s+'))) { // Pecah ucapan per kata, huruf kecil semua
    if (kata.isEmpty) continue; // Lewati kalau ada spasi ganda menghasilkan kata kosong

    final String? dariKata = _kataAngka[kata]; // Coba cocokkan kata utuh ke kamus angka
    if (dariKata != null) { // Jika kata ini memang kata angka yang dikenal
      digitHasil.write(dariKata); // Tambahkan digitnya ke hasil
      continue; // Lanjut ke kata berikutnya
    }

    // Bukan kata angka dikenal — mungkin literal digit ("334501") atau
    // gabungan digit+kata yang tak terpisah spasi. Ambil tiap karakter
    // digit yang ada, buang selain itu (mis. tanda baca).
    for (final String ch in kata.split('')) { // Ulangi tiap karakter dalam kata ini
      if (RegExp(r'^[0-9]$').hasMatch(ch)) digitHasil.write(ch); // Simpan kalau karakter ini digit 0-9
    }
  }

  final String hasil = digitHasil.toString(); // Gabungan seluruh digit yang terkumpul
  return hasil.length == 6 ? hasil : null; // Hanya valid kalau tepat 6 digit, sesuai panjang PIN
}
