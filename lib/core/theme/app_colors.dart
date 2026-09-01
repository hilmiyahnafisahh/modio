import 'package:flutter/material.dart'; // Untuk tipe Color

/// ─────────────────────────────────────────────────────────────────
/// APP COLORS  –  Sistem warna Modio
///
/// Setiap warna yang dipakai untuk TEKS mencantumkan rasio kontras
/// terukurnya terhadap latar putih. Ambang WCAG 2.1:
///   • AA  = 4.5:1  (minimum wajib)
///   • AAA = 7.0:1  (klaim MODIO)
///
/// JANGAN mengganti nilai hex tanpa menghitung ulang rasionya.
/// Gunakan contrast checker mana pun untuk memverifikasi.
///
/// Aturan pemakaian:
///   • Warna berakhiran 50   → HANYA untuk latar, tidak pernah teks
///   • Warna berakhiran 500  → HANYA untuk ikon dan garis, tidak teks
///   • Warna berakhiran 700+ → aman untuk teks di atas latar terang
/// ─────────────────────────────────────────────────────────────────

class AppColors { // Kumpulan konstanta warna aplikasi
  AppColors._(); // Konstruktor privat, kelas ini hanya wadah statis

  // ── Primary Emerald (Hijau) ──────────────────────────────────────
  static const Color primary900 = Color(0xFF064E3B); // latar gelap, putih 9,7:1
  static const Color primary700 = Color(0xFF03543F); // teks 8,3:1 ✓ AAA
  static const Color primary500 = Color(0xFF10B981); // ikon & garis saja
  static const Color primary400 = Color(0xFF34D399); // dekorasi
  static const Color primary50  = Color(0xFFECFDF5); // latar saja

  // ── Secondary Sky (Biru) ────────────────────────────────────────
  static const Color secondary900 = Color(0xFF0C4A6E); // warna biru gelap
  static const Color secondary700 = Color(0xFF075985); // teks 7,6:1 ✓ AAA
  static const Color secondary500 = Color(0xFF0EA5E9); // ikon & garis saja
  static const Color secondary400 = Color(0xFF38BDF8); // dekorasi
  static const Color secondary50  = Color(0xFFF0F9FF); // latar saja

  // ── Tertiary Coral (Merah) ───────────────────────────────────────
  static const Color tertiary900 = Color(0xFF2D1517); // warna merah sangat gelap

  /// Teks 9,2:1 ✓ AAA
  ///
  /// Digelapkan dari #B91C1C yang hanya mencapai 6,5:1 — lolos AA
  static const Color tertiary700 = Color(0xFF8F1515); // aman dipakai sebagai warna teks merah

  /// IKON DAN GARIS SAJA, JANGAN UNTUK TEKS.
  ///
  /// #EF4444 hanya mencapai 3,8:1 terhadap putih — gagal bahkan
  /// standar AA. Sebelumnya warna ini dipakai untuk nominal
  /// pengeluaran, yaitu angka yang justru paling penting terbaca.
  /// Untuk teks merah, gunakan tertiary700.
  static const Color tertiary500 = Color(0xFFEF4444); // hanya untuk ikon/garis, bukan teks

  static const Color tertiary400 = Color(0xFFFF5A5A); // dekorasi
  static const Color tertiary50  = Color(0xFFFEF2F2); // latar saja

  // ── Amber (kartu jumlah transaksi) ───────────────────────────────
  static const Color amber700 = Color(0xFF92400E); // teks 7,4:1 ✓ AAA
  static const Color amber50  = Color(0xFFFFFBEB); // latar saja

  // ── Warna Netral ────────────────────────────────────────────────
  static const Color baseDark  = Color(0xFF1A1A1A);  // teks 17,4:1 ✓ AAA
  static const Color white     = Color(0xFFFFFFFF); // warna putih murni
  static const Color bgPage    = Color(0xFFFFFFFF);  // putih bersih
  static const Color inputFill = Color(0xFFF5F5F5);  // latar input field di atas putih
  static const Color divider   = Color(0xFFE2E4E9);  // garis & border kartu

  /// Teks sekunder, 7,6:1 ✓ AAA
  ///
  /// Digelapkan dari #6B7280 yang hanya mencapai 4,8:1. Warna ini
  /// dipakai untuk waktu, metode bayar, dan keterangan — informasi
  /// yang tetap harus terbaca pengguna low vision, bukan sekadar
  /// pelengkap visual.
  static const Color textMuted = Color(0xFF4B5563); // warna teks sekunder/keterangan

  // ── Mode Gelap ───────────────────────────────────────────────────
  // Latar memakai hitam netral standar Material Design, tanpa
  // undertone warna, dan lebih gelap dari abu #212121 yang dipakai
  // sebelumnya sehingga seluruh rasio kontras naik. Seluruh rasio di
  // bawah dihitung terhadap #121212 dan diverifikasi ulang manual
  // (formula relative luminance WCAG), bukan disalin dari klaim lain.
  //
  // PERINGATAN: warna berakhiran 700 pada palet terang TIDAK BOLEH
  // dipakai di mode gelap. Warna itu dirancang untuk latar putih;
  // terhadap latar gelap rasionya sekitar 2:1, jauh di bawah ambang
  // AA 4,5:1.
  static const Color darkBg        = Color(0xFF121212); // latar halaman
  static const Color darkSurface   = Color(0xFF1E1E1E); // kartu
  static const Color darkSurfaceHi = Color(0xFF2A2A2A); // kartu menonjol
  static const Color darkDivider   = Color(0xFF3D3D3D); // garis pemisah

  static const Color darkText      = Color(0xFFF8FAFC); // 17,9:1 ✓ AAA
  static const Color darkTextMuted = Color(0xFFCBD5E1); // 12,6:1 ✓ AAA

  static const Color darkPrimary   = Color(0xFF34D399); //  9,7:1 ✓ AAA
  static const Color darkIncome    = Color(0xFF34D399); //  9,7:1 ✓ AAA
  static const Color darkExpense   = Color(0xFFFF9494); //  8,9:1 ✓ AAA
  static const Color darkInfo      = Color(0xFF38BDF8); //  8,7:1 ✓ AAA

  // Latar kartu berwarna, sengaja sangat gelap. Latar pastel terang
  // (mis. primary50/tertiary50) di atas mode gelap menimbulkan silau,
  // yaitu masalah yang justru ingin dihindari oleh mode gelap.
  static const Color darkIncomeBg  = Color(0xFF10291F); // latar kartu pemasukan mode gelap
  static const Color darkExpenseBg = Color(0xFF2E1A1A); // latar kartu pengeluaran mode gelap
  static const Color darkInfoBg    = Color(0xFF122430); // latar kartu info mode gelap

  // Padanan gelap untuk kartu "Transaksi" (amber700/amber50 pada
  // palet terang). amber700 terhadap latar gelap juga jatuh di bawah
  // ambang AA seperti warna 700 lain, jadi butuh nada terang sendiri.
  static const Color darkAmber   = Color(0xFFFCD34D); // 13,0:1 ✓ AAA
  static const Color darkAmberBg = Color(0xFF2E2410); // latar kartu amber mode gelap
}
