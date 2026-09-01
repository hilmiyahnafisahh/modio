import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:speech_to_text/speech_to_text.dart' as  stt;

import '../../../../core/navigation/main_nav_controller.dart';
import '../../../../core/services/ai_parser_service.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../data/transaction_model.dart';
import '../../data/transaksi_repository.dart';
import 'record_transaction_modal.dart';

/// ─────────────────────────────────────────────────────────────────
/// ALUR CATAT TRANSAKSI VIA SUARA
///
/// Tiga tahap: (1) dengarkan ucapan lewat speech-to-text di perangkat,
/// (2) kirim teksnya ke AI (lihat AiParserService) untuk diuraikan jadi
/// nominal/kategori/catatan, (3) buka form Catat Transaksi yang sudah
/// terisi hasil tebakan itu — pengguna SELALU meninjau dan bisa
/// mengubah semuanya di form sebelum data benar-benar tersimpan. AI di
/// sini cuma mempercepat pengisian, bukan yang memutuskan.
/// ─────────────────────────────────────────────────────────────────

/// Menampilkan lembar "sedang mendengarkan" dan mengembalikan teks hasil
/// ucapan, atau null bila dibatalkan/tidak ada suara terdeteksi.
Future<String?> dengarkanUcapan(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (_) => const _VoiceListenSheet(),
  );
}

/// Mengirim [teks] ke AI untuk diuraikan jadi data transaksi. Menampilkan
/// snackbar dan mengembalikan null kalau gagal (mis. tidak ada koneksi ke
/// proxy backend) — pemanggil tidak perlu menangani error-nya sendiri.
Future<ParsedTransaction?> uraikanUcapanTransaksi(
  BuildContext context,
  String teks,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final TransaksiRepository repo = TransaksiRepository();
  final List<String> kategoriMasuk =
      await repo.kategoriUntuk(TransactionType.masuk);
  final List<String> kategoriKeluar =
      await repo.kategoriUntuk(TransactionType.keluar);

  if (!context.mounted) return null;

  try {
    return await AiParserService().uraikanTransaksi(
      teks: teks,
      kategoriMasuk: kategoriMasuk,
      kategoriKeluar: kategoriKeluar,
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Gagal memproses ucapan. Periksa koneksi internet lalu coba lagi.',
        ),
      ),
    );
    return null;
  }
}

/// Dipanggil dari tombol mic di halaman mana pun (di luar form yang
/// sedang terbuka). Mendengarkan, lalu bercabang dua: kalau ucapannya
/// perintah pindah halaman ("buka laporan", "chat AI", dst.), langsung
/// pindah lewat [MainNavController] tanpa menyentuh AI sama sekali —
/// murni cocok kata kunci, gratis dan instan. Selain itu, diperlakukan
/// sebagai dikte transaksi: diuraikan lewat AI lalu membuka form Catat
/// Transaksi baru yang sudah terisi. Mengembalikan true bila transaksi
/// akhirnya tersimpan, sama seperti kontrak RecordTransactionModal.
Future<bool?> mulaiCatatTransaksiSuara(BuildContext context) async {
  final String? teks = await dengarkanUcapan(context);
  if (teks == null || teks.trim().isEmpty || !context.mounted) return null;

  final VoiceNavTarget? tujuanNavigasi = deteksiPerintahNavigasi(teks);
  if (tujuanNavigasi != null) {
    MainNavController.instance.pindahKe(tujuanNavigasi);
    // Perpindahan tab (IndexedStack) tidak memicu pengumuman otomatis
    // dari Flutter/TalkBack seperti halnya Navigator.push — dan bahkan
    // untuk yang push pun tidak bisa diandalkan konsisten. Diumumkan
    // eksplisit di sini supaya pengguna TalkBack selalu tahu ia mendarat
    // di halaman yang benar, dari perintah suara halaman mana pun.
    if (context.mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Membuka halaman ${labelHalaman(tujuanNavigasi)}',
        Directionality.of(context),
      );
    }
    return null;
  }

  final ParsedTransaction? hasil = await uraikanUcapanTransaksi(context, teks);
  if (hasil == null || !context.mounted) return null;

  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecordTransactionModal(
      prefillIsIncome: switch (hasil.jenis) {
        'masuk' => true,
        'keluar' => false,
        _ => null,
      },
      prefillNominal: hasil.nominal,
      prefillKategori: hasil.kategori,
      prefillCatatan: hasil.catatan,
    ),
  );
}

class _VoiceListenSheet extends StatefulWidget {
  const _VoiceListenSheet();

  @override
  State<_VoiceListenSheet> createState() => _VoiceListenSheetState();
}

class _VoiceListenSheetState extends State<_VoiceListenSheet> {
  /// Jeda maksimum SEBELUM kata pertama terucap — lebih longgar karena
  /// pengguna masih menyusun kalimat, atau menunggu pengumuman "Sedang
  /// mendengarkan" selesai dibacakan TalkBack sebelum bisa mulai bicara.
  static const Duration _jedaSebelumBicara = Duration(seconds: 15);

  /// Jeda hening SETELAH sempat bicara sebelum dianggap selesai — lebih
  /// pendek, karena di titik ini pengguna sudah pasti sedang mendikte,
  /// jadi hening singkat sudah cukup jadi tanda ia sudah selesai.
  static const Duration _jedaSetelahBicara = Duration(seconds: 3);

  /// Plugin speech_to_text cuma punya SATU angka (pauseFor) yang berlaku
  /// dari awal listen() sampai akhir — tidak bisa membedakan "belum
  /// mulai bicara" dari "baru saja berhenti bicara". Makanya dua jeda di
  /// atas dikelola manual lewat [_timerHening], dijadwalkan ulang setiap
  /// [onResult] dengan durasi yang dipilih sesuai apakah [_teks] sudah
  /// terisi atau belum. pauseFor plugin sengaja tidak dipakai sama
  /// sekali; listenFor dipasang sebagai jaring pengaman kalau timer ini
  /// entah bagaimana gagal terpicu.
  static const Duration _batasTotal = Duration(seconds: 60);

  final stt.SpeechToText _speech = stt.SpeechToText();
  String _teks = '';
  bool _mendengarkan = false;
  bool _sudahDitutup = false;
  String? _error;
  Timer? _timerHening;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  void _jadwalkanTimerHening() {
    _timerHening?.cancel();
    final Duration jeda =
        _teks.trim().isEmpty ? _jedaSebelumBicara : _jedaSetelahBicara;
    _timerHening = Timer(jeda, () {
      _tutup(_teks.trim().isEmpty ? null : _teks.trim());
    });
  }

  Future<void> _mulai() async {
    final bool tersedia = await _speech.initialize(
      onError: (e) {
        if (!mounted) return;
        setState(() => _error = 'Mikrofon bermasalah: ${e.errorMsg}');
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _mendengarkan = false);
          // listenFor (jaring pengaman) berakhir, atau speech recognizer
          // berhenti sendiri lebih awal — dua-duanya diperlakukan sama
          // seperti timer hening kita habis.
          _tutup(_teks.trim().isEmpty ? null : _teks.trim());
        }
      },
    );

    if (!mounted) return;
    if (!tersedia) {
      setState(() => _error = 'Pengenalan suara tidak tersedia di perangkat ini.');
      return;
    }

    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(
        localeId: 'id_ID',
        listenFor: _batasTotal,
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => _teks = result.recognizedWords);
        _jadwalkanTimerHening();
      },
    );
    if (!mounted) return;
    setState(() => _mendengarkan = true);
    _jadwalkanTimerHening();
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Sedang mendengarkan',
      Directionality.of(context),
    );
  }

  /// Satu-satunya jalan keluar dari lembar ini, dipanggil baik oleh
  /// hening otomatis maupun tombol Batal. Dijaga [_sudahDitutup] karena
  /// onStatus dan timer bisa saja terpicu hampir bersamaan — tanpa
  /// penjaga ini Navigator.pop bisa terpanggil dua kali dan melempar
  /// error.
  void _tutup(String? hasil) {
    if (_sudahDitutup) return;
    _sudahDitutup = true;
    _timerHening?.cancel();
    _speech.stop();
    Navigator.pop(context, hasil);
  }

  void _batal() {
    _speech.cancel();
    _tutup(null);
  }

  @override
  void dispose() {
    _timerHening?.cancel();
    _speech.stop();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.warnaKartu,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mendengarkan
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.4),
              ),
              child: Icon(
                Icons.mic_rounded,
                size: 36,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error ??
                  (_mendengarkan
                      ? 'Sedang mendengarkan…'
                      : (_teks.isEmpty
                          ? 'Menyiapkan mikrofon…'
                          : 'Diam sebentar untuk selesai…')),
              style: AppTypography.titleMedium.copyWith(
                color: context.warnaTeksUtama,
              ),
              textAlign: TextAlign.center,
            ),
            if (_teks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _teks,
                style: AppTypography.bodyMedium.copyWith(
                  color: context.warnaTeksMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _batal,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                ),
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
