import 'package:flutter/material.dart';

import 'core/navigation/app_route.dart';
import 'core/navigation/main_nav_controller.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/theme_extensions.dart';
import 'features/ai_chat/presentation/pages/ai_assistant_page.dart';
import 'features/dashboard/presentation/pages/dashboard_page.dart';
import 'features/transactions/presentation/pages/history_page.dart';
import 'features/transactions/presentation/widgets/record_transaction_modal.dart';
import 'features/reports/presentation/pages/reports_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/profile/presentation/pages/informasi_profil_page.dart';
import 'features/profile/presentation/pages/ganti_pin_page.dart';
import 'features/profile/presentation/pages/pengaturan_aksesibilitas_page.dart';
import 'features/profile/presentation/pages/tentang_aplikasi_page.dart';

/// ─────────────────────────────────────────────────────────────────
/// MAIN PAGE  –  Shell navigasi utama aplikasi
///
/// Memuat 4 halaman dalam IndexedStack (Dashboard, Riwayat, Laporan,
/// Profil). Tombol tengah (Catat) tidak punya halaman sendiri melainkan
/// membuka modal.
/// ─────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;

  const _NavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
  });
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final MainNavController _nav = MainNavController.instance;

  /// Dinaikkan setiap kali transaksi baru tersimpan, agar halaman
  /// dimuat ulang dari basis data.
  int _revisi = 0;

  @override
  void initState() {
    super.initState();
    // Diisi supaya perintah navigasi suara ("chat AI", "ganti pin", dst.)
    // dari halaman mana pun bisa membuka halaman lepas ini lewat
    // Navigator, bukan cuma lewat menu/tombol masing-masing.
    _nav.bukaHalamanLepas = _bukaHalamanLepas;
  }

  @override
  void dispose() {
    _nav.bukaHalamanLepas = null;
    super.dispose();
  }

  void _bukaHalamanLepas(VoiceNavTarget target) {
    final WidgetBuilder builder = switch (target) {
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
        throw StateError('$target seharusnya tidak sampai ke sini'),
    };
    Navigator.push(context, buatRute(builder));
  }

  static const List<_NavItem> _navItems = [
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

  Future<void> _showRecordModal() async {
    final bool? tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RecordTransactionModal(),
    );
    if (tersimpan == true && mounted) {
      setState(() => _revisi++);
    }
  }

  void _openAiChat() {
    Navigator.push(
      context,
      buatRute((_) => const AiAssistantPage()),
    );
  }

  void _goToReports() {
    _nav.currentIndex.value = 3;
  }

  int _bodyIndexForNav(int navIndex) {
    return navIndex >= 3 ? navIndex - 1 : navIndex;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _nav.currentIndex,
      builder: (context, currentIndex, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: currentIndex == 2 ? 0 : _bodyIndexForNav(currentIndex),
          children: [
            DashboardPage(
              key: ValueKey('dashboard_$_revisi'),
              onOpenAiChat: _openAiChat,
              onOpenReports: _goToReports,
            ),
            HistoryPage(key: ValueKey('history_$_revisi')),
            ReportsPage(key: ValueKey('reports_$_revisi')),
            const ProfilePage(),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(currentIndex),
      ),
    );
  }

  Widget _buildBottomNav(int currentIndex) {
    final Color activeColor = Theme.of(context).colorScheme.primary;
    final Color inactiveColor = context.warnaTeksMuted;
    final Color bgColor = context.warnaKartu;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: context.warnaGaris),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final bool isActive = currentIndex == i && i != 2;
              final _NavItem item = _navItems[i];

              // ── Tombol Catat (tengah) ──────────────────────────
              if (i == 2) {
                return Semantics(
                  button: true,
                  label: 'Catat transaksi baru',
                  // onTap wajib dipasang di simpul semantik ini.
                  // excludeSemantics membuang aksi milik InkWell,
                  // jadi tanpa baris ini TalkBack mengumumkan
                  // "tombol" tapi ketuk dua kali tidak melakukan apa
                  // pun — satu-satunya jalan mencatat transaksi jadi
                  // tidak terjangkau lewat TalkBack.
                  onTap: _showRecordModal,
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: _showRecordModal,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 56,
                        minHeight: 56,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: context.gelap
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
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (context.gelap
                                          ? AppColors.darkPrimary
                                          : AppColors.primary700)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 26,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Catat',
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
              return Semantics(
                button: true,
                selected: isActive,
                label: item.label,
                onTap: () => _nav.currentIndex.value = i,
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => _nav.currentIndex.value = i,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? activeColor.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.inactiveIcon,
                          size: 24,
                          color: isActive ? activeColor : inactiveColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
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
