import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter

import 'core/navigation/app_route.dart'; // Helper pembuat route/transisi halaman
import 'core/navigation/main_nav_controller.dart'; // Pengontrol tab navigasi utama & navigasi suara
import 'core/theme/app_colors.dart'; // Palet warna khusus aplikasi
import 'core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema
import 'features/ai_chat/presentation/pages/ai_assistant_page.dart'; // Halaman chat AI
import 'features/dashboard/presentation/pages/dashboard_page.dart'; // Halaman dashboard/beranda
import 'features/transactions/presentation/pages/history_page.dart'; // Halaman riwayat transaksi
import 'features/transactions/presentation/widgets/record_transaction_modal.dart'; // Modal catat transaksi
import 'features/reports/presentation/pages/reports_page.dart'; // Halaman laporan
import 'features/profile/presentation/pages/profile_page.dart'; // Halaman profil
import 'features/profile/presentation/pages/informasi_profil_page.dart'; // Halaman informasi profil
import 'features/profile/presentation/pages/ganti_pin_page.dart'; // Halaman ganti PIN
import 'features/profile/presentation/pages/pengaturan_aksesibilitas_page.dart'; // Halaman pengaturan aksesibilitas
import 'features/profile/presentation/pages/tentang_aplikasi_page.dart'; // Halaman tentang aplikasi

/// ─────────────────────────────────────────────────────────────────
/// MAIN PAGE  –  Shell navigasi utama aplikasi
///
/// Memuat 4 halaman dalam IndexedStack (Dashboard, Riwayat, Laporan,
/// Profil). Tombol tengah (Catat) tidak punya halaman sendiri melainkan
/// membuka modal.
/// ─────────────────────────────────────────────────────────────────

class _NavItem { // Data satu item pada bottom navigation bar
  final IconData activeIcon; // Ikon saat tab ini aktif
  final IconData inactiveIcon; // Ikon saat tab ini tidak aktif
  final String label; // Teks label di bawah ikon

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

class MainPage extends StatefulWidget { // Widget shell utama, punya state karena tab bisa berubah
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState(); // Buat objek state terkait
}

class _MainPageState extends State<MainPage> {
  final MainNavController _nav = MainNavController.instance; // Ambil instance singleton pengontrol navigasi

  /// Dinaikkan setiap kali transaksi baru tersimpan, agar halaman
  /// dimuat ulang dari basis data.
  int _revisi = 0; // Counter pemicu reload halaman lewat perubahan key

  @override
  void initState() { // Dipanggil sekali saat widget pertama dibuat
    super.initState();
    // Diisi supaya perintah navigasi suara ("chat AI", "ganti pin", dst.)
    // dari halaman mana pun bisa membuka halaman lepas ini lewat
    // Navigator, bukan cuma lewat menu/tombol masing-masing.
    _nav.bukaHalamanLepas = _bukaHalamanLepas; // Daftarkan callback pembuka halaman ke controller
  }

  @override
  void dispose() { // Dipanggil saat widget dihancurkan
    _nav.bukaHalamanLepas = null; // Lepas callback agar tidak memanggil state yang sudah mati
    super.dispose();
  }

  void _bukaHalamanLepas(VoiceNavTarget target) { // Membuka halaman berdasarkan target navigasi suara
    final WidgetBuilder builder = switch (target) { // Pilih builder halaman sesuai target
      VoiceNavTarget.aiChat => (_) => const AiAssistantPage(),
      VoiceNavTarget.informasiProfil => (_) => const InformasiProfilPage(),
      VoiceNavTarget.gantiPin => (_) => const GantiPinPage(),
      VoiceNavTarget.aksesibilitas => (_) =>
          const PengaturanAksesibilitasPage(),
      VoiceNavTarget.tentangAplikasi => (_) => const TentangAplikasiPage(),
      // Tab bottom-nav biasa ditangani lewat currentIndex, tidak pernah
      // sampai memanggil callback ini — lihat MainNavController.pindahKe.
      VoiceNavTarget.dashboard ||
      VoiceNavTarget.riwayat ||
      VoiceNavTarget.laporan ||
      VoiceNavTarget.profil =>
        throw StateError('$target seharusnya tidak sampai ke sini'), // Target tab seharusnya tak lewat sini
    };
    Navigator.push(context, buatRute(builder)); // Dorong halaman baru ke tumpukan navigasi
  }

  static const List<_NavItem> _navItems = [ // Daftar tetap 5 item bottom nav (termasuk tombol tengah)
    _NavItem(
      activeIcon: Icons.home_rounded,
      inactiveIcon: Icons.home_outlined,
      label: 'Dashboard',
    ),
    _NavItem(
      activeIcon: Icons.receipt_long,
      inactiveIcon: Icons.receipt_long_outlined,
      label: 'Transaksi',
    ),
    _NavItem(
      activeIcon: Icons.add_circle,
      inactiveIcon: Icons.add_circle_outline,
      label: 'Catat',
    ),
    _NavItem(
      // bar_chart (bukan bar_chart_rounded) supaya satu keluarga ikon
      // dengan bar_chart_outlined — sebelumnya keduanya dari keluarga
      // gaya berbeda (rounded vs default) sehingga pergantian isi/garis
      // saat aktif/nonaktif kurang terlihat jelas.
      activeIcon: Icons.bar_chart,
      inactiveIcon: Icons.bar_chart_outlined,
      label: 'Laporan',
    ),
    _NavItem(
      activeIcon: Icons.person_rounded,
      inactiveIcon: Icons.person_outline_rounded,
      label: 'Profil',
    ),
  ];

  Future<void> _showRecordModal() async { // Menampilkan modal catat transaksi
    final bool? tersimpan = await showModalBottomSheet<bool>( // Tunggu hasil modal (true jika tersimpan)
      context: context,
      isScrollControlled: true, // Modal bisa memenuhi tinggi layar (untuk keyboard)
      backgroundColor: Colors.transparent, // Latar transparan agar sudut modal terlihat membulat
      builder: (_) => const RecordTransactionModal(), // Widget modal yang ditampilkan
    );
    if (tersimpan == true && mounted) { // Jika transaksi berhasil disimpan dan widget masih hidup
      setState(() => _revisi++); // Naikkan revisi agar halaman terkait reload data
    }
  }

  void _openAiChat() { // Membuka halaman chat AI
    Navigator.push(
      context,
      buatRute((_) => const AiAssistantPage()), // Dorong halaman AiAssistantPage
    );
  }

  void _goToReports() { // Pindah ke tab Laporan
    _nav.currentIndex.value = 3; // Set index tab aktif ke 3 (Laporan)
  }

  int _bodyIndexForNav(int navIndex) { // Konversi index tab nav ke index body IndexedStack
    return navIndex >= 3 ? navIndex - 1 : navIndex; // Tab setelah tombol Catat digeser mundur satu
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>( // Bangun ulang saat currentIndex berubah
      valueListenable: _nav.currentIndex, // Dengarkan perubahan index tab aktif
      builder: (context, currentIndex, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar sesuai tema
        body: IndexedStack( // Simpan semua halaman tetap hidup, hanya ganti yang terlihat
          index: currentIndex == 2 ? 0 : _bodyIndexForNav(currentIndex), // Tombol Catat (2) tetap tampilkan Dashboard
          children: [
            DashboardPage(
              key: ValueKey('dashboard_$_revisi'), // Key berubah saat revisi naik, memicu rebuild total
              onOpenAiChat: _openAiChat, // Callback untuk membuka chat AI dari dashboard
              onOpenReports: _goToReports, // Callback untuk membuka laporan dari dashboard
            ),
            HistoryPage(key: ValueKey('history_$_revisi')), // Halaman riwayat, reload saat revisi berubah
            ReportsPage(key: ValueKey('reports_$_revisi')), // Halaman laporan, reload saat revisi berubah
            const ProfilePage(), // Halaman profil, tidak perlu reload dari revisi
          ],
        ),
        bottomNavigationBar: _buildBottomNav(currentIndex), // Bangun bilah navigasi bawah
      ),
    );
  }

  Widget _buildBottomNav(int currentIndex) { // Membangun seluruh bilah navigasi bawah
    final Color activeColor = Theme.of(context).colorScheme.primary; // Warna untuk item aktif
    final Color inactiveColor = context.warnaTeksMuted; // Warna untuk item tidak aktif
    final Color bgColor = context.warnaKartu; // Warna latar bilah navigasi

    return Container(
      decoration: BoxDecoration(
        color: bgColor, // Terapkan warna latar
        border: Border(
          top: BorderSide(color: context.warnaGaris), // Garis pemisah tipis di atas bilah
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Sudut atas membulat
      ),
      child: SafeArea( // Hindari area sistem (mis. gesture bar) di bawah
        child: Container(
          constraints: const BoxConstraints(minHeight: 72), // Tinggi minimum bilah navigasi
          padding: const EdgeInsets.symmetric(vertical: 6), // Jarak dalam vertikal
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, // Sebarkan item secara merata
            children: List.generate(_navItems.length, (i) { // Bangun tiap item nav dari daftar
              final bool isActive = currentIndex == i && i != 2; // Aktif jika index cocok, kecuali tombol Catat
              final _NavItem item = _navItems[i]; // Data item nav saat ini

              // ── Tombol Catat (tengah) ──────────────────────────
              if (i == 2) { // Perlakuan khusus untuk tombol tengah (Catat)
                return Semantics( // Bungkus dengan info aksesibilitas kustom
                  button: true, // Umumkan sebagai tombol ke screen reader
                  label: 'Catat transaksi baru', // Label yang dibacakan TalkBack
                  // onTap wajib dipasang di simpul semantik ini.
                  // excludeSemantics membuang aksi milik InkWell,
                  // jadi tanpa baris ini TalkBack mengumumkan
                  // "tombol" tapi ketuk dua kali tidak melakukan apa
                  // pun — satu-satunya jalan mencatat transaksi jadi
                  // tidak terjangkau lewat TalkBack.
                  onTap: _showRecordModal, // Aksi yang dijalankan lewat aktivasi semantik
                  excludeSemantics: true, // Sembunyikan semantik anak (InkWell) agar tidak dobel
                  child: InkWell( // Efek ripple visual saat diketuk
                    onTap: _showRecordModal, // Aksi sama untuk interaksi sentuh biasa
                    borderRadius: BorderRadius.circular(14), // Bentuk area ripple mengikuti sudut
                    child: Container(
                      constraints: const BoxConstraints( // Ukuran minimum area sentuh (target aksesibilitas)
                        minWidth: 56,
                        minHeight: 56,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Tinggi kolom sekecil mungkin
                        mainAxisAlignment: MainAxisAlignment.center, // Rata tengah vertikal
                        children: [
                          Container( // Lingkaran ikon tombol Catat
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: context.gelap // Pilih gradasi warna sesuai mode tema
                                  ? const LinearGradient(
                                      colors: [
                                        AppColors.darkPrimary,
                                        AppColors.darkIncome,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : const LinearGradient(
                                      colors: [
                                        AppColors.primary700,
                                        AppColors.primary500,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              shape: BoxShape.circle, // Bentuk lingkaran penuh
                              boxShadow: [
                                BoxShadow( // Bayangan lembut di bawah lingkaran
                                  color: (context.gelap
                                          ? AppColors.darkPrimary
                                          : AppColors.primary700)
                                      .withValues(alpha: 0.35), // Transparansi bayangan
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded, // Ikon tambah/plus
                              size: 26,
                              color: Theme.of(context).colorScheme.onPrimary, // Warna kontras di atas warna primary
                            ),
                          ),
                          const SizedBox(height: 4), // Jarak antara ikon dan label teks
                          Text(
                            'Catat', // Label teks di bawah lingkaran
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: activeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // ── Tombol navigasi biasa ──────────────────────────
              return Semantics( // Bungkus tombol nav biasa dengan info aksesibilitas
                button: true, // Umumkan sebagai tombol
                selected: isActive, // Beritahu screen reader status terpilih
                label: item.label, // Label yang dibacakan
                onTap: () => _nav.currentIndex.value = i, // Aksi lewat aktivasi semantik: pindah tab
                excludeSemantics: true, // Cegah duplikasi semantik dari InkWell di dalamnya
                child: InkWell( // Efek ripple untuk interaksi sentuh biasa
                  onTap: () => _nav.currentIndex.value = i, // Ubah index tab aktif saat diketuk
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints( // Ukuran minimum target sentuh
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? activeColor.withValues(alpha: 0.10) // Latar tipis untuk tab aktif
                          : Colors.transparent, // Transparan untuk tab tidak aktif
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.inactiveIcon, // Ganti ikon sesuai status aktif
                          size: 24,
                          color: isActive ? activeColor : inactiveColor, // Ganti warna sesuai status aktif
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label, // Label tab
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400, // Tebal saat aktif
                            color: isActive ? activeColor : inactiveColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
