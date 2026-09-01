import 'package:flutter/foundation.dart';

/// ─────────────────────────────────────────────────────────────────
/// NAVIGASI SUARA  –  Pindah tab lewat perintah ucapan
///
/// Tombol mic ada di banyak halaman (Dashboard, Riwayat, Laporan,
/// Profil), masing-masing tanpa akses langsung ke state MainPage yang
/// memegang tab aktif. Controller singleton ini jadi titik temu:
/// halaman mana pun bisa memanggil [MainNavController.pindahKe] tanpa
/// perlu mengalirkan callback lewat setiap konstruktor.
/// ─────────────────────────────────────────────────────────────────

enum VoiceNavTarget {
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

const List<String> _prefixNavigasi = ['buka ', 'ke ', 'pindah ke ', 'pergi ke '];

/// Mengenali apakah [teksAsli] adalah perintah pindah halaman, murni
/// lewat cocok kata kunci lokal — tanpa AI, gratis, instan. Perintah
/// biasa (dashboard/riwayat/laporan/profil) wajib diawali kata seperti
/// "buka"/"ke" supaya ucapan transaksi yang kebetulan menyebut kata
/// serupa tidak salah terdeteksi sebagai navigasi. Asisten AI dikecualikan
/// karena wajar diucapkan singkat tanpa awalan itu, misalnya cuma "chat AI".
VoiceNavTarget? deteksiPerintahNavigasi(String teksAsli) {
  final String teks = teksAsli.trim().toLowerCase();
  if (teks.isEmpty) return null;

  if (teks.contains('chat ai') ||
      teks.contains('ai chat') ||
      teks.contains('asisten ai') ||
      teks.contains('analisis ai')) {
    return VoiceNavTarget.aiChat;
  }

  String? sisa; 
  for (final String prefix in _prefixNavigasi) {
    if (teks.startsWith(prefix)) {
      sisa = teks.substring(prefix.length).trim();
      break;
    }
  }
  if (sisa == null || sisa.isEmpty) return null;

  // Sub-halaman Profil dicek lebih dulu — namanya sendiri mengandung
  // kata "profil", jadi harus menang sebelum sampai ke cek tab Profil
  // yang lebih umum di bawah (kalau tidak, "buka informasi profil"
  // akan salah berhenti di tab Profil saja).
  if (sisa.contains('informasi profil') ||
      sisa.contains('info profil') ||
      sisa.contains('data profil')) {
    return VoiceNavTarget.informasiProfil;
  }
  if (sisa.contains('ganti pin') || sisa.contains('ubah pin')) {
    return VoiceNavTarget.gantiPin;
  }
  if (sisa.contains('aksesibilitas')) {
    return VoiceNavTarget.aksesibilitas;
  }
  if (sisa.contains('tentang')) {
    return VoiceNavTarget.tentangAplikasi;
  }

  if (sisa.contains('beranda') || sisa.contains('dashboard')) {
    return VoiceNavTarget.dashboard;
  }
  if (sisa.contains('riwayat') ||
      sisa.contains('history') ||
      sisa.contains('transaksi')) {
    return VoiceNavTarget.riwayat;
  }
  if (sisa.contains('laporan')) return VoiceNavTarget.laporan;
  if (sisa.contains('profil')) return VoiceNavTarget.profil;

  return null;
}

/// Nama halaman yang diumumkan lewat TalkBack begitu navigasi suara
/// berhasil — supaya pengguna tunanetra tahu ia benar mendarat di
/// halaman yang dimaksud, tanpa perlu meraba-raba UI dulu.
String labelHalaman(VoiceNavTarget target) => switch (target) {
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

class MainNavController {
  MainNavController._();
  static final MainNavController instance = MainNavController._();

  /// Indeks tab aktif di bottom nav (bukan indeks body IndexedStack —
  /// lihat `_bodyIndexForNav` di MainPage untuk pemetaannya).
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  /// Diisi oleh MainPage selama ia aktif. Menangani tujuan yang bukan
  /// tab bottom-nav biasa (Asisten AI, sub-halaman Profil) lewat
  /// Navigator.push — MainPage yang tahu widget halaman sebenarnya,
  /// controller ini sengaja tidak mengimpor halaman fitur mana pun.
  void Function(VoiceNavTarget target)? bukaHalamanLepas;

  void pindahKe(VoiceNavTarget target) {
    switch (target) {
      case VoiceNavTarget.dashboard:
        currentIndex.value = 0;
      case VoiceNavTarget.riwayat:
        currentIndex.value = 1;
      case VoiceNavTarget.laporan:
        currentIndex.value = 3;
      case VoiceNavTarget.profil:
        currentIndex.value = 4;
      case VoiceNavTarget.aiChat:
      case VoiceNavTarget.informasiProfil:
      case VoiceNavTarget.gantiPin:
      case VoiceNavTarget.aksesibilitas:
      case VoiceNavTarget.tentangAplikasi:
        bukaHalamanLepas?.call(target);
    }
  }
}
