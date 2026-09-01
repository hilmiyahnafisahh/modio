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
library;

class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format angka integer ke format Rupiah penuh
  /// Contoh: 4500000 → 'Rp 4.500.000'
  static String format(int amount) {
    final String raw = amount.abs().toString();
    final StringBuffer result = StringBuffer();

    int count = 0;
    for (int i = raw.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result.write('.');
      }
      result.write(raw[i]);
      count++;
    }

    final String formatted = result.toString().split('').reversed.join();
    final String prefix = amount < 0 ? '-Rp ' : 'Rp ';
    return '$prefix$formatted';
  }

  /// Format ringkas untuk angka besar
  /// Contoh: 4500000 → 'Rp 4,5 Jt'
  ///
  /// JANGAN dipakai sebagai label semantik. Pembulatan menyembunyikan
  /// selisih yang penting: 'Rp 4,5 Jt' bisa berarti 4.450.000 atau
  /// 4.549.000. Untuk screen reader selalu pakai spoken().
  static String compact(int amount) {
    if (amount >= 1000000000) {
      return 'Rp ${_removeTrailingZero(amount / 1000000000)} M';
    } else if (amount >= 1000000) {
      return 'Rp ${_removeTrailingZero(amount / 1000000)} Jt';
    } else if (amount >= 1000) {
      return 'Rp ${_removeTrailingZero(amount / 1000)} Rb';
    }
    return format(amount);
  }

  /// Format terbaca untuk screen reader
  /// Contoh: 4500000 → 'empat juta lima ratus ribu rupiah'
  static String spoken(int amount) {
    if (amount == 0) return 'nol rupiah';

    final bool negatif = amount < 0;
    int sisa = amount.abs();
    final List<String> bagian = [];

    const Map<int, String> satuan = {
      1000000000: 'miliar',
      1000000: 'juta',
      1000: 'ribu',
    };

    for (final entry in satuan.entries) {
      if (sisa >= entry.key) {
        bagian.add('${_terbilang(sisa ~/ entry.key)} ${entry.value}');
        sisa %= entry.key;
      }
    }
    if (sisa > 0) bagian.add(_terbilang(sisa));

    return '${negatif ? 'minus ' : ''}${bagian.join(' ')} rupiah';
  }

  static const List<String> _angka = [
    '', 'satu', 'dua', 'tiga', 'empat',
    'lima', 'enam', 'tujuh', 'delapan', 'sembilan',
  ];

  static String _terbilang(int n) {
    if (n < 10) return _angka[n];
    if (n == 10) return 'sepuluh';
    if (n == 11) return 'sebelas';
    if (n < 20) return '${_angka[n - 10]} belas';
    if (n < 100) {
      final int sisa = n % 10;
      return '${_angka[n ~/ 10]} puluh${sisa > 0 ? ' ${_angka[sisa]}' : ''}';
    }
    if (n < 1000) {
      final String ratus =
          n ~/ 100 == 1 ? 'seratus' : '${_angka[n ~/ 100]} ratus';
      final int sisa = n % 100;
      return '$ratus${sisa > 0 ? ' ${_terbilang(sisa)}' : ''}';
    }
    return n.toString();
  }

  static String _removeTrailingZero(double value) {
    if (value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }
}

/// Format tanggal dan waktu.
/// Selalu terima waktu SETEMPAT (sudah di-toLocal()), bukan UTC.
class DateFormatter {
  DateFormatter._();

  static const List<String> _bulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  /// '13 Agustus 2026, 14.45'
  static String full(DateTime local) =>
      '${local.day} ${_bulan[local.month]} ${local.year}, ${time(local)}';

  /// '14.45'
  static String time(DateTime local) {
    final String h = local.hour.toString().padLeft(2, '0');
    final String m = local.minute.toString().padLeft(2, '0');
    return '$h.$m';
  }

  /// '13/08/2026'
  static String short(DateTime local) {
    final String d = local.day.toString().padLeft(2, '0');
    final String m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }

  /// '13 Agustus 2026'
  static String dateWithMonth(DateTime local) =>
      '${local.day} ${_bulan[local.month]} ${local.year}';
}
