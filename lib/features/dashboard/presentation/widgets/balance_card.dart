import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';

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

class BalanceCard extends StatelessWidget {
  /// Nominal dalam rupiah utuh
  final int balance;

  /// Teks periode aktif
  final String period;

  /// Label di atas nominal. Default 'Saldo' untuk dashboard; halaman
  /// Laporan mengisi 'Laba Usaha' atau 'Rugi'.
  final String title;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.period,
    this.title = 'Saldo',
  });

  @override
  Widget build(BuildContext context) {
    final bool gelap = context.gelap;
    // Gradasi primary900→primary700 nyaris menyatu dengan latar mode
    // gelap — kartu ini justru butuh terlihat MENONJOL dari latar,
    // jadi mode gelap dapat perlakuan berbeda: latar solid
    // darkSurfaceHi ditambah garis tepi darkPrimary, bukan gradasi.
    final Color warnaTeksKartu = gelap ? AppColors.darkText : AppColors.white;
    // Label & periode: dark mode memakai darkTextMuted (rasio 12,3:1
    // yang sudah terverifikasi terhadap darkSurfaceHi), bukan darkText
    // yang diberi alpha — mengecilkan alpha tidak pernah diukur
    // rasionya, jadi tidak bisa diklaim AAA.
    final Color warnaMutedKartu =
        gelap ? AppColors.darkTextMuted : Colors.white.withValues(alpha: 0.88);
    final Color warnaMutedKartuLemah =
        gelap ? AppColors.darkTextMuted : Colors.white.withValues(alpha: 0.80);

    return Semantics(
      // Satu kalimat utuh menggantikan tiga elemen terpisah.
      // Tanpa ini TalkBack membaca "Saldo Usaha", jeda,
      // "Rp empat titik lima nol nol titik nol nol nol", jeda,
      // "Periode Juli 2026" — nominalnya tidak terpahami sebagai jumlah.
      label: '$title ${CurrencyFormatter.spoken(balance)}. $period',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: gelap
              ? null
              : const LinearGradient(
                  colors: [AppColors.primary900, AppColors.primary700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: gelap ? AppColors.darkSurfaceHi : null,
          borderRadius: BorderRadius.circular(20),
          border: gelap
              ? Border.all(color: AppColors.darkPrimary, width: 1.5)
              : null,
          boxShadow: gelap
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary900.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
        ),
        // ClipRRect menjaga lingkaran dekoratif di dalam Stack tidak
        // meluber keluar dari sudut kartu yang membulat.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Dua lingkaran translusen murni dekoratif, agar kartu
              // tidak terasa datar. Alpha rendah supaya tidak mengganggu
              // kontras teks di atasnya.
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary400.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                right: 30,
                bottom: -50,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary500.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.labelMedium.copyWith(
                        color: warnaMutedKartu,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      CurrencyFormatter.format(balance),
                      style: AppTypography.numericLarge.copyWith(
                        fontSize: 32,
                        color: warnaTeksKartu,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: warnaMutedKartuLemah,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
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
