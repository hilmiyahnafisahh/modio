import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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

class AiAnomalyBadge extends StatelessWidget {
  /// Pesan anomali dari AI
  final String message;

  /// Level keparahan: 'warning' (kuning) atau 'alert' (merah)
  final AnomalyLevel level;

  const AiAnomalyBadge({
    super.key,
    required this.message,
    this.level = AnomalyLevel.warning,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor = level == AnomalyLevel.alert
        ? AppColors.tertiary50
        : const Color(0xFFFFFBEB); // amber muda
    final Color iconColor = level == AnomalyLevel.alert
        ? AppColors.tertiary500
        : const Color(0xFFB45309); // amber gelap
    final IconData icon = level == AnomalyLevel.alert
        ? Icons.error_outline
        : Icons.warning_amber_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withAlpha(77), // 30% opacity border
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
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
enum AnomalyLevel {
  warning, // Peringatan ringan (kuning)
  alert,   // Peringatan serius (merah)
}
