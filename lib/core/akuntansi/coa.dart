/// ─────────────────────────────────────────────────────────────────
/// BAGAN AKUN (COA)  –  Kategori transaksi sesuai SAK EMKM
///
/// Setiap kategori transaksi adalah satu akun. Kelompok akun
/// menentukan letaknya di laporan laba rugi:
///
///   Pendapatan Usaha
///   (−) Harga Pokok Penjualan
///   = Laba Kotor
///   (−) Beban Usaha
///   = Laba Usaha
///   (+) Pendapatan Lain-lain  (−) Beban Lain-lain
///   = Laba Sebelum Pajak
///   (−) Beban Pajak
///   = Laba Bersih
///
/// Modal, prive, pinjaman, dan pembelian aset tetap BUKAN pendapatan
/// atau beban, sehingga dicatat di luar laba rugi. Menghitung modal
/// sebagai pendapatan, atau membeli etalase sebagai beban, membuat
/// laba yang dibacakan ke pengguna tidak sesuai standar.
///
/// Kode akun disimpan untuk penyusunan laporan, tetapi tidak
/// dibacakan — pengguna tunanetra cukup mendengar nama akunnya.
///
/// Batasan yang disadari: harga pokok penjualan dihitung dari
/// pembelian pada periode itu (belum ada pencatatan persediaan), dan
/// aset tetap belum disusutkan.
/// ─────────────────────────────────────────────────────────────────
library;

/// Kelompok akun. [kode] adalah nilai yang disimpan di basis data.
enum KelompokAkun {
  pendapatanUsaha('pendapatan_usaha', 'Pendapatan Usaha', labaRugi: true),
  hargaPokok('hpp', 'Harga Pokok Penjualan', labaRugi: true),
  bebanUsaha('beban_usaha', 'Beban Usaha', labaRugi: true),
  pendapatanLain('pendapatan_lain', 'Pendapatan Lain-lain', labaRugi: true),
  bebanLain('beban_lain', 'Beban Lain-lain', labaRugi: true),
  bebanPajak('beban_pajak', 'Beban Pajak', labaRugi: true),
  modal('modal', 'Modal Pemilik', labaRugi: false),
  prive('prive', 'Prive', labaRugi: false),
  kewajiban('kewajiban', 'Pinjaman', labaRugi: false),
  aset('aset', 'Aset Tetap', labaRugi: false);

  const KelompokAkun(this.kode, this.label, {required this.labaRugi});

  final String kode; // Nilai kolom kategori.kelompok
  final String label; // Nama kelompok untuk judul bagian laporan
  final bool labaRugi; // true bila ikut dihitung di laporan laba rugi

  /// Kelompok dari nilai tersimpan. Nilai kosong/tak dikenal jatuh ke
  /// kelompok bawaan per jenis transaksi (lihat [bawaanUntuk]).
  static KelompokAkun dariKode(String? kode, {required bool masuk}) {
    for (final KelompokAkun k in values) {
      if (k.kode == kode) return k;
    }
    return bawaanUntuk(masuk: masuk);
  }

  /// Kelompok untuk kategori buatan pengguna yang belum diklasifikasi:
  /// pemasukan dianggap pendapatan usaha, pengeluaran dianggap beban
  /// usaha — tebakan paling umum untuk UMKM.
  static KelompokAkun bawaanUntuk({required bool masuk}) =>
      masuk ? pendapatanUsaha : bebanUsaha;
}

/// Satu akun bawaan.
class AkunBawaan {
  const AkunBawaan(this.kode, this.nama, this.type, this.kelompok);

  final String kode; // Kode akun, mis. "6-101"
  final String nama; // Nama kategori yang dilihat & didengar pengguna
  final String type; // 'masuk' atau 'keluar'
  final KelompokAkun kelompok;
}

/// Akun bawaan untuk pengguna baru, berurutan seperti yang tampil di
/// pemilih kategori.
const List<AkunBawaan> akunBawaan = [
  // Pemasukan
  AkunBawaan('4-101', 'Penjualan', 'masuk', KelompokAkun.pendapatanUsaha),
  AkunBawaan('4-102', 'Pendapatan Jasa', 'masuk', KelompokAkun.pendapatanUsaha),
  AkunBawaan('7-101', 'Pendapatan Lain-lain', 'masuk', KelompokAkun.pendapatanLain),
  AkunBawaan('3-101', 'Modal Pemilik', 'masuk', KelompokAkun.modal),
  AkunBawaan('2-101', 'Pinjaman Diterima', 'masuk', KelompokAkun.kewajiban),
  // Pengeluaran
  AkunBawaan('5-101', 'Bahan Baku dan Barang Dagang', 'keluar', KelompokAkun.hargaPokok),
  AkunBawaan('5-102', 'Kemasan', 'keluar', KelompokAkun.hargaPokok),
  AkunBawaan('6-101', 'Gaji dan Upah', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-102', 'Sewa', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-103', 'Listrik, Air, dan Komunikasi', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-104', 'Transportasi dan Pengiriman', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-105', 'Pemeliharaan dan Perbaikan', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-106', 'Perlengkapan', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-107', 'Pemasaran', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-108', 'Konsumsi', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('6-199', 'Beban Usaha Lain-lain', 'keluar', KelompokAkun.bebanUsaha),
  AkunBawaan('7-201', 'Bunga dan Biaya Bank', 'keluar', KelompokAkun.bebanLain),
  AkunBawaan('8-101', 'Pajak', 'keluar', KelompokAkun.bebanPajak),
  AkunBawaan('1-201', 'Pembelian Aset Tetap', 'keluar', KelompokAkun.aset),
  AkunBawaan('2-102', 'Angsuran Pinjaman', 'keluar', KelompokAkun.kewajiban),
  AkunBawaan('3-102', 'Prive', 'keluar', KelompokAkun.prive),
];

/// Ganti nama kategori bawaan versi lama ke akun COA: (nama lama, jenis,
/// nama baru). Dipakai migrasi basis data versi 3.
///
/// "Peralatan" lama dipindah ke Perlengkapan (beban), bukan Aset Tetap:
/// data lama tidak membedakan alat kecil dari aset besar, dan memindah
/// ke beban menjaga laba bulan-bulan lalu tetap sama seperti yang
/// sudah pernah dibacakan ke pengguna.
const List<(String, String, String)> gantiNamaKategoriLama = [
  ('Jasa', 'masuk', 'Pendapatan Jasa'),
  ('Pemasukan Lain', 'masuk', 'Pendapatan Lain-lain'),
  ('Modal Masuk', 'masuk', 'Modal Pemilik'),
  ('Bahan Baku', 'keluar', 'Bahan Baku dan Barang Dagang'),
  ('Gaji', 'keluar', 'Gaji dan Upah'),
  ('Listrik dan Air', 'keluar', 'Listrik, Air, dan Komunikasi'),
  ('Transportasi', 'keluar', 'Transportasi dan Pengiriman'),
  ('Peralatan', 'keluar', 'Perlengkapan'),
  ('Pengeluaran Lain', 'keluar', 'Beban Usaha Lain-lain'),
];

/// Kategori bawaan versi lama yang dipertahankan apa adanya (masih bisa
/// dipakai data lama), tetapi diberi kelompok akun yang sesuai.
const List<(String, String, KelompokAkun)> kelompokKategoriLama = [
  ('Iuran Anggota', 'masuk', KelompokAkun.pendapatanLain),
  ('Donasi', 'masuk', KelompokAkun.pendapatanLain),
  ('Kegiatan', 'keluar', KelompokAkun.bebanUsaha),
];
