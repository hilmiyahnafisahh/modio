import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// ─────────────────────────────────────────────────────────────────
/// APP THEME  –  Konfigurasi tema global aplikasi Modio
///
/// Dua prinsip yang dipegang di seluruh berkas ini:
///
/// 1. TIDAK ADA TINGGI TETAP pada komponen yang memuat teks.
///    Gunakan minimumSize atau BoxConstraints(minHeight:). Tinggi
///    tetap memotong label begitu pengguna memperbesar teks sistem,
///    dan itu penyebab paling umum kegagalan pada aplikasi yang
///    mengaku mendukung pembesaran 200 persen.
///
/// 2. UKURAN TEKS MINIMUM 14.
///    Ukuran di bawah itu praktis tidak terbaca oleh pengguna low
///    vision. Teks yang lebih kecil hanya boleh untuk dekorasi yang
///    tidak membawa informasi.
/// ─────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  /// Tinggi sentuh minimum. WCAG 2.5.5 mensyaratkan 44 piksel,
  /// Material mensyaratkan 48. Dipakai yang lebih besar agar nyaman
  /// bagi pengguna yang menavigasi tanpa melihat layar.
  static const double minTouchTarget = 56;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.bgPage,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        primary: AppColors.primary700,
        secondary: AppColors.secondary700,
        error: AppColors.tertiary700,
        surface: AppColors.white,
        onSurface: AppColors.baseDark,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.baseDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ),
        // Latar terang perlu ikon bilah status gelap — tanpa ini
        // ikonnya memakai warna bawaan yang ternyata putih, dan
        // menghilang di atas latar putih.
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.baseDark,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.baseDark,
        ),
        // Dinaikkan dari 14. Ini gaya teks utama aplikasi.
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.baseDark,
        ),
        // Dinaikkan dari 12, ukuran yang sulit dibaca pengguna
        // low vision padahal memuat informasi.
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.baseDark,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary700,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary700,
          minimumSize: const Size(88, minTouchTarget),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(fontSize: 16, color: AppColors.baseDark),
        hintStyle: const TextStyle(fontSize: 16, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        // Indikator fokus tebal. Garis tipis sulit terlihat pengguna
        // low vision saat berpindah antar isian.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary700, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary700, width: 2),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 0,
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          color: AppColors.white,
        ),
        // Lebih lama dari bawaan empat detik. Pengguna screen reader
        // membutuhkan waktu lebih untuk mendengar dan memproses pesan.
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          height: 1.5,
          color: AppColors.baseDark,
        ),
      ),
    );
  }

  /// Struktur persis sama dengan [lightTheme] — ukuran teks, tinggi
  /// sentuh minimum, dan ketebalan garis fokus tidak berubah, cuma
  /// warnanya. Warna berakhiran 700 pada palet terang TIDAK dipakai
  /// ulang di sini (lihat peringatan pada blok "Mode Gelap" di
  /// app_colors.dart) — rasio kontrasnya terhadap latar gelap jauh
  /// di bawah ambang AA.
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkDivider,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.darkPrimary,
        secondary: AppColors.darkInfo,
        error: AppColors.darkExpense,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        // Teks gelap di atas hijau terang — teks putih di atas
        // #34D399 hanya mencapai 1,8:1, teks gelap mencapai 8,4:1.
        onPrimary: AppColors.darkBg,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkText,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextMuted,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkPrimary,
          foregroundColor: AppColors.darkBg,
          minimumSize: const Size.fromHeight(minTouchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          minimumSize: const Size(88, minTouchTarget),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(fontSize: 16, color: AppColors.darkText),
        hintStyle:
            const TextStyle(fontSize: 16, color: AppColors.darkTextMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkPrimary, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkExpense, width: 2),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 0,
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      snackBarTheme: const SnackBarThemeData(
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          color: AppColors.darkBg,
        ),
        backgroundColor: AppColors.darkPrimary,
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurfaceHi,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          height: 1.5,
          color: AppColors.darkText,
        ),
      ),
    );
  }
}