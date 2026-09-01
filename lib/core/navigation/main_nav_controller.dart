import 'package:flutter/foundation.dart'; // Untuk ValueNotifier (state yang bisa didengarkan)

/// ─────────────────────────────────────────────────────────────────
/// NAVIGASI SUARA  –  Pindah tab lewat perintah ucapan
///
/// Tombol mic ada di banyak halaman (Dashboard, Riwayat, Laporan,
/// Profil), masing-masing tanpa akses langsung ke state MainPage yang
/// memegang tab aktif. Controller singleton ini jadi titik temu:
/// halaman mana pun bisa memanggil [MainNavController.pindahKe] tanpa
/// perlu mengalirkan callback lewat setiap konstruktor.
/// ─────────────────────────────────────────────────────────────────

enum VoiceNavTarget { // Daftar tujuan navigasi yang bisa dituju lewat suara
  dashboard,
  riwayat,
  laporan,
  profil,
  aiChat,
  informasiProfil,
  gantiPin,
  aksesibilitas,
  tentangAplikasi,
}

const List<String> _prefixNavigasi = ['buka ', 'ke ', 'pindah ke ', 'pergi ke ']; // Kata awalan penanda perintah navigasi

/// Mengenali apakah [teksAsli] adalah perintah pindah halaman, murni
/// lewat cocok kata kunci lokal — tanpa AI, gratis, instan. Perintah
/// biasa (dashboard/riwayat/laporan/profil) wajib diawali kata seperti
/// "buka"/"ke" supaya ucapan transaksi yang kebetulan menyebut kata
/// serupa tidak salah terdeteksi sebagai navigasi. Asisten AI dikecualikan
/// karena wajar diucapkan singkat tanpa awalan itu, misalnya cuma "chat AI".
VoiceNavTarget? deteksiPerintahNavigasi(String teksAsli) { // Deteksi tujuan navigasi dari teks ucapan
  final String teks = teksAsli.trim().toLowerCase(); // Bersihkan spasi dan samakan huruf kecil
  if (teks.isEmpty) return null; // Teks kosong, tidak ada perintah

  if (teks.contains('chat ai') || // Cek berbagai frasa yang merujuk Asisten AI
      teks.contains('ai chat') ||
      teks.contains('asisten ai') ||
      teks.contains('analisis ai')) {
    return VoiceNavTarget.aiChat; // Langsung kembalikan tujuan Asisten AI tanpa perlu prefix
  }

  String? sisa; // Teks setelah prefix navigasi dibuang
  for (final String prefix in _prefixNavigasi) { // Cari prefix yang cocok dengan awal teks
    if (teks.startsWith(prefix)) {
      sisa = teks.substring(prefix.length).trim(); // Ambil teks setelah prefix
      break; // Berhenti setelah prefix pertama yang cocok
    }
  }
  if (sisa == null || sisa.isEmpty) return null; // Tidak ada prefix cocok, bukan perintah navigasi

  // Sub-halaman Profil dicek lebih dulu — namanya sendiri mengandung
  // kata "profil", jadi harus menang sebelum sampai ke cek tab Profil
  // yang lebih umum di bawah (kalau tidak, "buka informasi profil"
  // akan salah berhenti di tab Profil saja).
  if (sisa.contains('informasi profil') || // Cek berbagai variasi frasa Informasi Profil
      sisa.contains('info profil') ||
      sisa.contains('data profil')) {
    return VoiceNavTarget.informasiProfil;
  }
  if (sisa.contains('ganti pin') || sisa.contains('ubah pin')) { // Cek frasa untuk halaman Ganti PIN
    return VoiceNavTarget.gantiPin;
  }
  if (sisa.contains('aksesibilitas')) { // Cek frasa untuk halaman Aksesibilitas
    return VoiceNavTarget.aksesibilitas;
  }
  if (sisa.contains('tentang')) { // Cek frasa untuk halaman Tentang Aplikasi
    return VoiceNavTarget.tentangAplikasi;
  }

  if (sisa.contains('beranda') || sisa.contains('dashboard')) { // Cek frasa untuk tab Dashboard
    return VoiceNavTarget.dashboard;
  }
  if (sisa.contains('riwayat') || // Cek frasa untuk tab Riwayat
      sisa.contains('history') ||
      sisa.contains('transaksi')) {
    return VoiceNavTarget.riwayat;
  }
  if (sisa.contains('laporan')) return VoiceNavTarget.laporan; // Cek frasa untuk tab Laporan
  if (sisa.contains('profil')) return VoiceNavTarget.profil; // Cek frasa untuk tab Profil

  return null; // Tidak ada tujuan yang cocok
}

/// Nama halaman yang diumumkan lewat TalkBack begitu navigasi suara
/// berhasil — supaya pengguna tunanetra tahu ia benar mendarat di
/// halaman yang dimaksud, tanpa perlu meraba-raba UI dulu.
String labelHalaman(VoiceNavTarget target) => switch (target) { // Pemetaan tujuan ke label yang dibacakan
      VoiceNavTarget.dashboard => 'Dashboard',
      VoiceNavTarget.riwayat => 'Riwayat',
      VoiceNavTarget.laporan => 'Laporan',
      VoiceNavTarget.profil => 'Profil',
      VoiceNavTarget.aiChat => 'Asisten AI',
      VoiceNavTarget.informasiProfil => 'Informasi Profil',
      VoiceNavTarget.gantiPin => 'Ganti PIN',
      VoiceNavTarget.aksesibilitas => 'Pengaturan Aksesibilitas',
      VoiceNavTarget.tentangAplikasi => 'Tentang Aplikasi',
    };

class MainNavController { // Controller singleton pengelola tab aktif dan navigasi lepas
  MainNavController._(); // Konstruktor privat untuk pola singleton
  static final MainNavController instance = MainNavController._(); // Satu-satunya instance controller

  /// Indeks tab aktif di bottom nav (bukan indeks body IndexedStack —
  /// lihat `_bodyIndexForNav` di MainPage untuk pemetaannya).
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0); // Indeks tab aktif, bisa didengarkan perubahannya

  /// Diisi oleh MainPage selama ia aktif. Menangani tujuan yang bukan
  /// tab bottom-nav biasa (Asisten AI, sub-halaman Profil) lewat
  /// Navigator.push — MainPage yang tahu widget halaman sebenarnya,
  /// controller ini sengaja tidak mengimpor halaman fitur mana pun.
  void Function(VoiceNavTarget target)? bukaHalamanLepas; // Callback untuk membuka halaman di luar bottom nav

  void pindahKe(VoiceNavTarget target) { // Eksekusi perpindahan ke tujuan navigasi
    switch (target) {
      case VoiceNavTarget.dashboard:
        currentIndex.value = 0; // Pindah ke tab Dashboard
      case VoiceNavTarget.riwayat:
        currentIndex.value = 1; // Pindah ke tab Riwayat
      case VoiceNavTarget.laporan:
        currentIndex.value = 3; // Pindah ke tab Laporan
      case VoiceNavTarget.profil:
        currentIndex.value = 4; // Pindah ke tab Profil
      case VoiceNavTarget.aiChat:
      case VoiceNavTarget.informasiProfil:
      case VoiceNavTarget.gantiPin:
      case VoiceNavTarget.aksesibilitas:
      case VoiceNavTarget.tentangAplikasi:
        bukaHalamanLepas?.call(target); // Serahkan ke MainPage untuk membuka halaman lepas
    }
  }
}
