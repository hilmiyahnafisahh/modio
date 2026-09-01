import 'package:flutter/material.dart'; // Untuk BuildContext, Color, Theme

import '../services/aksesibilitas_controller.dart'; // Pengelola pengaturan aksesibilitas
import 'app_colors.dart'; // Palet warna aplikasi

/// ─────────────────────────────────────────────────────────────────
/// THEME EXTENSIONS  –  Pasangan warna terang/gelap siap pakai
///
/// AppTypography menetapkan UKURAN dan KETEBALAN teks, tapi warnanya
/// tertanam tetap (AppColors.baseDark dkk) sehingga tidak ikut
/// berubah saat mode gelap aktif. Dipakai bersama
/// `AppTypography.xxx.copyWith(color: context.warnaTeksUtama)` di
/// setiap tempat yang butuh teks sadar-tema, alih-alih menuliskan
/// ulang ternary brightness di setiap berkas.
/// ─────────────────────────────────────────────────────────────────
extension AppThemeContext on BuildContext { // Tambahan fungsi/getter pada BuildContext untuk akses warna tema
  bool get gelap => Theme.of(this).brightness == Brightness.dark; // true jika tema aktif mode gelap

  /// Sakelar "Kontras Tinggi" di Pengaturan Aksesibilitas. Dibaca
  /// langsung dari controller (bukan lewat parameter widget) supaya
  /// setiap pemakai `context.warnaTeksMuted`/`warnaGaris` di seluruh
  /// aplikasi otomatis ikut naik kontrasnya tanpa perlu disentuh
  /// satu per satu — funnel yang sama yang dipakai `gelap`.
  bool get kontrasTinggi => AksesibilitasController.instance.kontrasTinggi.value; // Status sakelar kontras tinggi

  Color get warnaKartu => gelap ? AppColors.darkSurface : AppColors.white; // Warna latar kartu sesuai tema
  Color get warnaKartuMenonjol => // Warna latar kartu yang lebih menonjol sesuai tema
      gelap ? AppColors.darkSurfaceHi : AppColors.white;
  Color get warnaTeksUtama => gelap ? AppColors.darkText : AppColors.baseDark; // Warna teks utama sesuai tema

  // Kontras Tinggi menghapus tingkat "diredam" sepenuhnya — teks
  // sekunder memakai kekuatan penuh yang sama dengan teks utama,
  // bukan cuma versi yang sedikit lebih gelap dari textMuted biasa.
  Color get warnaTeksMuted => kontrasTinggi // Warna teks sekunder, naik ke kontras penuh jika diaktifkan
      ? warnaTeksUtama
      : (gelap ? AppColors.darkTextMuted : AppColors.textMuted);

  Color get warnaGaris => kontrasTinggi // Warna garis pemisah, lebih tegas jika kontras tinggi aktif
      ? warnaTeksUtama.withValues(alpha: 0.7)
      : (gelap ? AppColors.darkDivider : AppColors.divider);

  // Pemasukan/pengeluaran: tertiary700 dan primary700 dari palet
  // terang TIDAK dipakai ulang di mode gelap (kontras terhadap
  // #212121 jauh di bawah AA — lihat peringatan di app_colors.dart).
  Color get warnaMasuk => gelap ? AppColors.darkIncome : AppColors.primary700; // Warna teks/ikon untuk pemasukan
  Color get warnaKeluar => // Warna teks/ikon untuk pengeluaran
      gelap ? AppColors.darkExpense : AppColors.tertiary700;
  Color get latarMasuk => // Warna latar kartu/badge pemasukan
      gelap ? AppColors.darkIncomeBg : AppColors.primary50;
  Color get latarKeluar => // Warna latar kartu/badge pengeluaran
      gelap ? AppColors.darkExpenseBg : AppColors.tertiary50;

  // Aksen biru (mis. kartu laba/rugi, wawasan AI) dan amber (kartu
  // jumlah transaksi) — sama-sama butuh padanan gelap karena warna
  // 700/50 milik palet terang tidak aman dipakai ulang.
  Color get warnaInfo => gelap ? AppColors.darkInfo : AppColors.secondary700; // Warna aksen informasi
  Color get latarInfo => gelap ? AppColors.darkInfoBg : AppColors.secondary50; // Warna latar kartu informasi
  Color get warnaAmber => gelap ? AppColors.darkAmber : AppColors.amber700; // Warna aksen amber
  Color get latarAmber => gelap ? AppColors.darkAmberBg : AppColors.amber50; // Warna latar kartu amber
}
