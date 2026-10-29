import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import 'package:flutter/semantics.dart'; // Untuk SemanticsService (pengumuman ke pembaca layar)

import '../../../../core/services/aksesibilitas_controller.dart'; // Getaran saat memilih
import '../../../../core/theme/theme_controller.dart'; // Mode tema aktif
import '../../../../core/theme/theme_extensions.dart'; // Warna sesuai tema
import '../widgets/penanda_langkah.dart'; // Penanda "Langkah n dari 3"

/// ─────────────────────────────────────────────────────────────────
/// REGISTRASI TEMA  –  Langkah 3 dari 3: pilih tema terang/gelap
///
/// Pilihan langsung diterapkan, jadi pengguna low vision bisa melihat
/// hasilnya sebelum menekan "Mulai pakai Modio". Bisa diubah lagi
/// kapan saja di halaman Profil.
/// ─────────────────────────────────────────────────────────────────
class RegistrasiTemaPage extends StatelessWidget {
  const RegistrasiTemaPage({super.key, required this.onSelesai});

  final VoidCallback onSelesai; // Dipanggil saat registrasi selesai

  static const List<(ThemeMode, IconData, String)> _pilihan = [
    (ThemeMode.light, Icons.light_mode_outlined, 'Latar putih, teks gelap'),
    (ThemeMode.dark, Icons.dark_mode_outlined, 'Latar gelap, nyaman di tempat redup dan mengurangi silau'),
    (ThemeMode.system, Icons.phone_android_outlined, 'Mengikuti tema yang dipilih di pengaturan ponsel'),
  ];

  Future<void> _pilih(BuildContext context, ThemeMode m) async {
    final ThemeController tc = ThemeController.instance;
    AksesibilitasController.instance.getar(); // Getaran ringan seperti sakelar pengaturan
    await tc.ganti(m);
    if (!context.mounted) return;
    SemanticsService.sendAnnouncement(View.of(context), '${tc.label(m)} dipilih.', Directionality.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeController tc = ThemeController.instance;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PenandaLangkah(langkah: 3),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        'Pilih tema tampilan',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.warnaTeksUtama),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tampilan langsung berubah saat dipilih. Bisa diubah lagi kapan saja di Profil.',
                      style: TextStyle(fontSize: 15, color: context.warnaTeksMuted),
                    ),
                    const SizedBox(height: 24),
                    ValueListenableBuilder<ThemeMode>(
                      valueListenable: tc.mode,
                      builder: (context, aktif, _) => Column(
                        children: [
                          for (final (ThemeMode m, IconData ikon, String ket) in _pilihan) ...[
                            _KartuTema(
                              ikon: ikon,
                              judul: tc.label(m),
                              keterangan: ket,
                              terpilih: aktif == m,
                              onTap: () => _pilih(context, m),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
                    SemanticsService.sendAnnouncement(View.of(context),
                        'Pendaftaran selesai. Membuka Dashboard.', Directionality.of(context));
                    onSelesai();
                  },
                  child: const Text('Mulai pakai Modio', style: TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu pilihan tema. Yang terpilih ditandai dengan garis tebal dan
/// ikon centang, tidak hanya warna, serta diumumkan sebagai terpilih.
class _KartuTema extends StatelessWidget {
  const _KartuTema({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.terpilih,
    required this.onTap,
  });

  final IconData ikon;
  final String judul;
  final String keterangan;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: terpilih,
      inMutuallyExclusiveGroup: true,
      label: '$judul. $keterangan',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: terpilih ? context.latarMasuk : context.warnaKartu,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: terpilih ? scheme.primary : context.warnaGarisInput,
            width: terpilih ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(ikon, size: 32, color: scheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(judul,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: terpilih ? FontWeight.w800 : FontWeight.w600,
                              color: context.warnaTeksUtama)),
                      const SizedBox(height: 4),
                      Text(keterangan, style: TextStyle(fontSize: 14, color: context.warnaTeksMuted)),
                    ],
                  ),
                ),
                if (terpilih) Icon(Icons.check_circle_rounded, color: scheme.primary, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
