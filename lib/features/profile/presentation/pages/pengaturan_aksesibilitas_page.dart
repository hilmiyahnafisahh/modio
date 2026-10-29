import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter
import '../../../../core/services/aksesibilitas_controller.dart'; // Penyimpan & pengelola state pengaturan aksesibilitas
import '../../../../core/theme/app_colors.dart'; // Palet warna khusus aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// PENGATURAN AKSESIBILITAS PAGE
/// ─────────────────────────────────────────────────────────────────

class PengaturanAksesibilitasPage extends StatefulWidget { // Halaman punya state karena sakelar bisa berubah
  const PengaturanAksesibilitasPage({super.key});

  @override
  State<PengaturanAksesibilitasPage> createState() =>
      _PengaturanAksesibilitasPageState(); // Buat objek state terkait
}

class _PengaturanAksesibilitasPageState
    extends State<PengaturanAksesibilitasPage> {
  final _ak = AksesibilitasController.instance; // Ambil instance singleton controller aksesibilitas

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar halaman sesuai tema
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Samakan warna app bar dengan latar
        elevation: 0, // Tanpa bayangan di bawah app bar
        leading: IconButton( // Tombol kembali di kiri app bar
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.warnaTeksUtama,
          onPressed: () => Navigator.pop(context), // Kembali ke halaman sebelumnya
          tooltip: 'Kembali', // Teks bantuan aksesibilitas
        ),
        title: Text(
          'Aksesibilitas', // Judul halaman
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama,
          ),
        ),
        centerTitle: true, // Judul diletakkan di tengah app bar
      ),
      body: SingleChildScrollView( // Konten bisa digulir jika melebihi layar
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri untuk semua konten
          children: [
            const SizedBox(height: 20), // Jarak atas sebelum konten pertama

            // ── Banner Info ──────────────────────────────────────────
            Container( // Kotak info penjelasan standar aksesibilitas
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.latarMasuk, // Warna latar bernuansa aksen positif
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: context.warnaMasuk.withValues(alpha: 0.35)), // Garis tepi transparan sebagian
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // Ikon dan teks rata atas
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: context.warnaMasuk), // Ikon info
                  const SizedBox(width: 10), // Jarak antara ikon dan teks
                  Expanded( // Teks mengisi sisa ruang agar bisa wrap
                    child: Text(
                      'Modio dirancang untuk memenuhi standar aksesibilitas WCAG 2.1 tingkat AAA. Pengaturan di sini membantu menyesuaikan pengalaman Anda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.warnaMasuk,
                        height: 1.5, // Jarak antar baris teks
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24), // Jarak setelah banner info

            // Setiap sakelar di bawah membaca & menulis langsung ke
            // AksesibilitasController — ListenableBuilder membangun
            // ulang bagian ini saja saat salah satu nilainya berubah,
            // dari mana pun perubahan itu dipicu.
            ListenableBuilder( // Bangun ulang bagian ini saat salah satu listenable berubah
              listenable: Listenable.merge([ // Gabungkan beberapa ValueNotifier jadi satu listenable
                _ak.kontrasTinggi,
                _ak.teksTebal,
                _ak.getaran,
                _ak.kurangiAnimasi,
              ]),
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Seksi: Penglihatan ─────────────────────────
                    _buildSectionLabel('PENGLIHATAN'), // Label judul seksi
                    const SizedBox(height: 8),
                    _buildToggleGroup([ // Kelompok sakelar terkait penglihatan
                      _ToggleItem(
                        icon: Icons.contrast_rounded,
                        label: 'Kontras Tinggi',
                        description:
                            'Menghilangkan tingkat warna "diredam" — teks sekunder dan garis kartu memakai kekuatan penuh di seluruh aplikasi',
                        value: _ak.kontrasTinggi.value, // Nilai sakelar saat ini
                        onChanged: (v) { // Dipanggil saat sakelar digeser
                          _ak.getar(); // Beri umpan balik getaran
                          _ak.ubahKontrasTinggi(v); // Simpan nilai baru ke controller
                        },
                      ),
                      _ToggleItem(
                        icon: Icons.format_bold_rounded,
                        label: 'Teks Tebal',
                        description:
                            'Menaikkan ketebalan seluruh teks di aplikasi satu-dua tingkat',
                        value: _ak.teksTebal.value,
                        onChanged: (v) {
                          _ak.getar();
                          _ak.ubahTeksTebal(v);
                        },
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Seksi: Interaksi ───────────────────────────
                    _buildSectionLabel('INTERAKSI'),
                    const SizedBox(height: 8),
                    _buildToggleGroup([ // Kelompok sakelar terkait interaksi
                      _ToggleItem(
                        icon: Icons.vibration_rounded,
                        label: 'Getaran (Haptic)',
                        description:
                            'Respons getaran di keypad PIN dan setiap sakelar pengaturan',
                        value: _ak.getaran.value,
                        onChanged: (v) {
                          // Getar dulu dengan nilai LAMA (sebelum
                          // dimatikan) supaya mematikannya sendiri
                          // tetap terasa sebagai konfirmasi.
                          if (_ak.getaran.value) _ak.getar(); // Getar hanya jika sebelumnya masih aktif
                          _ak.ubahGetaran(v); // Simpan nilai baru sakelar getaran
                        },
                      ),
                      _ToggleItem(
                        icon: Icons.animation_rounded,
                        label: 'Kurangi Animasi',
                        description:
                            'Transisi antar halaman berpindah seketika, tanpa animasi geser',
                        value: _ak.kurangiAnimasi.value,
                        onChanged: (v) {
                          _ak.getar();
                          _ak.ubahKurangiAnimasi(v);
                        },
                      ),
                    ]),
                  ],
                );
              },
            ),
            const SizedBox(height: 32), // Jarak sebelum tombol reset

            // ── Tombol Reset ─────────────────────────────────────────
            SizedBox(
              width: double.infinity, // Tombol selebar layar
              child: OutlinedButton(
                onPressed: _resetDefaults, // Kembalikan semua sakelar ke nilai default
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.warnaGaris), // Warna garis tepi tombol
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)), // Sudut membulat
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'Atur Ulang ke Default',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.warnaTeksMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32), // Jarak bawah sebelum akhir scroll
          ],
        ),
      ),
    );
  }

  void _resetDefaults() { // Mengembalikan semua pengaturan ke nilai awal
    _ak.ubahKontrasTinggi(false); // Matikan kontras tinggi
    _ak.ubahTeksTebal(false); // Matikan teks tebal
    _ak.ubahGetaran(true); // Nyalakan getaran (default aktif)
    _ak.ubahKurangiAnimasi(false); // Matikan pengurangan animasi
    ScaffoldMessenger.of(context).showSnackBar( // Tampilkan notifikasi konfirmasi di bawah layar
      SnackBar(
        content: Text(
          'Pengaturan aksesibilitas direset ke default',
          style: TextStyle(
            color: context.gelap ? AppColors.darkBg : AppColors.white, // Warna teks kontras sesuai tema
          ),
        ),
        backgroundColor: context.warnaMasuk, // Warna latar snackbar
        behavior: SnackBarBehavior.floating, // Snackbar melayang, tidak menempel di tepi bawah
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Sudut membulat snackbar
      ),
    );
  }

  Widget _buildSectionLabel(String label) { // Membangun label judul seksi kecil
    return Semantics( // Tandai sebagai judul agar bisa dilompati lewat navigasi Judul TalkBack
      header: true,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.warnaTeksMuted,
          letterSpacing: 0.8, // Jarak antar huruf sedikit lebar (gaya label)
        ),
      ),
    );
  }

  Widget _buildToggleGroup(List<_ToggleItem> items) { // Membangun kartu berisi daftar sakelar
    final scheme = Theme.of(context).colorScheme; // Ambil skema warna tema aktif
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu, // Warna latar kartu
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris), // Garis tepi kartu
      ),
      child: Column(
        children: List.generate(items.length, (index) { // Bangun tiap baris sakelar dari daftar item
          final item = items[index]; // Item sakelar saat ini
          final isLast = index == items.length - 1; // Cek apakah ini item terakhir (untuk divider)
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container( // Kotak ikon bulat di kiri baris
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.value // Warna kotak berbeda saat sakelar aktif
                            ? context.latarMasuk
                            : context.warnaKartuMenonjol,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: item.value // Warna ikon berbeda saat sakelar aktif
                            ? context.warnaMasuk
                            : context.warnaTeksMuted,
                      ),
                    ),
                    const SizedBox(width: 12), // Jarak antara ikon dan teks
                    Expanded( // Label & deskripsi mengisi sisa ruang
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label, // Nama pengaturan
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.warnaTeksUtama,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description, // Penjelasan singkat pengaturan
                            style: TextStyle(
                              fontSize: 12,
                              color: context.warnaTeksMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8), // Jarak sebelum sakelar
                    Switch.adaptive( // Sakelar yang tampilannya menyesuaikan platform (iOS/Android)
                      value: item.value, // Status aktif/nonaktif sakelar
                      onChanged: item.onChanged, // Callback saat sakelar digeser
                      activeThumbColor: AppColors.white, // Warna bulatan sakelar saat aktif
                      activeTrackColor: scheme.primary, // Warna jalur sakelar saat aktif
                    ),
                  ],
                ),
              ),
              if (!isLast) // Tambahkan garis pemisah kecuali untuk item terakhir
                Divider(
                    height: 1, indent: 64, color: context.warnaGaris),
            ],
          );
        }),
      ),
    );
  }
}

class _ToggleItem { // Model data satu baris sakelar pengaturan
  final IconData icon; // Ikon yang mewakili pengaturan
  final String label; // Nama pengaturan
  final String description; // Penjelasan singkat
  final bool value; // Status aktif/nonaktif saat ini
  final ValueChanged<bool> onChanged; // Callback saat nilai diubah pengguna

  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });
}
