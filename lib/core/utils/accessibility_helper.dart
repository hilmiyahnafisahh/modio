import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// ─────────────────────────────────────────────────────────────────
/// ACCESSIBILITY HELPER  –  Utilitas aksesibilitas (a11y)
///
/// Membantu membuat widget lebih mudah diakses oleh pengguna
/// dengan kebutuhan khusus (disabilitas visual, motor, dll).
///
/// Cara pakai:
///   AccessibilityHelper.wrapSemantics(
///     label: 'Tombol Simpan Transaksi',
///     hint: 'Ketuk dua kali untuk menyimpan',
///     child: ElevatedButton(...),
///   )
/// ─────────────────────────────────────────────────────────────────

class AccessibilityHelper {
  AccessibilityHelper._();

  // ── Semantics Wrapper ────────────────────────────────────────────
  /// Membungkus widget dengan Semantics agar screen reader bisa membacanya
  ///
  /// [label]   → deskripsi singkat widget (WAJIB diisi)
  /// [hint]    → petunjuk cara berinteraksi (opsional)
  /// [onTap]   → aksi saat diaktifkan via accessibility
  static Widget wrapSemantics({
    required String label,
    required Widget child,
    String? hint,
    VoidCallback? onTap,
    bool isButton = false,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: isButton,
      onTap: onTap,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  // ── Ukuran Tap Target Minimum ─────────────────────────────────────
  /// Membungkus widget kecil agar area tap-nya minimal 48×48px
  /// (standar WCAG 2.5.5 – Target Size)
  static Widget minTapTarget({
    required Widget child,
    required VoidCallback onTap,
    double minSize = 48,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        child: Center(child: child),
      ),
    );
  }

  // ── Teks dengan Contrast Tinggi ──────────────────────────────────
  /// Mengembalikan warna teks yang kontras terhadap background
  /// (untuk memenuhi WCAG AA minimum ratio 4.5:1)
  ///
  /// [background] → warna latar widget
  static Color contrastText(Color background) {
    // Hitung luminance relatif background
    final double luminance = background.computeLuminance();
    // Jika background terang → gunakan teks gelap, dan sebaliknya
    return luminance > 0.5 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  }

  // ── Announce untuk Screen Reader ─────────────────────────────────
  /// Umumkan pesan ke screen reader (contoh: setelah simpan data)
  static void announce(BuildContext context, String message) {
    SemanticsService.sendAnnouncement(
        View.of(context), message, Directionality.of(context));
  }
}
