import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../../../../core/navigation/app_route.dart'; // buatRute() untuk membuka halaman Tanya AI
import '../../../../core/services/aksesibilitas_controller.dart'; // Pola getaran berhasil/gagal
import '../../../../core/theme/app_typography.dart'; // Gaya teks khusus aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Warna sesuai tema
import '../../../../core/utils/accessibility_helper.dart'; // Membacakan hasil lewat screen reader
import '../../../../core/utils/currency_formatter.dart'; // DateFormatter untuk waktu pembuatan analisis
import '../../../ai_chat/presentation/pages/ai_assistant_page.dart'; // Halaman Tanya AI
import '../../data/ai_analysis_service.dart'; // Layanan & penyimpanan saran AI
import '../../data/report_model.dart'; // Model LaporanBulanan

/// ─────────────────────────────────────────────────────────────────
/// ANALISIS AI CARD  –  Saran AI langsung di halaman Laporan
///
/// Hasil analisis TERSIMPAN di HP per bulan: membuka Laporan lagi
/// langsung menampilkan analisis terakhir tanpa internet atau kuota AI.
/// Analisis baru hanya dibuat saat pengguna menekan "Buat analisis"
/// (belum ada) atau "Perbarui analisis" — yang terakhir meminta
/// konfirmasi dulu karena analisis lama diganti tanpa riwayat.
///
/// Beri `key` berbeda per bulan (mis. ValueKey('2026-10')) supaya
/// berpindah bulan memuat analisis bulan itu, bukan bulan sebelumnya.
/// ─────────────────────────────────────────────────────────────────
class AnalisisAiCard extends StatefulWidget {
  const AnalisisAiCard({super.key, required this.laporan});

  final LaporanBulanan laporan; // Laporan bulan yang sedang dibuka

  @override
  State<AnalisisAiCard> createState() => _AnalisisAiCardState();
}

class _AnalisisAiCardState extends State<AnalisisAiCard> {
  final AnalisisAiTersimpan _tersimpan = AnalisisAiTersimpan();

  AnalisisAi? _analisis; // Analisis yang sedang ditampilkan
  bool _membaca = true; // Membaca analisis tersimpan dari HP
  bool _meminta = false; // Sedang meminta analisis ke AI
  String? _galat; // Pesan bila permintaan ke AI gagal

  LaporanBulanan get _l => widget.laporan;

  @override
  void initState() {
    super.initState();
    _tersimpan.baca(_l.tahun, _l.bulan).then((a) {
      if (mounted) {
        setState(() {
          _analisis = a;
          _membaca = false;
        });
      }
    });
  }

  /// Meminta analisis baru lalu menimpa yang tersimpan. Bila gagal,
  /// analisis lama (kalau ada) tetap tampil dan tetap tersimpan.
  Future<void> _buat() async {
    setState(() {
      _meminta = true;
      _galat = null;
    });
    AccessibilityHelper.announce(context, 'Sedang membuat analisis AI.');
    try {
      final AnalisisAi baru = await AiAnalysisService().analisisLaporan(_l);
      await _tersimpan.simpan(_l.tahun, _l.bulan, baru);
      if (!mounted) return;
      setState(() {
        _analisis = baru;
        _meminta = false;
      });
      AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
      // Fokus TalkBack masih di tombol, jadi hasil baru dibacakan langsung.
      AccessibilityHelper.announce(context, 'Analisis AI. ${baru.judul}. ${_gabung(baru.saran)}');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _meminta = false;
        _galat = _analisis == null
            ? 'Analisis belum bisa dibuat. Periksa koneksi internet, lalu coba lagi.'
            : 'Analisis belum bisa diperbarui. Analisis sebelumnya tetap tersimpan.';
      });
      AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
      AccessibilityHelper.announce(context, _galat!);
    }
  }

  /// Konfirmasi sebelum menimpa: analisis lama tidak disimpan sebagai
  /// riwayat, jadi pengguna perlu tahu sebelum kehilangannya.
  Future<void> _perbarui() async {
    final bool? setuju = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(
          'Perbarui analisis?',
          style: AppTypography.titleMedium.copyWith(color: d.warnaTeksUtama),
        ),
        content: Text(
          'Analisis baru akan dibuat dari laporan ${_l.labelPeriode} saat ini. '
          'Analisis sebelumnya akan diganti dan tidak disimpan.',
          style: AppTypography.bodyMedium.copyWith(color: d.warnaTeksUtama, height: 1.5),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(100, 56)),
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Batal', style: TextStyle(fontSize: 17)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Perbarui', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
    if (setuju == true && mounted) await _buat();
  }

  String _gabung(List<String> saran) => [
        for (int i = 0; i < saran.length; i++) '${i + 1}. ${saran[i]}',
      ].join(' ');

  @override
  Widget build(BuildContext context) {
    final AnalisisAi? a = _analisis;
    final Color aksen = context.warnaInfo;
    final TextStyle isi = AppTypography.bodyMedium.copyWith(
      color: context.warnaTeksUtama,
      height: 1.55,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.latarInfo,
        borderRadius: BorderRadius.circular(16),
        // Satu warna & ketebalan di keempat sisi: Flutter tidak bisa
        // menggambar garis tepi beda-warna bersama sudut membulat.
        border: Border.all(color: aksen.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Judul ──────────────────────────────────────────────
          Semantics(
            header: true, // Bisa dilompati lewat navigasi Judul TalkBack
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: aksen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ExcludeSemantics(child: Icon(Icons.auto_awesome, size: 20, color: aksen)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Analisis AI',
                    style: AppTypography.titleMedium.copyWith(color: context.warnaTeksUtama),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Isi ────────────────────────────────────────────────
          if (_membaca)
            const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
          else if (a == null && !_meminta)
            Text(
              'Belum ada analisis untuk ${_l.labelPeriode}. AI akan memberi '
              'saran singkat dari laporan bulan ini, tanpa mengubah angkanya.',
              style: isi,
            )
          else if (a != null)
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.judul,
                    style: AppTypography.titleSmall.copyWith(color: aksen, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < a.saran.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 22, child: Text('${i + 1}.', style: isi)),
                          Expanded(child: Text(a.saran[i], style: isi)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          if (_meminta)
            Semantics(
              label: 'Sedang membuat analisis AI',
              excludeSemantics: true,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          if (_galat != null) ...[
            const SizedBox(height: 8),
            Text(_galat!, style: isi.copyWith(color: context.warnaKeluar, fontWeight: FontWeight.w600)),
          ],

          if (a != null) ...[
            const SizedBox(height: 8),
            Text(
              'Dibuat ${DateFormatter.full(a.dibuatPada.toLocal())}. Saran AI bisa '
              'keliru; angka resmi tetap yang ada di laporan.',
              style: AppTypography.bodySmall.copyWith(color: context.warnaTeksMuted, height: 1.5),
            ),
          ],

          // ── Tombol ─────────────────────────────────────────────
          if (!_membaca && !_meminta) ...[
            const SizedBox(height: 14),
            a == null
                ? FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _buat,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Buat analisis', style: TextStyle(fontSize: 16)),
                  )
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _perbarui,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Perbarui analisis', style: TextStyle(fontSize: 16)),
                  ),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.push(context, buatRute((_) => const AiAssistantPage())),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Tanya AI', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}
