import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../../../../core/theme/app_colors.dart'; // Palet warna aplikasi
import '../../../../core/theme/app_typography.dart'; // Gaya-gaya teks aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Extension untuk akses warna sesuai tema
import '../../../../core/utils/currency_formatter.dart'; // Pemformat angka menjadi teks rupiah

/// ─────────────────────────────────────────────────────────────────
/// BALANCE CARD  –  Kartu hero bergradasi
///
/// Dipakai untuk Saldo di dashboard maupun Laba Usaha/Rugi di halaman
/// Laporan — satu widget untuk kedua tempat agar gaya visualnya tetap
/// sama dan perbaikan pada salah satunya tidak terlewat di yang lain.
///
/// PERUBAHAN: `balance` sekarang bertipe int, bukan String berformat.
/// Alasannya, versi terbaca untuk screen reader hanya bisa dihitung
/// dari angka. Kalau yang diterima sudah berupa teks "Rp 4.500.000",
/// teks itu harus dibongkar kembali menjadi angka — dan pembongkaran
/// semacam itu rawan salah.
///
/// Cara pakai:
///   BalanceCard(balance: 4500000, period: 'Periode Juli 2026')
///   BalanceCard(balance: 950000, period: 'Juli 2026', title: 'Laba Usaha')
/// ─────────────────────────────────────────────────────────────────

class BalanceCard extends StatelessWidget { // Widget tanpa state internal, tampilan bergantung pada properti
  /// Nominal dalam rupiah utuh
  final int balance; // Jumlah saldo/laba dalam angka (bukan teks)

  /// Teks periode aktif
  final String period; // Teks periode yang ditampilkan, misalnya "Juli 2026"

  /// Label di atas nominal. Default 'Saldo' untuk dashboard; halaman
  /// Laporan mengisi 'Laba Usaha' atau 'Rugi'.
  final String title; // Judul di atas nominal

  const BalanceCard({ // Konstruktor widget, semua parameter bernama
    super.key, // Key widget diteruskan ke superclass
    required this.balance, // Wajib diisi saat membuat widget
    required this.period, // Wajib diisi saat membuat widget
    this.title = 'Saldo', // Nilai default judul
  });

  @override
  Widget build(BuildContext context) { // Membangun tampilan widget
    final bool gelap = context.gelap; // Cek apakah tema saat ini mode gelap
    // Gradasi primary900→primary700 nyaris menyatu dengan latar mode
    // gelap — kartu ini justru butuh terlihat MENONJOL dari latar,
    // jadi mode gelap dapat perlakuan berbeda: latar solid
    // darkSurfaceHi ditambah garis tepi darkPrimary, bukan gradasi.
    final Color warnaTeksKartu = gelap ? AppColors.darkText : AppColors.white; // Warna teks utama menyesuaikan tema
    // Label & periode: dark mode memakai darkTextMuted (rasio 12,3:1
    // yang sudah terverifikasi terhadap darkSurfaceHi), bukan darkText
    // yang diberi alpha. Mode terang: putih alpha 0,90 di atas ujung
    // gradasi paling terang (primary700) = 7,6:1 ✓ AAA. Alpha 0,80
    // sebelumnya hanya 6,4:1.
    final Color warnaMutedKartu =
        gelap ? AppColors.darkTextMuted : Colors.white.withValues(alpha: 0.92); // Warna teks label/periode, 7,8:1
    final Color warnaMutedKartuLemah =
        gelap ? AppColors.darkTextMuted : Colors.white.withValues(alpha: 0.90); // Warna teks periode lebih redup, 7,6:1

    return Semantics( // Bungkus dengan info aksesibilitas untuk screen reader
      // Satu kalimat utuh menggantikan tiga elemen terpisah.
      // Tanpa ini TalkBack membaca "Saldo Usaha", jeda,
      // "Rp empat titik lima nol nol titik nol nol nol", jeda,
      // "Periode Juli 2026" — nominalnya tidak terpahami sebagai jumlah.
      label: '$title ${CurrencyFormatter.spoken(balance)}. $period', // Label yang dibacakan screen reader
      excludeSemantics: true, // Sembunyikan info semantik dari anak-anak widget di bawahnya
      child: Container( // Kotak pembungkus utama kartu
        width: double.infinity, // Lebar mengikuti lebar induk
        decoration: BoxDecoration( // Dekorasi visual kartu
          gradient: gelap
              ? null // Mode gelap tidak pakai gradasi
              : const LinearGradient( // Mode terang pakai gradasi warna
                  colors: [AppColors.primary900, AppColors.primary700],
                  begin: Alignment.topLeft, // Gradasi mulai dari kiri atas
                  end: Alignment.bottomRight, // Gradasi berakhir di kanan bawah
                ),
          color: gelap ? AppColors.darkSurfaceHi : null, // Warna solid untuk mode gelap
          borderRadius: BorderRadius.circular(20), // Sudut kartu membulat
          border: gelap
              ? Border.all(color: AppColors.darkPrimary, width: 1.5) // Garis tepi hanya di mode gelap
              : null,
          boxShadow: gelap
              ? null // Tidak ada bayangan di mode gelap
              : [
                  BoxShadow( // Bayangan lembut di mode terang
                    color: AppColors.primary900.withValues(alpha: 0.35),
                    blurRadius: 24, // Seberapa kabur bayangannya
                    offset: const Offset(0, 12), // Posisi bayangan bergeser ke bawah
                  ),
                ],
        ),
        // ClipRRect menjaga lingkaran dekoratif di dalam Stack tidak
        // meluber keluar dari sudut kartu yang membulat.
        child: ClipRRect( // Potong konten agar mengikuti sudut membulat
          borderRadius: BorderRadius.circular(20), // Radius potongan sama dengan kartu
          child: Stack( // Tumpuk elemen dekoratif dan konten
            children: [
              // Dua lingkaran translusen murni dekoratif, agar kartu
              // tidak terasa datar. Alpha rendah supaya tidak mengganggu
              // kontras teks di atasnya.
              Positioned( // Lingkaran dekoratif pertama, posisi absolut
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // Bentuk lingkaran
                    color: AppColors.primary400.withValues(alpha: 0.12), // Warna transparan tipis
                  ),
                ),
              ),
              Positioned( // Lingkaran dekoratif kedua, posisi absolut
                right: 30,
                bottom: -50,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, // Bentuk lingkaran
                    color: AppColors.primary500.withValues(alpha: 0.10), // Warna transparan tipis
                  ),
                ),
              ),
              Padding( // Beri jarak isi kartu dari tepi
                padding: const EdgeInsets.all(20),
                child: Column( // Susun konten secara vertikal
                  crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                  children: [
                    Text( // Judul di atas nominal
                      title,
                      style: AppTypography.labelMedium.copyWith(
                        color: warnaMutedKartu,
                      ),
                    ),
                    const SizedBox(height: 12), // Jarak vertikal antar elemen

                    Text( // Nominal utama yang diformat sebagai rupiah
                      CurrencyFormatter.format(balance),
                      style: AppTypography.numericLarge.copyWith(
                        fontSize: 32, // Ukuran font besar agar menonjol
                        color: warnaTeksKartu,
                      ),
                    ),
                    const SizedBox(height: 12), // Jarak vertikal antar elemen

                    Row( // Baris ikon kalender dan teks periode
                      children: [
                        Icon( // Ikon kalender kecil
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: warnaMutedKartuLemah,
                        ),
                        const SizedBox(width: 6), // Jarak horizontal ikon ke teks
                        Flexible( // Biarkan teks periode menyusut jika ruang sempit
                          child: Text(
                            period,
                            style: AppTypography.captionSmall.copyWith(
                              color: warnaMutedKartuLemah,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
