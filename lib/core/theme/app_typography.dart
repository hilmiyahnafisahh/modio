import 'package:flutter/material.dart';

import '../services/aksesibilitas_controller.dart';
import 'app_colors.dart';

/// ─────────────────────────────────────────────────────────────────
/// APP TYPOGRAPHY  –  Sistem tipografi terpusat
///
/// Semua text style harus menggunakan kelas ini untuk konsistensi.
/// Format: {hierarki}{size}, contoh: headingLarge, bodySmall, labelSmall
///
/// Setiap gaya adalah GETTER, bukan `static const`, karena beratnya
/// harus bisa naik saat sakelar "Teks Tebal" (Pengaturan Aksesibilitas)
/// aktif — dibaca langsung dari AksesibilitasController lewat [_b],
/// funnel tunggal yang sama untuk seluruh 16 gaya di berkas ini.
/// ─────────────────────────────────────────────────────────────────

class AppTypography {
  AppTypography._();

  /// Menaikkan bobot font satu-dua tingkat saat Teks Tebal aktif.
  /// Dipetakan manual (bukan `FontWeight.values[index + n]`) supaya
  /// hasilnya selalu FontWeight yang valid dan lompatannya terasa
  /// jelas, bukan naik satu tingkat yang nyaris tak terlihat.
  static FontWeight _b(FontWeight dasar) {
    if (!AksesibilitasController.instance.teksTebal.value) return dasar;
    return switch (dasar) {
      FontWeight.w400 => FontWeight.w700,
      FontWeight.w500 => FontWeight.w700,
      FontWeight.w600 => FontWeight.w800,
      FontWeight.w700 => FontWeight.w800,
      FontWeight.w800 => FontWeight.w900,
      _ => FontWeight.w900,
    };
  }

  // ── HEADING ──────────────────────────────────────────────────────
  /// Heading terbesar (30px, w700) - untuk judul halaman utama
  static TextStyle get headingLarge => TextStyle(
    fontFamily: 'Inter',
    fontSize: 30,
    fontWeight: _b(FontWeight.w700),
    color: AppColors.baseDark,
    height: 1.2,
  );

  /// Heading sedang (24px, w700) - untuk sub judul
  static TextStyle get headingMedium => TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: _b(FontWeight.w700),
    color: AppColors.baseDark,
    height: 1.2,
  );

  /// Heading kecil (22px, w700) - untuk nama pengguna/konten penting
  static TextStyle get headingSmall => TextStyle(
    fontFamily: 'Inter',
    fontSize: 22,
    fontWeight: _b(FontWeight.w700),
    color: AppColors.baseDark,
    height: 1.2,
  );

  // ── TITLE ────────────────────────────────────────────────────────
  /// Title besar (19px, w600) - untuk kategori, header section
  static TextStyle get titleLarge => TextStyle(
    fontFamily: 'Inter',
    fontSize: 19,
    fontWeight: _b(FontWeight.w600),
    color: AppColors.baseDark,
    height: 1.3,
  );

  /// Title sedang (17px, w600) - untuk app bar, judul modal
  static TextStyle get titleMedium => TextStyle(
    fontFamily: 'Inter',
    fontSize: 17,
    fontWeight: _b(FontWeight.w600),
    color: AppColors.baseDark,
    height: 1.3,
  );

  /// Title kecil (16px, w600) - untuk item list, card header
  static TextStyle get titleSmall => TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: _b(FontWeight.w600),
    color: AppColors.baseDark,
    height: 1.3,
  );

  // ── BODY (Regular) ───────────────────────────────────────────────
  /// Body besar (16px, w400) - teks utama, isi paragraf
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: _b(FontWeight.w400),
    color: AppColors.baseDark,
    height: 1.5,
  );

  /// Body sedang (15px, w400) - deskripsi, isi card sekunder
  static TextStyle get bodyMedium => TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: _b(FontWeight.w400),
    color: AppColors.textMuted,
    height: 1.5,
  );

  /// Body kecil (14px, w400) - metadata, informasi tambahan
  static TextStyle get bodySmall => TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: _b(FontWeight.w400),
    color: AppColors.textMuted,
    height: 1.5,
  );

  // ── LABEL ────────────────────────────────────────────────────────
  /// Label besar (16px, w600) - tombol, tag, label form
  static TextStyle get labelLarge => TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: _b(FontWeight.w600),
    color: AppColors.baseDark,
    height: 1.3,
  );

  /// Label sedang (15px, w500) - label item, metadata penting
  static TextStyle get labelMedium => TextStyle(
    fontFamily: 'Inter',
    fontSize: 15,
    fontWeight: _b(FontWeight.w500),
    color: AppColors.baseDark,
    height: 1.3,
  );

  /// Label kecil (14px, w500) - secondary text, hint
  static TextStyle get labelSmall => TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: _b(FontWeight.w500),
    color: AppColors.baseDark,
    height: 1.3,
  );

  // ── CAPTION (untuk dekorasi non-informatif) ─────────────────────
  /// Caption (13px, w400) - keterangan ringan, watermark
  static TextStyle get captionLarge => TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: _b(FontWeight.w400),
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// Caption kecil (12px, w400) - dekorasi, hint teks
  static TextStyle get captionSmall => TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: _b(FontWeight.w400),
    color: AppColors.textMuted,
    height: 1.4,
  );

  // ── NUMERIC (untuk angka/nominal) ────────────────────────────────
  /// Numeric besar (18px, w700) - untuk nominal, total
  static TextStyle get numericLarge => TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: _b(FontWeight.w700),
    color: AppColors.baseDark,
    height: 1.3,
  );

  /// Numeric sedang (16px, w700) - nominal item list
  static TextStyle get numericMedium => TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: _b(FontWeight.w700),
    color: AppColors.baseDark,
    height: 1.3,
  );

  // ── HELPER METHODS untuk Dynamic Colors ──────────────────────────
  /// Buat TextStyle dari preset dengan warna custom
  static TextStyle copyWith({
    required TextStyle style,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
  }) {
    return style.copyWith(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
    );
  }

  /// Body style dengan warna custom (untuk income/expense)
  static TextStyle bodyMediumWithColor(Color color) {
    return bodyMedium.copyWith(color: color);
  }

  /// Title style dengan warna custom
  static TextStyle titleSmallWithColor(Color color) {
    return titleSmall.copyWith(color: color);
  }

  /// Numeric style dengan warna custom
  static TextStyle numericMediumWithColor(Color color) {
    return numericMedium.copyWith(color: color);
  }
}
