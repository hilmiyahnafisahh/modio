import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import 'package:flutter/semantics.dart'; // Untuk SemanticsService (pengumuman ke screen reader)

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

class AccessibilityHelper { // Kumpulan fungsi bantu aksesibilitas
  AccessibilityHelper._(); // Konstruktor privat, kelas ini hanya wadah statis

  // ── Semantics Wrapper ────────────────────────────────────────────
  /// Membungkus widget dengan Semantics agar screen reader bisa membacanya
  ///
  /// [label]   → deskripsi singkat widget (WAJIB diisi)
  /// [hint]    → petunjuk cara berinteraksi (opsional)
  /// [onTap]   → aksi saat diaktifkan via accessibility
  static Widget wrapSemantics({ // Bungkus widget apa pun dengan info aksesibilitas
    required String label, // Teks yang dibacakan screen reader
    required Widget child, // Widget yang dibungkus
    String? hint, // Petunjuk tambahan opsional
    VoidCallback? onTap, // Aksi saat diaktifkan lewat screen reader
    bool isButton = false, // Tandai sebagai tombol atau tidak
    bool excludeSemantics = false, // Sembunyikan info semantik anak widget
  }) {
    return Semantics( // Widget pembawa info aksesibilitas
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
  static Widget minTapTarget({ // Perbesar area sentuh widget kecil agar mudah diketuk
    required Widget child, // Widget asli yang dibungkus
    required VoidCallback onTap, // Aksi saat area disentuh
    double minSize = 48, // Ukuran minimum area sentuh dalam piksel
  }) {
    return GestureDetector( // Deteksi ketukan pada seluruh area minimum
      onTap: onTap,
      child: ConstrainedBox( // Paksa ukuran minimum area sentuh
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        child: Center(child: child), // Widget asli diposisikan di tengah area
      ),
    );
  }

  // ── Teks dengan Contrast Tinggi ──────────────────────────────────
  /// Mengembalikan warna teks yang kontras terhadap background
  /// (untuk memenuhi WCAG AA minimum ratio 4.5:1)
  ///
  /// [background] → warna latar widget
  static Color contrastText(Color background) { // Pilih warna teks yang kontras dengan latar
    // Hitung luminance relatif background
    final double luminance = background.computeLuminance(); // Tingkat kecerahan warna latar
    // Jika background terang → gunakan teks gelap, dan sebaliknya
    return luminance > 0.5 ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF); // Pilih teks gelap atau terang
  }

  // ── Announce untuk Screen Reader ─────────────────────────────────
  /// Umumkan pesan ke screen reader (contoh: setelah simpan data)
  static void announce(BuildContext context, String message) { // Bacakan pesan lewat screen reader
    SemanticsService.sendAnnouncement( // Kirim pengumuman ke layanan aksesibilitas sistem
        View.of(context), message, Directionality.of(context));
  }
}
