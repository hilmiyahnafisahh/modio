/// ─────────────────────────────────────────────────────────────────
/// CURRENCY FORMATTER  –  Helper format angka ke format Rupiah
///
/// Dua bentuk keluaran untuk dua indra yang berbeda:
///
///   format(300000)   → 'Rp 300.000'              untuk dilihat
///   spoken(300000)   → 'tiga ratus ribu rupiah'  untuk didengar
///
/// Keduanya diperlukan. TalkBack membaca 'Rp 300.000' sebagai
/// "Rp tiga titik nol nol nol" — deretan digit yang mustahil dipahami
/// sebagai jumlah uang. Setiap widget yang menampilkan nominal wajib
/// memasang spoken() sebagai label semantiknya.
/// ─────────────────────────────────────────────────────────────────
library; // Menandai file ini sebagai library tanpa nama khusus

class CurrencyFormatter {
  CurrencyFormatter._(); // Constructor privat agar class ini tidak bisa di-instantiate

  /// Format angka integer ke format Rupiah penuh
  /// Contoh: 4500000 → 'Rp 4.500.000'
  static String format(int amount) {
    final String raw = amount.abs().toString(); // Ambil nilai absolut lalu ubah jadi teks digit
    final StringBuffer result = StringBuffer(); // Penampung hasil yang sedang dibangun

    int count = 0; // Penghitung berapa digit sudah ditulis
    for (int i = raw.length - 1; i >= 0; i--) { // Loop dari digit paling kanan ke kiri
      if (count > 0 && count % 3 == 0) { // Setiap 3 digit, sisipkan titik ribuan
        result.write('.'); // Tulis titik pemisah ribuan
      }
      result.write(raw[i]); // Tulis digit saat ini (masih terbalik)
      count++; // Tambah penghitung digit
    }

    final String formatted = result.toString().split('').reversed.join(); // Balik urutan agar jadi normal lagi
    final String prefix = amount < 0 ? '-Rp ' : 'Rp '; // Tentukan awalan sesuai tanda negatif/positif
    return '$prefix$formatted'; // Gabungkan awalan dan angka terformat
  }

  /// Format ringkas untuk angka besar
  /// Contoh: 4500000 → 'Rp 4,5 Jt'
  ///
  /// JANGAN dipakai sebagai label semantik. Pembulatan menyembunyikan
  /// selisih yang penting: 'Rp 4,5 Jt' bisa berarti 4.450.000 atau
  /// 4.549.000. Untuk screen reader selalu pakai spoken().
  static String compact(int amount) {
    if (amount >= 1000000000) { // Jika bernilai miliaran ke atas
      return 'Rp ${_removeTrailingZero(amount / 1000000000)} M'; // Tampilkan dalam satuan Miliar
    } else if (amount >= 1000000) { // Jika bernilai jutaan
      return 'Rp ${_removeTrailingZero(amount / 1000000)} Jt'; // Tampilkan dalam satuan Juta
    } else if (amount >= 1000) { // Jika bernilai ribuan
      return 'Rp ${_removeTrailingZero(amount / 1000)} Rb'; // Tampilkan dalam satuan Ribu
    }
    return format(amount); // Di bawah seribu, pakai format penuh biasa
  }

  /// Format terbaca untuk screen reader
  /// Contoh: 4500000 → 'empat juta lima ratus ribu rupiah'
  static String spoken(int amount) {
    if (amount == 0) return 'nol rupiah'; // Kasus khusus nol agar tidak menghasilkan teks kosong

    final bool negatif = amount < 0; // Simpan apakah nilainya negatif
    int sisa = amount.abs(); // Kerja dengan nilai absolut, tanda ditangani terpisah
    final List<String> bagian = []; // Kumpulan potongan kata yang akan digabung

    const Map<int, String> satuan = { // Daftar satuan besar beserta sebutannya
      1000000000: 'miliar',
      1000000: 'juta',
      1000: 'ribu',
    };

    for (final entry in satuan.entries) { // Cek tiap satuan dari besar ke kecil
      if (sisa >= entry.key) { // Jika nilai sisa masih mencakup satuan ini
        bagian.add('${_terbilang(sisa ~/ entry.key)} ${entry.value}'); // Tambahkan kata untuk kelipatan satuan itu
        sisa %= entry.key; // Kurangi sisa dengan bagian yang sudah dipakai
      }
    }
    if (sisa > 0) bagian.add(_terbilang(sisa)); // Tambahkan sisa angka di bawah seribu jika ada

    return '${negatif ? 'minus ' : ''}${bagian.join(' ')} rupiah'; // Gabungkan semua kata jadi satu kalimat
  }

  static const List<String> _angka = [ // Daftar nama angka 0-9 dalam Bahasa Indonesia
    '', 'satu', 'dua', 'tiga', 'empat',
    'lima', 'enam', 'tujuh', 'delapan', 'sembilan',
  ];

  static String _terbilang(int n) { // Mengubah angka (di bawah 1000) jadi kata terucap
    if (n < 10) return _angka[n]; // Angka satuan langsung diambil dari daftar
    if (n == 10) return 'sepuluh'; // Kasus khusus sepuluh
    if (n == 11) return 'sebelas'; // Kasus khusus sebelas
    if (n < 20) return '${_angka[n - 10]} belas'; // Belasan: satuan + "belas"
    if (n < 100) { // Puluhan
      final int sisa = n % 10; // Sisa satuan setelah puluhan
      return '${_angka[n ~/ 10]} puluh${sisa > 0 ? ' ${_angka[sisa]}' : ''}'; // Gabungkan puluhan dan satuan sisa
    }
    if (n < 1000) { // Ratusan
      final String ratus = // Kata untuk bagian ratusan
          n ~/ 100 == 1 ? 'seratus' : '${_angka[n ~/ 100]} ratus'; // "seratus" khusus untuk 1 ratus
      final int sisa = n % 100; // Sisa di bawah seratus
      return '$ratus${sisa > 0 ? ' ${_terbilang(sisa)}' : ''}'; // Gabungkan ratusan dengan sisa terucap (rekursif)
    }
    return n.toString(); // Fallback jika di luar jangkauan yang ditangani
  }

  static String _removeTrailingZero(double value) { // Hilangkan angka desimal ,0 yang tidak perlu
    if (value == value.truncateToDouble()) { // Jika bilangan bulat penuh tanpa pecahan
      return value.toInt().toString(); // Tampilkan sebagai bilangan bulat saja
    }
    return value.toStringAsFixed(1).replaceAll('.', ','); // Satu angka desimal, pakai koma sesuai gaya Indonesia
  }
}

/// Format tanggal dan waktu.
/// Selalu terima waktu SETEMPAT (sudah di-toLocal()), bukan UTC.
class DateFormatter {
  DateFormatter._(); // Constructor privat, class ini hanya berisi method statis

  static const List<String> _bulan = [ // Daftar nama bulan, index 0 kosong agar index 1 = Januari
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// '13 Agustus 2026, 14.45'
  static String full(DateTime local) => // Format lengkap tanggal + jam
      '${local.day} ${_bulan[local.month]} ${local.year}, ${time(local)}'; // Gabungkan tanggal, bulan, tahun, dan jam

  /// '14.45'
  static String time(DateTime local) {
    final String h = local.hour.toString().padLeft(2, '0'); // Jam, diberi nol di depan jika satu digit
    final String m = local.minute.toString().padLeft(2, '0'); // Menit, diberi nol di depan jika satu digit
    return '$h.$m'; // Gabungkan jam dan menit dengan titik
  }

  /// '13/08/2026'
  static String short(DateTime local) {
    final String d = local.day.toString().padLeft(2, '0'); // Tanggal dua digit
    final String m = local.month.toString().padLeft(2, '0'); // Bulan dua digit
    return '$d/$m/${local.year}'; // Format singkat dd/mm/yyyy
  }

  /// '13 Agustus 2026'
  static String dateWithMonth(DateTime local) => // Format tanggal dengan nama bulan tanpa jam
      '${local.day} ${_bulan[local.month]} ${local.year}'; // Gabungkan tanggal, nama bulan, tahun
}
