import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import '../../../../core/navigation/app_route.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../data/profile_repository.dart';
import '../../../transactions/presentation/widgets/voice_transaction_flow.dart';
import 'informasi_profil_page.dart';
import 'ganti_pin_page.dart';
import 'pengaturan_aksesibilitas_page.dart';
import 'tentang_aplikasi_page.dart';

/// ─────────────────────────────────────────────────────────────────
/// PROFILE PAGE  –  Halaman Profil & Pengaturan
/// ─────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _nama     = '';
  String _jabatan  = '';
  // Beda dari nama kosong: ini menandai proses baca dari basis data
  // belum selesai, supaya "Memuat..." tidak tertukar dengan "profil
  // memang belum diisi".
  bool _sedangMemuat = true;

  // Dipindah dari halaman Informasi Profil supaya cepat dijangkau —
  // sebelumnya ada di balik seluruh Data Pribadi dan Data Usaha.
  // Sementara masih state lokal, belum dikoneksikan ke basis data.
  // Mode Gelap TIDAK ada di sini lagi — itu sekarang punya bagiannya
  // sendiri (_pilihanTampilan) karena butuh 3 pilihan, bukan sakelar
  // hidup-mati, dan sudah benar-benar tersambung ke ThemeController.
  bool _voiceMode = false;
  bool _biometricAuth = false;

  final _repo = ProfileRepository.instance;

  @override
  void initState() {
    super.initState();
    _muatProfil();
  }

  Future<void> _muatProfil() async {
    final nama    = await _repo.bacaNama();
    final jabatan = await _repo.bacaJabatan();
    if (!mounted) return;
    setState(() {
      _nama    = nama;
      _jabatan = jabatan;
      _sedangMemuat = false;
    });
  }

  Future<void> _handleVoiceInput() async {
    await mulaiCatatTransaksiSuara(context);
  }

  // ── Warna sadar-tema ──────────────────────────────────────────────
  // Halaman ini memakai warna literal (bukan Theme.of(context).textTheme)
  // karena butuh kontrol halus per elemen (ikon vs teks vs latar), jadi
  // setiap pasangan terang/gelap dipusatkan di sini alih-alih diulang
  // sebagai ternary di puluhan tempat.
  static Color _kartu(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.white;

  static Color _teksUtama(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkText
          : AppColors.baseDark;

  static Color _teksMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextMuted
          : AppColors.textMuted;

  static Color _garis(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkDivider
          : AppColors.divider;

  static Color _bahaya(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkExpense
          : AppColors.tertiary500;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: gelap ? Brightness.light : Brightness.dark,
        statusBarBrightness: gelap ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
        heroTag: 'fab_profile',
        onPressed: _handleVoiceInput,
        backgroundColor: scheme.primary,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Catat transaksi dengan suara',
        // Semantics eksplisit, bukan cuma mengandalkan tooltip.
        // Tanpa label ini pembaca layar hanya menyebutnya "tombol"
        // tanpa keterangan, tak terbedakan dari tombol tambah lain.
        child: Semantics(
          button: true,
          label: 'Catat transaksi dengan suara',
          excludeSemantics: true,
          child: Icon(
            Icons.mic_rounded,
            color: scheme.onPrimary,
            size: 30,
          ),
        ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),

              // ── Header ─────────────────────────────────────────
              Text(
                'Profil Saya',
                style: AppTypography.headingMedium.copyWith(
                  color: _teksUtama(context),
                ),
              ),
              const SizedBox(height: 24),

              // ── Avatar + Nama ──────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 40,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      // "Memuat..." hanya selagi benar-benar membaca
                      // dari basis data. Sesudah itu, kosong berarti
                      // profil memang belum diisi — tampilkan sapaan
                      // polos, bukan nama contoh milik orang lain.
                      _sedangMemuat
                          ? 'Memuat...'
                          : (_nama.isEmpty ? 'Selamat datang' : _nama),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _teksUtama(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _jabatan.isEmpty ? '' : _jabatan,
                      style: TextStyle(
                        fontSize: 13,
                        color: _teksMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Pengaturan ──────────────────────────────────────
              // Satu kartu untuk semuanya — sakelar, pemilih tampilan,
              // dan menu navigasi — bukan lima kotak terpisah bertumpuk
              // ke bawah. Sebelumnya "Pengaturan Aksesibilitas" bahkan
              // punya kartu sendiri untuk satu baris saja.
              _buildSectionLabel('PENGATURAN'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: _kartu(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _garis(context)),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      _buildSettingToggle(
                        icon: Icons.mic_outlined,
                        label: 'Mode Suara',
                        value: _voiceMode,
                        onChanged: (val) {
                          setState(() => _voiceMode = val);
                          SemanticsService.sendAnnouncement(
                            View.of(context),
                            'Mode suara ${val ? "dinyalakan" : "dimatikan"}',
                            Directionality.of(context),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 46, color: _garis(context)),
                      _buildSettingToggle(
                        icon: Icons.fingerprint_outlined,
                        label: 'Autentikasi Biometrik',
                        value: _biometricAuth,
                        onChanged: (val) {
                          setState(() => _biometricAuth = val);
                          SemanticsService.sendAnnouncement(
                            View.of(context),
                            'Autentikasi biometrik '
                            '${val ? "dinyalakan" : "dimatikan"}',
                            Directionality.of(context),
                          );
                        },
                      ),
                      Divider(height: 1, indent: 46, color: _garis(context)),
                      _pilihanTampilan(),
                      Divider(height: 1, indent: 46, color: _garis(context)),
                      ..._daftarMenu(context),
                    ],
                  ),
                ),
              ),
              // 120: tinggi tombol mic (64) + jarak dari tepi bawah —
              // tanpa ini menu terakhir tertutup separuh oleh tombol
              // mic yang mengambang.
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _teksMuted(context),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildSettingToggle({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    // minHeight, bukan tinggi tetap — supaya baris ini tetap muat saat
    // ukuran teks sistem dimaksimalkan, bukannya label terpotong.
    return Semantics(
      label: label,
      toggled: value,
      hint: 'Ketuk dua kali untuk mengubah',
      // Wajib diisi eksplisit. ExcludeSemantics di bawah membuang aksi
      // tap milik Switch itu sendiri, jadi tanpa baris ini TalkBack
      // mengumumkan "sakelar" beserta statusnya tapi ketuk dua kali
      // tidak melakukan apa pun — persis bug yang berulang kali
      // ditemukan di komponen kustom lain pada aplikasi ini.
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _teksMuted(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyLarge.copyWith(
                      color: _teksUtama(context),
                    ),
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeThumbColor: AppColors.white,
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tiga baris pemilih Mode Tampilan, tanpa kartu/label sendiri —
  /// dipakai sebagai bagian dari kartu PENGATURAN bersama, bukan kotak
  /// terpisah. ValueListenableBuilder tetap dipertahankan di sini
  /// (bukan di kartu pemanggil) supaya saat ThemeMode berubah, hanya
  /// tiga baris ini yang dibangun ulang — bukan seluruh kartu.
  Widget _pilihanTampilan() {
    final ThemeController tc = ThemeController.instance;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: tc.mode,
      builder: (context, aktif, _) {
        return Column(
          children: [
            for (int i = 0; i < ThemeMode.values.length; i++) ...[
              _buildBarisTampilan(ThemeMode.values[i], aktif, tc),
              if (i < ThemeMode.values.length - 1)
                Divider(height: 1, indent: 46, color: _garis(context)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildBarisTampilan(ThemeMode m, ThemeMode aktif, ThemeController tc) {
    final bool terpilih = m == aktif;
    return Semantics(
      button: true,
      selected: terpilih,
      label: tc.label(m),
      onTap: () => _pilihTampilan(m),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _pilihTampilan(m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(
                  terpilih
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: terpilih
                      ? Theme.of(context).colorScheme.primary
                      : _teksMuted(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tc.label(m),
                    style: AppTypography.bodyLarge.copyWith(
                      color: _teksUtama(context),
                      fontWeight:
                          terpilih ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Icon(
                  switch (m) {
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.dark => Icons.dark_mode_outlined,
                    ThemeMode.system => Icons.smartphone_outlined,
                  },
                  size: 18,
                  color: _teksMuted(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pilihTampilan(ThemeMode m) async {
    final ThemeController tc = ThemeController.instance;
    await tc.ganti(m);
    if (!mounted) return;
    // Pengguna tunanetra tidak melihat tampilan berubah, sedangkan
    // perubahan ini memengaruhi pengguna lain yang memakai perangkat
    // yang sama. Pengumuman ini yang memberitahunya.
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Tampilan diubah ke ${tc.label(m)}',
      Directionality.of(context),
    );
  }

  /// Seluruh menu navigasi (dulu tersebar di tiga kartu terpisah —
  /// PROFIL, AKSESIBILITAS, LAINNYA) sebagai satu daftar rata, supaya
  /// bisa ditempel langsung ke kartu PENGATURAN bersama. Tidak ada
  /// label judul per kelompok lagi karena kelompoknya sendiri sudah
  /// lebur jadi satu.
  List<Widget> _daftarMenu(BuildContext context) {
    final List<_MenuItem> items = [
      _MenuItem(
        icon: Icons.person_outline,
        label: 'Informasi Profil',
        onTap: () async {
          await Navigator.push(
            context,
            buatRute((_) => const InformasiProfilPage()),
          );
          // Reload nama setelah kembali
          _muatProfil();
        },
      ),
      _MenuItem(
        icon: Icons.lock_outline,
        label: 'Ganti PIN',
        onTap: () => Navigator.push(
          context,
          buatRute((_) => const GantiPinPage()),
        ),
      ),
      _MenuItem(
        icon: Icons.accessibility_new_outlined,
        label: 'Pengaturan Aksesibilitas',
        onTap: () => Navigator.push(
          context,
          buatRute((_) => const PengaturanAksesibilitasPage()),
        ),
      ),
      _MenuItem(
        icon: Icons.info_outline,
        label: 'Tentang Aplikasi',
        onTap: () => Navigator.push(
          context,
          buatRute((_) => const TentangAplikasiPage()),
        ),
      ),
      _MenuItem(
        icon: Icons.logout,
        label: 'Keluar',
        onTap: () => _showLogoutDialog(context),
        isDestructive: true,
      ),
    ];

    return List.generate(items.length, (index) {
      final item = items[index];
      final bool isLast = index == items.length - 1;
      return Column(
        children: [
          ListTile(
            leading: Icon(
              item.icon,
              size: 20,
              color: item.isDestructive
                  ? _bahaya(context)
                  : _teksUtama(context),
            ),
            title: Text(
              item.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: item.isDestructive
                    ? _bahaya(context)
                    : _teksUtama(context),
              ),
            ),
            trailing: item.isDestructive
                ? null
                : Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _teksMuted(context),
                  ),
            onTap: item.onTap,
          ),
          if (!isLast)
            Divider(height: 1, indent: 52, color: _garis(context)),
        ],
      );
    });
  }

  // ── Dialog konfirmasi keluar ─────────────────────────────────────
  static void _showLogoutDialog(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Keluar dari Profil?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _teksUtama(context),
          ),
        ),
        content: Text(
          'Anda akan keluar dari aplikasi Modio. Data lokal Anda tetap tersimpan.',
          style: TextStyle(
            fontSize: 14,
            color: _teksMuted(context),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
                style: TextStyle(color: _teksMuted(context),
                    fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: arahkan ke halaman login
            },
            // tertiary700 dari palet terang nyaris tak terbaca di atas
            // latar gelap (lihat peringatan di app_colors.dart), jadi
            // dialog ini butuh cabang sendiri alih-alih tertiary700 tetap.
            child: Text('Keluar',
                style: TextStyle(
                    color: gelap ? AppColors.darkExpense : AppColors.tertiary700,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// Model data untuk setiap item menu
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });
}
