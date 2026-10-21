import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../services/aksesibilitas_controller.dart'; // Untuk getaran yang menghormati sakelar Getaran
import '../theme/app_typography.dart'; // Gaya teks aplikasi
import '../theme/theme_extensions.dart'; // Warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// AKHIR HALAMAN  –  Penanda bahwa isi halaman yang digulir sudah habis
///
/// Dua bagian yang dipakai bersama pada halaman panjang:
///
/// • [GetarAkhirGulir] — getaran ringan SEKALI saat halaman mencapai
///   dasar. Sengaja tanpa pengumuman suara: TalkBack sudah punya bunyi
///   batas gulir sendiri, dan pengumuman bisa memotong TalkBack yang
///   sedang membacakan elemen terakhir.
///
/// • [PenandaAkhirHalaman] — teks biasa di ujung isi, misalnya
///   "Akhir riwayat. 12 transaksi." TalkBack membacanya secara alami
///   setelah elemen terakhir, tanpa memotong apa pun.
///
/// Cara pakai:
///   GetarAkhirGulir(
///     child: CustomScrollView(slivers: [..., PenandaAkhirHalaman(...)]),
///   )
/// ─────────────────────────────────────────────────────────────────

class GetarAkhirGulir extends StatefulWidget { // Pembungkus area gulir yang bergetar saat sampai dasar
  final Widget child; // Area gulir yang dipantau (ScrollView apa pun)

  const GetarAkhirGulir({super.key, required this.child});

  /// Jarak dari dasar (dp) yang harus ditinggalkan dulu sebelum getaran
  /// boleh muncul lagi. Mencegah getaran berulang saat halaman sedikit
  /// memantul di dasar.
  static const double jarakReset = 48;

  @override
  State<GetarAkhirGulir> createState() => _GetarAkhirGulirState();
}

class _GetarAkhirGulirState extends State<GetarAkhirGulir> {
  bool _diDasar = false; // true selama halaman sedang berada di dasar

  bool _pantau(ScrollNotification n) {
    // Hanya area gulir utama halaman, bukan daftar bersarang di dalamnya.
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    // Halaman yang isinya muat satu layar tidak perlu penanda dasar.
    if (n.metrics.maxScrollExtent <= 0) return false;

    final double sisa = n.metrics.extentAfter; // Jarak tersisa sampai dasar
    if (!_diDasar && sisa <= 1) { // Baru saja sampai di dasar
      _diDasar = true;
      AksesibilitasController.instance.getar(); // Getaran ringan sekali
    } else if (_diDasar && sisa > GetarAkhirGulir.jarakReset) { // Sudah naik lagi
      _diDasar = false;
    }
    return false; // Jangan hentikan notifikasi, RefreshIndicator dll tetap butuh
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _pantau,
      child: widget.child,
    );
  }
}

class PenandaAkhirHalaman extends StatelessWidget { // Teks penutup di ujung isi halaman
  /// Teks yang tampil, mis. "Akhir riwayat".
  final String teks;

  /// Kalimat yang dibacakan pembaca layar, boleh lebih lengkap dari
  /// [teks] (mis. ditambah ringkasan total). Default sama dengan [teks].
  final String? labelSemantik;

  const PenandaAkhirHalaman({super.key, required this.teks, this.labelSemantik});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: labelSemantik ?? teks, // Kalimat penutup yang dibacakan
      excludeSemantics: true, // Garis dan teks anak tidak dibaca terpisah
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Expanded(child: Divider(color: context.warnaGaris)), // Garis kiri dekoratif
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                teks,
                style: AppTypography.labelMedium.copyWith(color: context.warnaTeksMuted),
              ),
            ),
            Expanded(child: Divider(color: context.warnaGaris)), // Garis kanan dekoratif
          ],
        ),
      ),
    );
  }
}
