import 'package:flutter/material.dart';

import '../services/aksesibilitas_controller.dart';
import 'app_colors.dart';

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
extension AppThemeContext on BuildContext {
  bool get gelap => Theme.of(this).brightness == Brightness.dark;

  /// Sakelar "Kontras Tinggi" di Pengaturan Aksesibilitas. Dibaca
  /// langsung dari controller (bukan lewat parameter widget) supaya
  /// setiap pemakai `context.warnaTeksMuted`/`warnaGaris` di seluruh
  /// aplikasi otomatis ikut naik kontrasnya tanpa perlu disentuh
  /// satu per satu — funnel yang sama yang dipakai `gelap`.
  bool get kontrasTinggi => AksesibilitasController.instance.kontrasTinggi.value;

  Color get warnaKartu => gelap ? AppColors.darkSurface : AppColors.white;
  Color get warnaKartuMenonjol =>
      gelap ? AppColors.darkSurfaceHi : AppColors.white;
  Color get warnaTeksUtama => gelap ? AppColors.darkText : AppColors.baseDark;

  // Kontras Tinggi menghapus tingkat "diredam" sepenuhnya — teks
  // sekunder memakai kekuatan penuh yang sama dengan teks utama,
  // bukan cuma versi yang sedikit lebih gelap dari textMuted biasa.
  Color get warnaTeksMuted => kontrasTinggi
      ? warnaTeksUtama
      : (gelap ? AppColors.darkTextMuted : AppColors.textMuted);

  Color get warnaGaris => kontrasTinggi
      ? warnaTeksUtama.withValues(alpha: 0.7)
      : (gelap ? AppColors.darkDivider : AppColors.divider);

  // Pemasukan/pengeluaran: tertiary700 dan primary700 dari palet
  // terang TIDAK dipakai ulang di mode gelap (kontras terhadap
  // #212121 jauh di bawah AA — lihat peringatan di app_colors.dart).
  Color get warnaMasuk => gelap ? AppColors.darkIncome : AppColors.primary700;
  Color get warnaKeluar =>
      gelap ? AppColors.darkExpense : AppColors.tertiary700;
  Color get latarMasuk =>
      gelap ? AppColors.darkIncomeBg : AppColors.primary50;
  Color get latarKeluar =>
      gelap ? AppColors.darkExpenseBg : AppColors.tertiary50;

  // Aksen biru (mis. kartu laba/rugi, wawasan AI) dan amber (kartu
  // jumlah transaksi) — sama-sama butuh padanan gelap karena warna
  // 700/50 milik palet terang tidak aman dipakai ulang.
  Color get warnaInfo => gelap ? AppColors.darkInfo : AppColors.secondary700;
  Color get latarInfo => gelap ? AppColors.darkInfoBg : AppColors.secondary50;
  Color get warnaAmber => gelap ? AppColors.darkAmber : AppColors.amber700;
  Color get latarAmber => gelap ? AppColors.darkAmberBg : AppColors.amber50;
}
