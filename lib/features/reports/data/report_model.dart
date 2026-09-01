import '../../../core/utils/currency_formatter.dart';
import '../../transactions/data/transaction_model.dart';

/// Rincian satu kategori dalam laporan
class RincianKategori {
  final String nama;
  final int total;
  final int jumlahTransaksi;

  /// Daftar transaksi dalam kategori ini.
  /// Diisi oleh LaporanRepository; kosong di versi lama.
  final List<TransactionItem> transaksi;

  const RincianKategori({
    required this.nama,
    required this.total,
    required this.jumlahTransaksi,
    this.transaksi = const [],
  });

  /// Porsi kategori ini terhadap keseluruhan, 0.0 sampai 1.0
  double porsi(int totalKeseluruhan) =>
      totalKeseluruhan == 0 ? 0 : total / totalKeseluruhan;

  /// Porsi dalam persen bulat
  int persen(int totalKeseluruhan) =>
      (porsi(totalKeseluruhan) * 100).round();
}

/// Laporan keuangan satu bulan
class LaporanBulanan {
  final int tahun;
  final int bulan;

  final int totalPendapatan;
  final int totalBeban;
  final int jumlahTransaksi;

  final List<RincianKategori> rincianPendapatan;
  final List<RincianKategori> rincianBeban;

  /// Angka bulan sebelumnya, untuk perbandingan. Null bila belum ada data.
  final int? pendapatanBulanLalu;
  final int? bebanBulanLalu;

  const LaporanBulanan({
    required this.tahun,
    required this.bulan,
    required this.totalPendapatan,
    required this.totalBeban,
    required this.jumlahTransaksi,
    required this.rincianPendapatan,
    required this.rincianBeban,
    this.pendapatanBulanLalu,
    this.bebanBulanLalu,
  });

  int get labaBersih => totalPendapatan - totalBeban;
  bool get untung => labaBersih >= 0;

  static const List<String> _namaBulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String get labelPeriode => '${_namaBulan[bulan]} $tahun';

  /// Perubahan pendapatan terhadap bulan lalu dalam persen.
  /// Null bila tidak ada pembanding atau pembagi nol.
  int? get perubahanPendapatan => _hitungPerubahan(
        pendapatanBulanLalu,
        totalPendapatan,
      );

  int? get perubahanBeban => _hitungPerubahan(bebanBulanLalu, totalBeban);

  int? _hitungPerubahan(int? lalu, int sekarang) {
    // Pembagian dengan nol menghasilkan Infinity, yang kalau ikut
    // dinarasikan akan terdengar seperti angka yang tidak masuk akal.
    if (lalu == null || lalu == 0) return null;
    return (((sekarang - lalu) / lalu) * 100).round();
  }

  /// Kategori beban terbesar, untuk disorot dalam narasi
  RincianKategori? get bebanTerbesar =>
      rincianBeban.isEmpty ? null : rincianBeban.first;

  /// Narasi laporan siap dibacakan pembaca layar.
  ///
  /// Dirakit dari template berisi angka hasil perhitungan basis data,
  /// bukan dibangkitkan model bahasa. Angka pada laporan keuangan tidak
  /// boleh mengandung kemungkinan kekeliruan — pengguna tunanetra tidak
  /// punya cara memeriksa ulang secara visual.
  String get narasi {
    if (jumlahTransaksi == 0) {
      return 'Belum ada transaksi pada $labelPeriode.';
    }

    final StringBuffer b = StringBuffer();

    b.write('Pada $labelPeriode, pendapatan usaha Anda '
        '${CurrencyFormatter.spoken(totalPendapatan)} '
        'dan beban biaya ${CurrencyFormatter.spoken(totalBeban)}. ');

    if (untung) {
      b.write('Laba bersih ${CurrencyFormatter.spoken(labaBersih)}. ');
    } else {
      b.write('Rugi ${CurrencyFormatter.spoken(labaBersih.abs())}. ');
    }

    // Perbandingan hanya disebut bila ada pembandingnya, agar tidak
    // memberi kesan ada tren padahal datanya belum cukup.
    final int? naikPendapatan = perubahanPendapatan;
    if (naikPendapatan != null && naikPendapatan != 0) {
      b.write('Pendapatan ${naikPendapatan > 0 ? 'naik' : 'turun'} '
          '${naikPendapatan.abs()} persen dibanding bulan lalu. ');
    }

    final int? naikBeban = perubahanBeban;
    if (naikBeban != null && naikBeban >= 20) {
      b.write('Perhatian, beban biaya naik $naikBeban persen '
          'dibanding bulan lalu. ');
    } else if (naikBeban != null && naikBeban <= -20) {
      b.write('Beban biaya turun ${naikBeban.abs()} persen '
          'dibanding bulan lalu. ');
    }

    final RincianKategori? terbesar = bebanTerbesar;
    if (terbesar != null && totalBeban > 0) {
      b.write('Pengeluaran terbesar pada ${terbesar.nama}, '
          '${CurrencyFormatter.spoken(terbesar.total)}, '
          'atau ${terbesar.persen(totalBeban)} persen dari '
          'seluruh pengeluaran.');
    }

    return b.toString();
  }
}
