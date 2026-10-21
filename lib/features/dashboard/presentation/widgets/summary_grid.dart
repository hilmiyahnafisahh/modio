import 'package:flutter/material.dart'; // Widget dasar Flutter

import '../../../../core/theme/app_typography.dart'; // Gaya teks terpusat
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi warna tema kontekstual
import '../../../../core/utils/currency_formatter.dart'; // Format nominal ke teks rupiah/terucap

/// ─────────────────────────────────────────────────────────────────
/// SUMMARY GRID  –  Grid 2×2 ringkasan keuangan hari ini
///
/// PERUBAHAN: menerima int, bukan String berformat, agar versi terbaca
/// untuk screen reader bisa dihitung dari angkanya.
///
/// Cara pakai:
///   SummaryGrid(
///     income: 1205000,
///     expense: 246000,
///     profit: 959000,
///     transactionCount: 19,
///   )
/// ─────────────────────────────────────────────────────────────────

class SummaryGrid extends StatelessWidget {
  final int income; // Total pemasukan hari ini
  final int expense; // Total pengeluaran hari ini
  final int profit; // Laba (bisa negatif bila rugi)
  final int transactionCount; // Jumlah transaksi hari ini

  const SummaryGrid({
    super.key,
    required this.income,
    required this.expense,
    required this.profit,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool rugi = profit < 0; // Tentukan label "Rugi" atau "Laba" dari tanda profit

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics( // Tandai sebagai judul agar bisa dilompati lewat navigasi Judul TalkBack
          header: true,
          child: Text(
            'Ringkasan Hari Ini',
            style: AppTypography.titleMedium.copyWith(
              color: context.warnaTeksUtama,
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row( // Baris berisi 2 kolom kartu (kiri & kanan)
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column( // Kolom kiri: Pemasukan + Laba/Rugi
                children: [
                  _SummaryCard(
                    // north_east/south_west, sama dengan ikon arah di
                    // baris transaksi (transaction_tile.dart) dan
                    // dashboard. Diagonal dipilih di seluruh app
                    // karena panah lurus atas-bawah mudah tertukar
                    // dengan penanda urutan atau gulir.
                    icon: Icons.north_east, // Panah diagonal naik = pemasukan
                    iconColor: context.warnaMasuk,
                    label: 'Pemasukan',
                    value: CurrencyFormatter.format(income), // Teks tampilan angka
                    spokenValue: CurrencyFormatter.spoken(income), // Teks terucap untuk pembaca layar
                    bgColor: context.latarMasuk,
                    valueColor: context.warnaMasuk,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: context.warnaInfo,
                    label: rugi ? 'Rugi Bersih' : 'Laba Bersih', // Label berubah sesuai untung/rugi
                    value: CurrencyFormatter.format(profit.abs()), // Tampilkan nilai mutlak (tanpa minus)
                    spokenValue: CurrencyFormatter.spoken(profit.abs()),
                    bgColor: context.latarInfo,
                    valueColor: context.warnaInfo,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column( // Kolom kanan: Pengeluaran + Jumlah transaksi
                children: [
                  _SummaryCard(
                    icon: Icons.south_west, // Panah diagonal turun = pengeluaran
                    iconColor: context.warnaKeluar,
                    label: 'Pengeluaran',
                    value: CurrencyFormatter.format(expense),
                    spokenValue: CurrencyFormatter.spoken(expense),
                    bgColor: context.latarKeluar,
                    valueColor: context.warnaKeluar,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    icon: Icons.receipt_long_outlined,
                    iconColor: context.warnaAmber,
                    label: 'Transaksi',
                    value: '$transactionCount', // Angka jumlah transaksi langsung sebagai teks
                    spokenValue: '$transactionCount transaksi',
                    bgColor: context.latarAmber,
                    valueColor: context.warnaAmber,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Kartu ringkasan satu metrik keuangan
class _SummaryCard extends StatelessWidget {
  final IconData icon; // Ikon metrik
  final Color iconColor; // Warna ikon
  final String label; // Nama metrik, mis. "Pemasukan"
  final String value; // Nilai tampilan (format angka)
  final String spokenValue; // Nilai untuk dibacakan pembaca layar
  final Color bgColor; // Warna latar kartu
  final Color valueColor; // Warna teks nilai

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.spokenValue,
    required this.bgColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $spokenValue', // Gabungan label+nilai untuk pembaca layar
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        // Tinggi mengikuti isi, tidak dipatok, agar tetap utuh saat
        // pengguna memperbesar teks sistem.
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: valueColor.withValues(alpha: 0.35)), // Garis tipis transparan sewarna nilai
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row( // Baris ikon bulat + label metrik
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor, width: 1.5),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.labelSmall.copyWith(
                      color: context.warnaTeksUtama,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text( // Nilai nominal/angka utama kartu
              value,
              style: AppTypography.numericLarge.copyWith(
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
