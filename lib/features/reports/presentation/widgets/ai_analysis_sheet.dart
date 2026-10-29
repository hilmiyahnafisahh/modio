import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../../../../core/services/aksesibilitas_controller.dart'; // Pola getaran berhasil/gagal
import '../../../../core/theme/app_typography.dart'; // Gaya teks khusus aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema
import '../../../../core/utils/accessibility_helper.dart'; // Untuk membacakan hasil lewat screen reader
import '../../data/ai_analysis_service.dart'; // Layanan saran AI untuk laporan
import '../../data/report_model.dart'; // Model LaporanBulanan
import 'ai_insight_widget.dart'; // Kartu ringkasan naratif

/// Membuka lembar bawah berisi saran AI untuk [laporan].
///
/// Saran diminta saat lembar dibuka, bukan otomatis setiap halaman
/// Laporan tampil — supaya kuota AI dan kuota internet pengguna hanya
/// terpakai bila memang diminta.
Future<void> tampilkanAnalisisAi(BuildContext context, LaporanBulanan laporan) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // Lembar boleh lebih tinggi dari setengah layar
    backgroundColor: Colors.transparent,
    builder: (_) => _AnalisisAiSheet(laporan: laporan),
  );
}

class _AnalisisAiSheet extends StatefulWidget {
  const _AnalisisAiSheet({required this.laporan});

  final LaporanBulanan laporan; // Laporan yang akan dianalisis

  @override
  State<_AnalisisAiSheet> createState() => _AnalisisAiSheetState();
}

class _AnalisisAiSheetState extends State<_AnalisisAiSheet> {
  late Future<AnalisisAi> _analisis; // Permintaan saran yang sedang berjalan

  @override
  void initState() {
    super.initState();
    _minta();
  }

  void _minta() { // Kirim (ulang) permintaan saran ke backend
    setState(() {
      _analisis = AiAnalysisService().analisisLaporan(widget.laporan);
    });
    _analisis.then((hasil) {
      if (!mounted) return;
      AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
      // Fokus TalkBack masih di tombol yang membuka lembar ini, jadi
      // hasilnya tidak akan terbaca kalau tidak diumumkan.
      AccessibilityHelper.announce(
        context,
        'Saran AI. ${hasil.judul}. ${_gabungSaran(hasil.saran)}',
      );
    }, onError: (_) {
      if (!mounted) return;
      AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
      AccessibilityHelper.announce(context, _pesanGagal);
    });
  }

  static const String _pesanGagal =
      'Saran AI belum bisa diambil. Periksa koneksi internet, lalu coba lagi.';

  String _gabungSaran(List<String> saran) => [
        for (int i = 0; i < saran.length; i++) '${i + 1}. ${saran[i]}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true, // Dikenali TalkBack sebagai judul lembar
              child: Text(
                'Saran AI · ${widget.laporan.labelPeriode}',
                style: AppTypography.titleLarge.copyWith(
                  color: context.warnaTeksUtama,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<AnalisisAi>(
              future: _analisis,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Semantics(
                    liveRegion: true, // Dibacakan otomatis saat muncul
                    label: 'Sedang meminta saran AI',
                    excludeSemantics: true,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _pesanGagal,
                        style: AppTypography.bodyLarge.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _minta,
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  );
                }

                final AnalisisAi hasil = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AiInsightWidget(
                      title: hasil.judul,
                      description: _gabungSaran(hasil.saran),
                      type: switch (hasil.nada) {
                        'positif' => InsightType.positive,
                        'negatif' => InsightType.negative,
                        _ => InsightType.neutral,
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Saran ini dibuat AI dan bisa keliru. '
                      'Angka resmi tetap yang ada di laporan.',
                      style: AppTypography.bodySmall.copyWith(
                        color: context.warnaTeksMuted,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
