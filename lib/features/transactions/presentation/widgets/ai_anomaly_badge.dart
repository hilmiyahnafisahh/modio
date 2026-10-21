import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import '../../../../core/theme/app_colors.dart'; // Palet warna aplikasi

/// ─────────────────────────────────────────────────────────────────
/// AI ANOMALY BADGE  –  Badge peringatan anomali transaksi dari AI
///
/// Menampilkan notifikasi kecil ketika AI mendeteksi transaksi
/// yang tidak biasa (anomali) — misal: pengeluaran jauh di atas rata-rata.
///
/// Cara pakai:
///   AiAnomalyBadge(
///     message: 'Pengeluaran 3× lebih tinggi dari rata-rata',
///   )
/// ─────────────────────────────────────────────────────────────────

class AiAnomalyBadge extends StatelessWidget { // Widget badge peringatan, tanpa state internal
  /// Pesan anomali dari AI
  final String message; // Teks pesan peringatan yang ditampilkan

  /// Level keparahan: 'warning' (kuning) atau 'alert' (merah)
  final AnomalyLevel level; // Tingkat keparahan anomali

  const AiAnomalyBadge({ // Konstruktor widget
    super.key, // Key diteruskan ke superclass
    required this.message, // Wajib diisi
    this.level = AnomalyLevel.warning, // Default level peringatan ringan
  });

  @override
  Widget build(BuildContext context) { // Membangun tampilan badge
    final Color bgColor = level == AnomalyLevel.alert
        ? AppColors.tertiary50 // Latar merah muda untuk level alert
        : AppColors.amber50; // amber muda
    final Color iconColor = level == AnomalyLevel.alert
        ? AppColors.tertiary700 // Merah 8,4:1 di atas tertiary50 (tertiary500 hanya 3,6:1)
        : AppColors.amber700; // Amber 7,4:1 di atas amber50 (#B45309 hanya 4,9:1)
    final IconData icon = level == AnomalyLevel.alert
        ? Icons.error_outline // Ikon error untuk level alert
        : Icons.warning_amber_outlined; // Ikon peringatan untuk level warning

    return Container( // Kotak pembungkus badge
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Jarak isi dari tepi
      decoration: BoxDecoration(
        color: bgColor, // Warna latar sesuai level
        borderRadius: BorderRadius.circular(8), // Sudut membulat
        border: Border.all(
          color: iconColor.withAlpha(77), // 30% opacity border
          width: 1,
        ),
      ),
      child: Row( // Susun ikon dan teks pesan secara horizontal
        mainAxisSize: MainAxisSize.min, // Lebar mengikuti konten, tidak memaksa penuh
        children: [
          Icon(icon, size: 16, color: iconColor), // Ikon penanda level keparahan
          const SizedBox(width: 6), // Jarak horizontal ikon ke teks
          Flexible( // Teks bisa menyusut sesuai ruang tersedia
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: iconColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Level keparahan anomali
enum AnomalyLevel { // Tingkat keparahan pesan anomali
  warning, // Peringatan ringan (kuning)
  alert,   // Peringatan serius (merah)
}
