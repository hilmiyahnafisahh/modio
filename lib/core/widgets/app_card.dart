import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter

import '../theme/app_colors.dart'; // Palet warna khusus aplikasi
import '../theme/app_typography.dart'; // Gaya teks (font, ukuran) khusus aplikasi
import '../theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// APP CARD WIDGET  –  Kartu standar yang konsisten
///
/// Digunakan untuk semua kartu di aplikasi agar memiliki styling
/// yang konsisten dan mudah di-maintain.
/// ─────────────────────────────────────────────────────────────────

/// Card dengan gaya Modio standar
class AppCard extends StatelessWidget { // Widget tanpa state, tampilan dihitung ulang dari parameter
  final Widget child; // Konten yang dibungkus di dalam kartu
  final EdgeInsetsGeometry padding; // Jarak dalam antara tepi kartu dan konten

  /// Null berarti ikut tema aktif (kartu & garis terang/gelap) — hanya
  /// diisi eksplisit saat pemanggil sungguh butuh warna tetap, bukan
  /// sebagai nilai baku, sebab nilai baku const tidak bisa membaca
  /// `BuildContext` untuk tahu tema mana yang sedang aktif.
  final Color? backgroundColor; // Warna latar kartu, opsional
  final Color? borderColor; // Warna garis tepi kartu, opsional
  final double borderRadius; // Radius sudut kartu
  final double elevation; // Nilai bayangan (dipakai turunan lain)
  final VoidCallback? onTap; // Aksi saat kartu diketuk, opsional
  final BoxBorder? border; // Border kustom, menggantikan borderColor jika diisi

  const AppCard({ // Constructor dengan nilai default umum
    super.key, // Key widget standar Flutter
    required this.child, // Konten wajib diisi
    this.padding = const EdgeInsets.all(16), // Default padding 16 di semua sisi
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14, // Default sudut membulat 14
    this.elevation = 0, // Default tanpa bayangan
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardBorder = border ?? // Pakai border kustom jika ada
        Border.all(
          color: borderColor ?? context.warnaGaris, // Warna garis: custom atau ikut tema
          width: 1, // Ketebalan garis tepi
        );

    final content = Container( // Bungkus konten dengan dekorasi kartu
      decoration: BoxDecoration(
        color: backgroundColor ?? context.warnaKartu, // Warna latar: custom atau ikut tema
        borderRadius: BorderRadius.circular(borderRadius), // Sudut membulat sesuai parameter
        border: cardBorder, // Pasang garis tepi yang sudah ditentukan
      ),
      child: Padding(
        padding: padding, // Beri jarak dalam sesuai parameter
        child: child, // Tampilkan konten asli
      ),
    );

    if (onTap == null) { // Jika tidak ada aksi ketuk
      return content; // Kembalikan kartu tanpa pembungkus interaksi
    }

    return GestureDetector( // Bungkus dengan detektor ketukan
      onTap: onTap, // Jalankan callback saat diketuk
      child: content, // Tampilan kartu yang sama
    );
  }
}

/// Card dengan shadow (elevated card)
class AppElevatedCard extends StatelessWidget { // Varian kartu dengan bayangan/efek terangkat
  final Widget child; // Konten di dalam kartu
  final EdgeInsetsGeometry padding; // Jarak dalam kartu
  final Color? backgroundColor; // Warna latar opsional
  final double borderRadius; // Radius sudut kartu
  final double elevation; // Seberapa besar bayangan
  final VoidCallback? onTap; // Aksi saat diketuk, opsional

  const AppElevatedCard({
    super.key,
    required this.child, // Konten wajib diisi
    this.padding = const EdgeInsets.all(16), // Default padding 16
    this.backgroundColor,
    this.borderRadius = 14, // Default sudut 14
    this.elevation = 4, // Default bayangan sedikit lebih besar dari AppCard
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Bayangan tidak terlihat di atas latar gelap — kartu bertumpuk
    // (warnaKartuMenonjol) plus garis tepi menggantikannya di sana,
    // bayangan aslinya dipertahankan untuk mode terang.
    final bool gelap = context.gelap; // Cek apakah tema aktif gelap
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? // Warna latar custom, atau...
            (gelap ? context.warnaKartuMenonjol : context.warnaKartu), // ...pilih sesuai mode gelap/terang
        borderRadius: BorderRadius.circular(borderRadius), // Sudut membulat
        border: gelap ? Border.all(color: context.warnaGaris) : null, // Garis tepi hanya muncul di mode gelap
        boxShadow: gelap
            ? null // Tidak ada bayangan di mode gelap
            : [
                BoxShadow( // Bayangan lembut untuk mode terang
                  color: AppColors.baseDark.withValues(alpha: 0.08), // Warna bayangan semi transparan
                  blurRadius: elevation, // Tingkat blur mengikuti elevation
                  offset: Offset(0, elevation / 2), // Geser bayangan ke bawah
                ),
              ],
      ),
      child: Padding(
        padding: padding, // Jarak dalam kartu
        child: child, // Konten asli
      ),
    );

    if (onTap == null) { // Tanpa aksi ketuk
      return content; // Kembalikan kartu polos
    }

    return GestureDetector( // Bungkus dengan interaksi ketuk
      onTap: onTap,
      child: content,
    );
  }
}

/// Card dengan highlight/tint background
class AppHighlightCard extends StatelessWidget { // Kartu dengan warna latar mencolok (highlight)
  final Widget child; // Konten kartu
  final EdgeInsetsGeometry padding; // Jarak dalam kartu
  final Color? backgroundColor; // Warna latar opsional
  final Color? borderColor; // Warna garis tepi opsional
  final double borderRadius; // Radius sudut
  final VoidCallback? onTap; // Aksi ketuk opsional

  const AppHighlightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.latarMasuk, // Default pakai warna latar "masuk" (aksen hijau/positif)
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (borderColor ?? context.warnaMasuk).withValues(alpha: 0.4), // Garis tepi transparan sebagian
          width: 1.5, // Ketebalan garis tepi
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

/// Header Card untuk section (biasanya di atas expandable item)
class AppCardHeader extends StatelessWidget { // Header kartu yang bisa diketuk untuk expand/collapse
  final String title; // Judul header
  final String? subtitle; // Sub-judul opsional
  final Widget? leading; // Widget di sisi kiri (mis. ikon), opsional
  final Widget? trailing; // Widget di sisi kanan, opsional
  final VoidCallback? onTap; // Aksi saat header diketuk
  final Color? backgroundColor; // Warna latar opsional
  final bool isExpanded; // Status apakah sedang terbuka (untuk ikon panah)

  const AppCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.isExpanded = false, // Default tertutup
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector( // Seluruh header bisa diketuk
      onTap: onTap,
      child: Container(
        color: backgroundColor ?? context.warnaKartu, // Warna latar header
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16), // Padding asimetris (kanan lebih kecil)
        child: Row( // Susun leading, judul, trailing secara horizontal
          children: [
            if (leading != null) ...[ // Tampilkan leading jika ada
              leading!,
              const SizedBox(width: 12), // Jarak setelah leading
            ],
            Expanded( // Bagian judul mengisi sisa ruang
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                children: [
                  Text(
                    title, // Tampilkan judul
                    style: AppTypography.titleSmall.copyWith(
                      color: context.warnaTeksUtama, // Warna teks utama sesuai tema
                    ),
                  ),
                  if (subtitle != null) ...[ // Tampilkan subtitle jika ada
                    const SizedBox(height: 2), // Jarak kecil di atas subtitle
                    Text(
                      subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.warnaTeksMuted, // Warna teks lebih redup untuk subtitle
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) // Jika ada widget trailing kustom
              trailing! // Tampilkan itu
            else if (onTap != null) // Jika tidak ada trailing tapi bisa diketuk
              Icon( // Tampilkan ikon panah expand/collapse
                isExpanded ? Icons.expand_less : Icons.expand_more, // Ikon berubah sesuai status
                color: context.warnaTeksMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Content Card untuk menampilkan informasi berpasangan (label-value)
class AppInfoCard extends StatelessWidget { // Baris info berformat label di kiri, nilai di kanan
  final String label; // Teks label
  final String value; // Teks nilai
  final TextStyle? labelStyle; // Gaya teks label kustom, opsional
  final TextStyle? valueStyle; // Gaya teks nilai kustom, opsional
  final Color? labelColor; // Warna label kustom, opsional
  final Color? valueColor; // Warna nilai kustom, opsional
  final Widget? trailing; // Widget tambahan di ujung kanan, opsional

  const AppInfoCard({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.labelColor,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8), // Jarak vertikal antar baris info
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Label kiri, nilai kanan, beri jarak
        children: [
          Text(
            label, // Tampilkan teks label
            style: labelStyle ?? // Pakai gaya kustom jika ada, atau...
                AppTypography.bodyMedium.copyWith(
                  color: labelColor ?? context.warnaTeksMuted, // ...warna default redup
                ),
          ),
          const SizedBox(width: 8), // Jarak antara label dan nilai
          Expanded( // Nilai mengisi sisa ruang agar teks panjang tidak overflow
            child: Text(
              value, // Tampilkan teks nilai
              textAlign: TextAlign.right, // Rata kanan
              style: valueStyle ??
                  AppTypography.labelSmall.copyWith(
                    color: valueColor ?? context.warnaTeksUtama, // Default warna teks utama
                  ),
            ),
          ),
          if (trailing != null) ...[ // Jika ada widget tambahan
            const SizedBox(width: 8), // Jarak sebelum trailing
            trailing!, // Tampilkan widget tambahan
          ],
        ],
      ),
    );
  }
}
