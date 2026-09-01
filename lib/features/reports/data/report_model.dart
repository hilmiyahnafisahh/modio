import '../../../core/utils/currency_formatter.dart'; // untuk mengubah angka jadi teks lisan
import '../../transactions/data/transaction_model.dart'; // model TransactionItem dipakai di rincian kategori

/// Rincian satu kategori dalam laporan
class RincianKategori {
  final String nama; // nama kategori, mis. "Makan"
  final int total; // total nominal transaksi dalam kategori ini
  final int jumlahTransaksi; // banyaknya transaksi dalam kategori ini

  /// Daftar transaksi dalam kategori ini.
  /// Diisi oleh LaporanRepository; kosong di versi lama.
  final List<TransactionItem> transaksi;

  const RincianKategori({
    required this.nama,
    required this.total,
    required this.jumlahTransaksi,
    this.transaksi = const [], // default kosong bila tidak diisi
  });

  /// Porsi kategori ini terhadap keseluruhan, 0.0 sampai 1.0
  double porsi(int totalKeseluruhan) =>
      // hindari pembagian dengan nol, hasilkan 0 bila total keseluruhan nol
      totalKeseluruhan == 0 ? 0 : total / totalKeseluruhan;

  /// Porsi dalam persen bulat
  int persen(int totalKeseluruhan) =>
      (porsi(totalKeseluruhan) * 100).round(); // ubah pecahan jadi persen bulat
}

/// Laporan keuangan satu bulan
class LaporanBulanan {
  final int tahun; // tahun periode laporan
  final int bulan; // bulan periode laporan, 1-12

  final int totalPendapatan; // total seluruh pemasukan bulan ini
  final int totalBeban; // total seluruh pengeluaran bulan ini
  final int jumlahTransaksi; // banyaknya transaksi bulan ini

  final List<RincianKategori> rincianPendapatan; // rincian per kategori pemasukan
  final List<RincianKategori> rincianBeban; // rincian per kategori pengeluaran

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

  int get labaBersih => totalPendapatan - totalBeban; // selisih pendapatan dan beban
  bool get untung => labaBersih >= 0; // true jika tidak rugi

  static const List<String> _namaBulan = [
    // indeks 0 sengaja kosong supaya indeks 1-12 cocok dengan nomor bulan
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String get labelPeriode => '${_namaBulan[bulan]} $tahun'; // teks periode, mis. "Januari 2026"

  /// Perubahan pendapatan terhadap bulan lalu dalam persen.
  /// Null bila tidak ada pembanding atau pembagi nol.
  int? get perubahanPendapatan => _hitungPerubahan(
        pendapatanBulanLalu,
        totalPendapatan,
      );

  int? get perubahanBeban => _hitungPerubahan(bebanBulanLalu, totalBeban); // perubahan beban vs bulan lalu

  int? _hitungPerubahan(int? lalu, int sekarang) {
    // Pembagian dengan nol menghasilkan Infinity, yang kalau ikut
    // dinarasikan akan terdengar seperti angka yang tidak masuk akal.
    if (lalu == null || lalu == 0) return null; // tidak ada pembanding yang valid
    return (((sekarang - lalu) / lalu) * 100).round(); // persentase perubahan dibulatkan
  }

  /// Kategori beban terbesar, untuk disorot dalam narasi
  RincianKategori? get bebanTerbesar =>
      // ambil elemen pertama karena daftar diasumsikan sudah terurut menurun
      rincianBeban.isEmpty ? null : rincianBeban.first;

  /// Narasi laporan siap dibacakan pembaca layar.
  ///
  /// Dirakit dari template berisi angka hasil perhitungan basis data,
  /// bukan dibangkitkan model bahasa. Angka pada laporan keuangan tidak
  /// boleh mengandung kemungkinan kekeliruan — pengguna tunanetra tidak
  /// punya cara memeriksa ulang secara visual.
  String get narasi {
    if (jumlahTransaksi == 0) {
      return 'Belum ada transaksi pada $labelPeriode.'; // laporan kosong, hentikan di sini
    }

    final StringBuffer b = StringBuffer(); // penampung teks narasi yang dirakit bertahap

    b.write('Pada $labelPeriode, pendapatan usaha Anda '
        '${CurrencyFormatter.spoken(totalPendapatan)} '
        'dan beban biaya ${CurrencyFormatter.spoken(totalBeban)}. '); // kalimat pembuka ringkasan

    if (untung) {
      b.write('Laba bersih ${CurrencyFormatter.spoken(labaBersih)}. '); // kondisi laba
    } else {
      b.write('Rugi ${CurrencyFormatter.spoken(labaBersih.abs())}. '); // kondisi rugi, nilai absolut
    }

    // Perbandingan hanya disebut bila ada pembandingnya, agar tidak
    // memberi kesan ada tren padahal datanya belum cukup.
    final int? naikPendapatan = perubahanPendapatan;
    if (naikPendapatan != null && naikPendapatan != 0) {
      b.write('Pendapatan ${naikPendapatan > 0 ? 'naik' : 'turun'} '
          '${naikPendapatan.abs()} persen dibanding bulan lalu. '); // sebutkan arah dan besar perubahan
    }

    final int? naikBeban = perubahanBeban;
    if (naikBeban != null && naikBeban >= 20) {
      b.write('Perhatian, beban biaya naik $naikBeban persen '
          'dibanding bulan lalu. '); // peringatan kenaikan beban signifikan
    } else if (naikBeban != null && naikBeban <= -20) {
      b.write('Beban biaya turun ${naikBeban.abs()} persen '
          'dibanding bulan lalu. '); // penurunan beban signifikan
    }

    final RincianKategori? terbesar = bebanTerbesar;
    if (terbesar != null && totalBeban > 0) {
      b.write('Pengeluaran terbesar pada ${terbesar.nama}, '
          '${CurrencyFormatter.spoken(terbesar.total)}, '
          'atau ${terbesar.persen(totalBeban)} persen dari '
          'seluruh pengeluaran.'); // sorot kategori pengeluaran terbesar
    }

    return b.toString(); // gabungkan seluruh potongan kalimat jadi satu narasi
  }
}
