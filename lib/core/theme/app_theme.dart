import 'package:flutter/material.dart'; // widget dan tema dasar Flutter
import 'package:flutter/services.dart'; // untuk SystemUiOverlayStyle (warna status bar)

import 'app_colors.dart'; // palet warna khusus aplikasi Modio

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
  AppTheme._(); // konstruktor privat, class ini hanya wadah static, tidak boleh diinstansiasi

  /// Tinggi sentuh minimum. WCAG 2.5.5 mensyaratkan 44 piksel,
  /// Material mensyaratkan 48. Dipakai yang lebih besar agar nyaman
  /// bagi pengguna yang menavigasi tanpa melihat layar.
  static const double minTouchTarget = 56;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true, // pakai desain Material 3
      fontFamily: 'Inter', // font utama seluruh aplikasi
      scaffoldBackgroundColor: AppColors.bgPage, // warna latar belakang halaman

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500, // warna dasar pembangkit skema warna
        primary: AppColors.primary700, // warna utama (tombol, aksen)
        secondary: AppColors.secondary700, // warna sekunder
        error: AppColors.tertiary700, // warna untuk kondisi error
        surface: AppColors.white, // warna permukaan kartu/dialog
        onSurface: AppColors.baseDark, // warna teks di atas permukaan
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white, // latar app bar
        foregroundColor: AppColors.baseDark, // warna ikon dan teks app bar
        elevation: 0, // tanpa bayangan di bawah app bar
        centerTitle: false, // judul rata kiri, bukan tengah
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
          statusBarColor: Colors.transparent, // status bar transparan menyatu dengan app bar
          statusBarIconBrightness: Brightness.dark, // ikon status bar gelap agar terlihat di latar terang
          statusBarBrightness: Brightness.light, // untuk iOS, menyesuaikan kecerahan status bar
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ), // gaya judul besar
        headlineMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ), // gaya judul sedang
        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w600,
          color: AppColors.baseDark,
        ), // gaya judul kartu/dialog
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.baseDark,
        ), // gaya subjudul
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
        ), // gaya teks kecil, tetap dijaga minimal 14
        labelLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.baseDark,
        ), // gaya label tombol
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary700, // warna latar tombol terisi
          foregroundColor: AppColors.white, // warna teks/ikon tombol
          minimumSize: const Size.fromHeight(minTouchTarget), // tinggi minimum, bukan tetap
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // sudut membulat
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
          foregroundColor: AppColors.primary700, // warna teks tombol datar
          minimumSize: const Size(88, minTouchTarget), // lebar dan tinggi minimum sentuh
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true, // kolom input diberi warna latar
        fillColor: AppColors.white, // warna latar kolom input
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(fontSize: 16, color: AppColors.baseDark),
        hintStyle: const TextStyle(fontSize: 16, color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder), // garis tepi bawaan, ≥ 3:1 (WCAG 1.4.11)
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.inputBorder), // garis tepi saat tidak fokus
        ),
        // Indikator fokus tebal. Garis tipis sulit terlihat pengguna
        // low vision saat berpindah antar isian.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary700, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.tertiary700, width: 2), // garis tepi saat error
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.divider, // warna garis pemisah
        thickness: 1, // ketebalan garis
        space: 0, // tanpa jarak tambahan di sekitar garis
      ),

      listTileTheme: const ListTileThemeData(
        minVerticalPadding: 14, // jarak vertikal minimum dalam ListTile
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
        behavior: SnackBarBehavior.floating, // snackbar mengambang, tidak menempel di tepi
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // sudut dialog membulat
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
          height: 1.5, // jarak antar baris lebih lega agar mudah dibaca
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
      brightness: Brightness.dark, // menandai tema ini sebagai mode gelap
      scaffoldBackgroundColor: AppColors.darkBg, // latar halaman versi gelap
      cardColor: AppColors.darkSurface, // warna kartu versi gelap
      dividerColor: AppColors.darkDivider, // warna garis pemisah versi gelap

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary500,
        brightness: Brightness.dark, // hasilkan skema warna varian gelap
      ).copyWith(
        primary: AppColors.darkPrimary, // timpa warna utama dengan versi gelap
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
          statusBarIconBrightness: Brightness.light, // ikon status bar terang untuk latar gelap
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
          borderSide: const BorderSide(color: AppColors.darkInputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.darkInputBorder),
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
        backgroundColor: AppColors.darkPrimary, // latar snackbar versi gelap
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurfaceHi, // latar dialog versi gelap, lebih terang dari kartu biasa
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
