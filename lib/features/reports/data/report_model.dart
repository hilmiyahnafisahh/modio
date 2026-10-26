import '../../../core/akuntansi/coa.dart'; // kelompok akun COA (SAK EMKM)
import '../../../core/utils/currency_formatter.dart'; // untuk mengubah angka jadi teks lisan
import '../../transactions/data/transaction_model.dart'; // model TransactionItem dipakai di rincian kategori

/// Rincian satu kategori (akun) dalam laporan
class RincianKategori {
  final String nama; // nama kategori, mis. "Gaji dan Upah"
  final int total; // total nominal transaksi dalam kategori ini
  final int jumlahTransaksi; // banyaknya transaksi dalam kategori ini
  final KelompokAkun kelompok; // letak akun ini di laporan laba rugi

  /// Daftar transaksi dalam kategori ini.
  /// Diisi oleh LaporanRepository; kosong di versi lama.
  final List<TransactionItem> transaksi;

  const RincianKategori({
    required this.nama,
    required this.total,
    required this.jumlahTransaksi,
    this.kelompok = KelompokAkun.bebanUsaha,
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

/// Laporan laba rugi satu bulan, disusun menurut SAK EMKM:
///
///   Pendapatan Usaha − Harga Pokok Penjualan = Laba Kotor
///   Laba Kotor − Beban Usaha = Laba Usaha
///   Laba Usaha + Pendapatan Lain-lain − Beban Lain-lain = Laba Sebelum Pajak
///   Laba Sebelum Pajak − Beban Pajak = Laba Bersih
///
/// Modal, prive, pinjaman, dan pembelian aset tetap tidak ikut dihitung
/// (lihat [diLuarLabaRugi]).
class LaporanBulanan {
  final int tahun; // tahun periode laporan
  final int bulan; // bulan periode laporan, 1-12
  final int jumlahTransaksi; // banyaknya transaksi bulan ini (semua jenis)

  /// Semua kategori yang punya transaksi bulan ini, terbesar dulu.
  final List<RincianKategori> rincian;

  /// Angka laba rugi bulan sebelumnya, untuk perbandingan. Null bila
  /// belum ada data.
  final int? pendapatanBulanLalu;
  final int? bebanBulanLalu;

  const LaporanBulanan({
    required this.tahun,
    required this.bulan,
    required this.jumlahTransaksi,
    required this.rincian,
    this.pendapatanBulanLalu,
    this.bebanBulanLalu,
  });

  /// Kategori dalam satu kelompok akun, terbesar dulu.
  List<RincianKategori> rincianKelompok(KelompokAkun k) =>
      rincian.where((r) => r.kelompok == k).toList();

  /// Total satu kelompok akun.
  int totalKelompok(KelompokAkun k) =>
      rincianKelompok(k).fold(0, (jumlah, r) => jumlah + r.total);

  // ── Susunan laba rugi ──────────────────────────────────────────────
  int get pendapatanUsaha => totalKelompok(KelompokAkun.pendapatanUsaha);
  int get hargaPokok => totalKelompok(KelompokAkun.hargaPokok);
  int get labaKotor => pendapatanUsaha - hargaPokok;
  int get bebanUsaha => totalKelompok(KelompokAkun.bebanUsaha);
  int get labaUsaha => labaKotor - bebanUsaha;
  int get pendapatanLain => totalKelompok(KelompokAkun.pendapatanLain);
  int get bebanLain => totalKelompok(KelompokAkun.bebanLain);
  int get labaSebelumPajak => labaUsaha + pendapatanLain - bebanLain;
  int get bebanPajak => totalKelompok(KelompokAkun.bebanPajak);
  int get labaBersih => labaSebelumPajak - bebanPajak;
  bool get untung => labaBersih >= 0; // true jika tidak rugi

  /// Seluruh pendapatan yang masuk laba rugi.
  int get totalPendapatan => pendapatanUsaha + pendapatanLain;

  /// Seluruh beban yang masuk laba rugi (termasuk harga pokok & pajak).
  int get totalBeban => hargaPokok + bebanUsaha + bebanLain + bebanPajak;

  /// Kategori pendapatan yang masuk laba rugi, terbesar dulu.
  List<RincianKategori> get rincianPendapatan => rincian
      .where((r) =>
          r.kelompok == KelompokAkun.pendapatanUsaha ||
          r.kelompok == KelompokAkun.pendapatanLain)
      .toList();

  /// Kategori beban yang masuk laba rugi, terbesar dulu.
  List<RincianKategori> get rincianBeban => rincian
      .where((r) =>
          r.kelompok.labaRugi &&
          r.kelompok != KelompokAkun.pendapatanUsaha &&
          r.kelompok != KelompokAkun.pendapatanLain)
      .toList();

  /// Modal, prive, pinjaman, dan pembelian aset: tercatat sebagai arus
  /// uang, tetapi bukan pendapatan atau beban.
  List<RincianKategori> get diLuarLabaRugi =>
      rincian.where((r) => !r.kelompok.labaRugi).toList();

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
  RincianKategori? get bebanTerbesar {
    final List<RincianKategori> beban = rincianBeban;
    return beban.isEmpty ? null : beban.first; // daftar sudah terurut menurun
  }

  /// Narasi laporan siap dibacakan pembaca layar.
  ///
  /// Dirakit dari template berisi angka hasil perhitungan basis data,
  /// bukan dibangkitkan model bahasa. Angka pada laporan keuangan tidak
  /// boleh mengandung kemungkinan kekeliruan — pengguna tunanetra tidak
  /// punya cara memeriksa ulang secara visual.
  ///
  /// Pos yang nilainya nol tidak disebut, supaya narasi tetap pendek.
  String get narasi {
    if (jumlahTransaksi == 0) {
      return 'Belum ada transaksi pada $labelPeriode.'; // laporan kosong, hentikan di sini
    }

    String rp(int n) => CurrencyFormatter.spoken(n.abs()); // nominal lisan tanpa tanda minus

    final StringBuffer b = StringBuffer(); // penampung teks narasi yang dirakit bertahap

    b.write('Laporan laba rugi $labelPeriode. '
        'Pendapatan usaha ${rp(pendapatanUsaha)}. ');

    if (hargaPokok > 0) {
      b.write('Harga pokok penjualan ${rp(hargaPokok)}, '
          '${labaKotor >= 0 ? 'laba' : 'rugi'} kotor ${rp(labaKotor)}. ');
    }
    if (bebanUsaha > 0) b.write('Beban usaha ${rp(bebanUsaha)}. ');
    if (pendapatanLain > 0) b.write('Pendapatan lain-lain ${rp(pendapatanLain)}. ');
    if (bebanLain > 0) b.write('Beban lain-lain ${rp(bebanLain)}. ');
    if (bebanPajak > 0) b.write('Beban pajak ${rp(bebanPajak)}. ');

    b.write('${untung ? 'Laba' : 'Rugi'} bersih ${rp(labaBersih)}. ');

    // Perbandingan hanya disebut bila ada pembandingnya, agar tidak
    // memberi kesan ada tren padahal datanya belum cukup.
    final int? naikPendapatan = perubahanPendapatan;
    if (naikPendapatan != null && naikPendapatan != 0) {
      b.write('Pendapatan ${naikPendapatan > 0 ? 'naik' : 'turun'} '
          '${naikPendapatan.abs()} persen dibanding bulan lalu. '); // sebutkan arah dan besar perubahan
    }

    final int? naikBeban = perubahanBeban;
    if (naikBeban != null && naikBeban >= 20) {
      b.write('Perhatian, beban naik $naikBeban persen '
          'dibanding bulan lalu. '); // peringatan kenaikan beban signifikan
    } else if (naikBeban != null && naikBeban <= -20) {
      b.write('Beban turun ${naikBeban.abs()} persen '
          'dibanding bulan lalu. '); // penurunan beban signifikan
    }

    final RincianKategori? terbesar = bebanTerbesar;
    if (terbesar != null && totalBeban > 0) {
      b.write('Pengeluaran terbesar pada ${terbesar.nama}, '
          '${rp(terbesar.total)}, '
          'atau ${terbesar.persen(totalBeban)} persen dari '
          'seluruh beban. '); // sorot kategori pengeluaran terbesar
    }

    final List<RincianKategori> luar = diLuarLabaRugi;
    if (luar.isNotEmpty) {
      b.write('Di luar laba rugi: '
          '${luar.map((r) => '${r.nama} ${rp(r.total)}').join(', ')}.');
    }

    return b.toString().trim(); // gabungkan seluruh potongan kalimat jadi satu narasi
  }
}
