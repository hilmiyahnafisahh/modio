import 'package:flutter/material.dart';
import '../../../../core/services/aksesibilitas_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// PENGATURAN AKSESIBILITAS PAGE
/// ─────────────────────────────────────────────────────────────────

class PengaturanAksesibilitasPage extends StatefulWidget {
  const PengaturanAksesibilitasPage({super.key});

  @override
  State<PengaturanAksesibilitasPage> createState() =>
      _PengaturanAksesibilitasPageState();
}

class _PengaturanAksesibilitasPageState
    extends State<PengaturanAksesibilitasPage> {
  final _ak = AksesibilitasController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.warnaTeksUtama,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
        title: Text(
          'Aksesibilitas',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // ── Banner Info ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.latarMasuk,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: context.warnaMasuk.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: context.warnaMasuk),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modio dirancang untuk memenuhi standar aksesibilitas WCAG 2.1 tingkat AAA. Pengaturan di sini membantu menyesuaikan pengalaman Anda.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.warnaMasuk,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Setiap sakelar di bawah membaca & menulis langsung ke
            // AksesibilitasController — ListenableBuilder membangun
            // ulang bagian ini saja saat salah satu nilainya berubah,
            // dari mana pun perubahan itu dipicu.
            ListenableBuilder(
              listenable: Listenable.merge([
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
                    _buildSectionLabel('PENGLIHATAN'),
                    const SizedBox(height: 8),
                    _buildToggleGroup([
                      _ToggleItem(
                        icon: Icons.contrast_rounded,
                        label: 'Kontras Tinggi',
                        description:
                            'Menghilangkan tingkat warna "diredam" — teks sekunder dan garis kartu memakai kekuatan penuh di seluruh aplikasi',
                        value: _ak.kontrasTinggi.value,
                        onChanged: (v) {
                          _ak.getar();
                          _ak.ubahKontrasTinggi(v);
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
                    _buildToggleGroup([
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
                          if (_ak.getaran.value) _ak.getar();
                          _ak.ubahGetaran(v);
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
            const SizedBox(height: 32),

            // ── Tombol Reset ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _resetDefaults,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: context.warnaGaris),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _resetDefaults() {
    _ak.ubahKontrasTinggi(false);
    _ak.ubahTeksTebal(false);
    _ak.ubahGetaran(true);
    _ak.ubahKurangiAnimasi(false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Pengaturan aksesibilitas direset ke default',
          style: TextStyle(
            color: context.gelap ? AppColors.darkBg : AppColors.white,
          ),
        ),
        backgroundColor: context.warnaMasuk,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.warnaTeksMuted,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildToggleGroup(List<_ToggleItem> items) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: item.value
                            ? context.latarMasuk
                            : context.warnaKartuMenonjol,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 18,
                        color: item.value
                            ? context.warnaMasuk
                            : context.warnaTeksMuted,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.warnaTeksUtama,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.warnaTeksMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch.adaptive(
                      value: item.value,
                      onChanged: item.onChanged,
                      activeThumbColor: AppColors.white,
                      activeTrackColor: scheme.primary,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1, indent: 64, color: context.warnaGaris),
            ],
          );
        }),
      ),
    );
  }
}

class _ToggleItem {
  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });
}
