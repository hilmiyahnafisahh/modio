import 'package:flutter/material.dart';

import '../../../../core/theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// AI INSIGHT WIDGET  –  Kartu ringkasan naratif
///
/// Menampilkan satu poin ringkasan keuangan.
///
/// CATATAN PENTING: isi kartu ini dirakit dari template berisi angka
/// hasil perhitungan basis data, bukan dibangkitkan model bahasa.
/// Angka pada laporan keuangan tidak boleh mengandung kemungkinan
/// kekeliruan, karena pengguna tunanetra tidak punya cara memeriksa
/// ulang secara visual.
/// ─────────────────────────────────────────────────────────────────

class AiInsightWidget extends StatelessWidget {
  final String title;
  final String description;
  final InsightType type;

  const AiInsightWidget({
    super.key,
    required this.title,
    required this.description,
    this.type = InsightType.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = switch (type) {
      InsightType.positive => context.latarMasuk,
      InsightType.negative => context.latarKeluar,
      InsightType.neutral => context.latarInfo,
    };
    final Color accentColor = switch (type) {
      InsightType.positive => context.warnaMasuk,
      InsightType.negative => context.warnaKeluar,
      InsightType.neutral => context.warnaInfo,
    };
    final IconData icon = switch (type) {
      InsightType.positive => Icons.trending_up_rounded,
      InsightType.negative => Icons.trending_down_rounded,
      InsightType.neutral => Icons.lightbulb_outline,
    };

    return Semantics(
      // Judul dan isi dibacakan sebagai satu kesatuan, bukan dua
      // elemen terpisah yang harus ditelusuri satu per satu.
      label: '$title. $description',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            // Garis tepi ditebalkan agar tetap terlihat pengguna
            // low vision, dan menjadi pembeda selain warna latar.
            left: BorderSide(color: accentColor, width: 5),
            top: BorderSide(color: accentColor.withValues(alpha: 0.25)),
            right: BorderSide(color: accentColor.withValues(alpha: 0.25)),
            bottom: BorderSide(color: accentColor.withValues(alpha: 0.25)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: accentColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      // Dinaikkan dari 13.
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      // Dinaikkan dari 12. Ini isi utama kartu,
                      // bukan keterangan tambahan.
                      fontSize: 15,
                      color: context.warnaTeksUtama,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nada ringkasan
enum InsightType {
  positive, // tren baik
  negative, // peringatan
  neutral,  // informasi netral
}