import 'package:flutter/material.dart'; // widget dan tema dasar Flutter
import 'package:flutter/semantics.dart'; // untuk pengumuman ke pembaca layar
import 'package:flutter/services.dart'; // untuk SystemUiOverlayStyle (warna status bar)
import '../../../../core/navigation/app_route.dart'; // helper pembuat rute navigasi
import '../../../../core/services/keamanan_controller.dart'; // pengelola pengaturan metode masuk (suara/biometrik)
import '../../../../core/theme/app_colors.dart'; // palet warna aplikasi
import '../../../../core/theme/app_typography.dart'; // gaya teks standar aplikasi
import '../../../../core/theme/theme_controller.dart'; // pengatur mode tema (terang/gelap/sistem)
import '../../data/profile_repository.dart'; // sumber data profil pengguna
import '../../../transactions/presentation/widgets/voice_transaction_flow.dart'; // alur pencatatan transaksi via suara
import 'informasi_profil_page.dart'; // halaman detail informasi profil
import 'ganti_pin_page.dart'; // halaman ganti PIN
import 'pengaturan_aksesibilitas_page.dart'; // halaman pengaturan aksesibilitas
import 'tentang_aplikasi_page.dart'; // halaman tentang aplikasi

/// ─────────────────────────────────────────────────────────────────
/// PROFILE PAGE  –  Halaman Profil & Pengaturan
/// ─────────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState(); // buat objek state terkait
}

class _ProfilePageState extends State<ProfilePage> {
  String _nama     = ''; // nama pengguna, diisi dari repository
  String _jabatan  = ''; // jabatan/peran pengguna, diisi dari repository
  // Beda dari nama kosong: ini menandai proses baca dari basis data
  // belum selesai, supaya "Memuat..." tidak tertukar dengan "profil
  // memang belum diisi".
  bool _sedangMemuat = true;

  // Dipindah dari halaman Informasi Profil supaya cepat dijangkau —
  // sebelumnya ada di balik seluruh Data Pribadi dan Data Usaha.
  // Mode Gelap TIDAK ada di sini lagi — itu sekarang punya bagiannya
  // sendiri (_pilihanTampilan) karena butuh 3 pilihan, bukan sakelar
  // hidup-mati, dan sudah benar-benar tersambung ke ThemeController.
  //
  // Kunci PIN, Mode Suara & Autentikasi Biometrik sekarang tersambung
  // ke KeamananController (lihat _keamanan di bawah) — mengubah salah
  // satunya di sini langsung berpengaruh: Kunci PIN menentukan apakah
  // PinLockPage ditampilkan sama sekali saat aplikasi dibuka, Mode
  // Suara menentukan boleh/tidaknya tombol mikrofon (baik di layar
  // kunci maupun tombol catat transaksi suara) dipakai, dan Biometrik
  // menambah opsi masuk di PinLockPage. Bukan sekadar sakelar kosmetik.
  final _keamanan = KeamananController.instance; // akses pengaturan metode masuk lewat singleton controller

  final _repo = ProfileRepository.instance; // akses data profil lewat singleton repository

  @override
  void initState() {
    super.initState();
    _muatProfil(); // muat data profil segera setelah widget dibuat
  }

  Future<void> _muatProfil() async {
    final nama    = await _repo.bacaNama(); // ambil nama dari penyimpanan
    final jabatan = await _repo.bacaJabatan(); // ambil jabatan dari penyimpanan
    if (!mounted) return; // batalkan bila widget sudah dilepas sebelum data siap
    setState(() {
      _nama    = nama; // simpan nama ke state agar UI diperbarui
      _jabatan = jabatan; // simpan jabatan ke state
      _sedangMemuat = false; // tandai proses muat selesai
    });
  }

  Future<void> _handleVoiceInput() async {
    await mulaiCatatTransaksiSuara(context); // buka alur pencatatan transaksi lewat suara
  }

  // ── Warna sadar-tema ──────────────────────────────────────────────
  // Halaman ini memakai warna literal (bukan Theme.of(context).textTheme)
  // karena butuh kontrol halus per elemen (ikon vs teks vs latar), jadi
  // setiap pasangan terang/gelap dipusatkan di sini alih-alih diulang
  // sebagai ternary di puluhan tempat.
  static Color _kartu(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface // warna kartu mode gelap
          : AppColors.white; // warna kartu mode terang

  static Color _teksUtama(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkText // warna teks utama mode gelap
          : AppColors.baseDark; // warna teks utama mode terang

  static Color _teksMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkTextMuted // warna teks pudar mode gelap
          : AppColors.textMuted; // warna teks pudar mode terang

  static Color _garis(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkDivider // warna garis pemisah mode gelap
          : AppColors.divider; // warna garis pemisah mode terang

  static Color _bahaya(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkExpense // warna peringatan/bahaya mode gelap
          : AppColors.tertiary500; // warna peringatan/bahaya mode terang

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme; // skema warna aktif dari tema
    final bool gelap = Theme.of(context).brightness == Brightness.dark; // deteksi mode gelap
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // status bar transparan
        statusBarIconBrightness: gelap ? Brightness.light : Brightness.dark, // ikon menyesuaikan mode
        statusBarBrightness: gelap ? Brightness.dark : Brightness.light, // kecerahan status bar untuk iOS
      ),
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // latar halaman sesuai tema
      // VoiceFab menghilang sendiri saat Mode Suara dimatikan di Pengaturan.
      floatingActionButton: VoiceFab(
        heroTag: 'fab_profile', // tag unik agar tidak bentrok dengan FAB halaman lain
        onPressed: _handleVoiceInput, // buka pencatatan transaksi suara saat ditekan
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // rata kiri semua anak
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
                        color: scheme.primary, // latar lingkaran avatar
                        shape: BoxShape.circle, // bentuk lingkaran
                      ),
                      child: Icon(
                        Icons.person_outline, // ikon avatar generik
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
                      _jabatan.isEmpty ? '' : _jabatan, // tampilkan jabatan bila ada
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
                  color: _kartu(context), // latar kartu sesuai tema
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _garis(context)),
                ),
                child: Material(
                  color: Colors.transparent, // agar efek ripple InkWell di dalamnya terlihat
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    children: [
                      ListenableBuilder( // Bangun ulang tiga baris ini saat salah satu pengaturan berubah
                        listenable: Listenable.merge([
                          _keamanan.pinAktif,
                          _keamanan.suaraAktif,
                          _keamanan.biometrikAktif,
                        ]),
                        builder: (context, _) => Column(
                          children: [
                            _buildSettingToggle(
                              icon: Icons.pin_outlined,
                              label: 'Kunci PIN',
                              value: _keamanan.pinAktif.value,
                              onChanged: (val) {
                                _keamanan.ubahPin(val); // simpan & terapkan apakah layar kunci PIN ditampilkan
                                SemanticsService.sendAnnouncement(
                                  View.of(context),
                                  'Kunci PIN ${val ? "dinyalakan" : "dimatikan"}. '
                                  '${val ? "Aplikasi akan meminta PIN setiap dibuka." : "Aplikasi akan langsung terbuka tanpa PIN mulai berikutnya."}',
                                  Directionality.of(context),
                                );
                              },
                            ),
                            Divider(height: 1, indent: 46, color: _garis(context)),
                            _buildSettingToggle(
                              icon: Icons.mic_outlined,
                              label: 'Mode Suara',
                              value: _keamanan.suaraAktif.value,
                              onChanged: (val) {
                                _keamanan.ubahSuara(val); // simpan & terapkan fitur suara (PIN & catat transaksi)
                                SemanticsService.sendAnnouncement(
                                  View.of(context),
                                  'Mode suara ${val ? "dinyalakan" : "dimatikan"}. '
                                  '${val ? "Anda bisa mencatat transaksi dan mengisi PIN dengan suara." : "Tombol mikrofon untuk mencatat transaksi dan mengeja PIN tidak akan berfungsi."}',
                                  Directionality.of(context),
                                );
                              },
                            ),
                            Divider(height: 1, indent: 46, color: _garis(context)),
                            _buildSettingToggle(
                              icon: Icons.fingerprint_outlined,
                              label: 'Autentikasi Biometrik',
                              value: _keamanan.biometrikAktif.value,
                              onChanged: (val) {
                                _keamanan.ubahBiometrik(val); // simpan & terapkan opsi masuk lewat biometrik
                                SemanticsService.sendAnnouncement(
                                  View.of(context),
                                  'Autentikasi biometrik '
                                  '${val ? "dinyalakan" : "dimatikan"}. '
                                  '${val ? "Opsi masuk dengan sidik jari kini tersedia di layar kunci." : ""}',
                                  Directionality.of(context),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, indent: 46, color: _garis(context)),
                      _pilihanTampilan(), // baris pemilih mode tampilan (terang/gelap/sistem)
                      Divider(height: 1, indent: 46, color: _garis(context)),
                      ..._daftarMenu(context), // sebar daftar item menu navigasi ke dalam Column
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
        letterSpacing: 0.8, // jarak antar huruf lebih lebar untuk gaya label kecil
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
      label: label, // teks yang dibacakan pembaca layar
      toggled: value, // beri tahu status sakelar saat ini
      hint: 'Ketuk dua kali untuk mengubah',
      // Wajib diisi eksplisit. ExcludeSemantics di bawah membuang aksi
      // tap milik Switch itu sendiri, jadi tanpa baris ini TalkBack
      // mengumumkan "sakelar" beserta statusnya tapi ketuk dua kali
      // tidak melakukan apa pun — persis bug yang berulang kali
      // ditemukan di komponen kustom lain pada aplikasi ini.
      onTap: () => onChanged(!value), // aksi manual untuk pembaca layar, membalik nilai
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
                  value: value, // nilai sakelar saat ini
                  onChanged: onChanged, // dipanggil saat pengguna mengetuk sakelar
                  activeThumbColor: AppColors.white, // warna bulatan saat aktif
                  activeTrackColor: Theme.of(context).colorScheme.primary, // warna trek saat aktif
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
    final ThemeController tc = ThemeController.instance; // akses pengatur tema singleton

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: tc.mode, // dengarkan perubahan mode tema aktif
      builder: (context, aktif, _) {
        return Column(
          children: [
            for (int i = 0; i < ThemeMode.values.length; i++) ...[
              _buildBarisTampilan(ThemeMode.values[i], aktif, tc), // baris untuk tiap mode (terang/gelap/sistem)
              if (i < ThemeMode.values.length - 1)
                Divider(height: 1, indent: 46, color: _garis(context)), // garis pemisah kecuali baris terakhir
            ],
          ],
        );
      },
    );
  }

  Widget _buildBarisTampilan(ThemeMode m, ThemeMode aktif, ThemeController tc) {
    final bool terpilih = m == aktif; // true bila mode ini yang sedang dipakai
    return Semantics(
      button: true,
      selected: terpilih,
      label: tc.label(m), // nama mode yang dibacakan pembaca layar
      onTap: () => _pilihTampilan(m),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _pilihTampilan(m), // ganti mode tampilan saat baris ini diketuk
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                Icon(
                  terpilih
                      ? Icons.radio_button_checked // tanda terpilih
                      : Icons.radio_button_unchecked, // tanda belum terpilih
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
                          terpilih ? FontWeight.w600 : FontWeight.w400, // tebal bila terpilih
                    ),
                  ),
                ),
                Icon(
                  switch (m) {
                    ThemeMode.light => Icons.light_mode_outlined, // ikon untuk mode terang
                    ThemeMode.dark => Icons.dark_mode_outlined, // ikon untuk mode gelap
                    ThemeMode.system => Icons.smartphone_outlined, // ikon untuk ikut sistem
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
    await tc.ganti(m); // terapkan mode tema yang dipilih
    if (!mounted) return; // batalkan bila widget sudah dilepas
    // Pengguna tunanetra tidak melihat tampilan berubah, sedangkan
    // perubahan ini memengaruhi pengguna lain yang memakai perangkat
    // yang sama. Pengumuman ini yang memberitahunya.
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Tampilan diubah ke ${tc.label(m)}', // umumkan mode baru
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
            buatRute((_) => const InformasiProfilPage()), // buka halaman informasi profil
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
          buatRute((_) => const GantiPinPage()), // buka halaman ganti PIN
        ),
      ),
      _MenuItem(
        icon: Icons.accessibility_new_outlined,
        label: 'Pengaturan Aksesibilitas',
        onTap: () => Navigator.push(
          context,
          buatRute((_) => const PengaturanAksesibilitasPage()), // buka halaman aksesibilitas
        ),
      ),
      _MenuItem(
        icon: Icons.info_outline,
        label: 'Tentang Aplikasi',
        onTap: () => Navigator.push(
          context,
          buatRute((_) => const TentangAplikasiPage()), // buka halaman tentang aplikasi
        ),
      ),
      _MenuItem(
        icon: Icons.logout,
        label: 'Keluar',
        onTap: () => _showLogoutDialog(context), // tampilkan konfirmasi keluar
        isDestructive: true, // tandai sebagai aksi berisiko, diberi warna bahaya
      ),
    ];

    return List.generate(items.length, (index) {
      final item = items[index];
      final bool isLast = index == items.length - 1; // cek apakah ini item terakhir
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
                ? null // item berbahaya tidak diberi panah navigasi
                : Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: _teksMuted(context),
                  ),
            onTap: item.onTap, // aksi saat item menu diketuk
          ),
          if (!isLast)
            Divider(height: 1, indent: 52, color: _garis(context)), // garis pemisah kecuali item terakhir
        ],
      );
    });
  }

  // ── Dialog konfirmasi keluar ─────────────────────────────────────
  static void _showLogoutDialog(BuildContext context) {
    final bool gelap = Theme.of(context).brightness == Brightness.dark; // deteksi mode gelap untuk dialog
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
            onPressed: () => Navigator.pop(context), // tutup dialog tanpa aksi
            child: Text('Batal',
                style: TextStyle(color: _teksMuted(context),
                    fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // tutup dialog
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
  final IconData icon; // ikon yang tampil di depan item
  final String label; // teks label item
  final VoidCallback onTap; // aksi saat item diketuk
  final bool isDestructive; // true bila aksi ini berisiko (mis. keluar)

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false, // default bukan aksi berisiko
  });
}
