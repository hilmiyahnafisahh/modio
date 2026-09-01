import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';

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
  final int income;
  final int expense;
  final int profit;
  final int transactionCount;

  const SummaryGrid({
    super.key,
    required this.income,
    required this.expense,
    required this.profit,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final bool rugi = profit < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Hari Ini',
          style: AppTypography.titleMedium.copyWith(
            color: context.warnaTeksUtama,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _SummaryCard(
                    // north_east/south_west, sama dengan ikon arah di
                    // baris transaksi (transaction_tile.dart) dan
                    // dashboard. Diagonal dipilih di seluruh app
                    // karena panah lurus atas-bawah mudah tertukar
                    // dengan penanda urutan atau gulir.
                    icon: Icons.north_east,
                    iconColor: context.warnaMasuk,
                    label: 'Pemasukan',
                    value: CurrencyFormatter.format(income),
                    spokenValue: CurrencyFormatter.spoken(income),
                    bgColor: context.latarMasuk,
                    valueColor: context.warnaMasuk,
                  ),
                  const SizedBox(height: 12),
                  _SummaryCard(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: context.warnaInfo,
                    label: rugi ? 'Rugi Bersih' : 'Laba Bersih',
                    value: CurrencyFormatter.format(profit.abs()),
                    spokenValue: CurrencyFormatter.spoken(profit.abs()),
                    bgColor: context.latarInfo,
                    valueColor: context.warnaInfo,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _SummaryCard(
                    icon: Icons.south_west,
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
                    value: '$transactionCount',
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
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String spokenValue;
  final Color bgColor;
  final Color valueColor;

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
      label: '$label $spokenValue',
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
          border: Border.all(color: valueColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
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
            Text(
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