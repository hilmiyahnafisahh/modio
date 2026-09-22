import 'dart:async'; // Untuk Timer (jeda hening deteksi selesai bicara)

import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter
import 'package:flutter/semantics.dart'; // Untuk mengirim pengumuman ke screen reader
import 'package:speech_to_text/speech_to_text.dart' as  stt; // Plugin pengenalan suara jadi teks

import '../../../../core/navigation/main_nav_controller.dart'; // Pengontrol navigasi tab & suara
import '../../../../core/services/ai_parser_service.dart'; // Layanan AI untuk menguraikan teks jadi data transaksi
import '../../../../core/services/keamanan_controller.dart'; // Sakelar Mode Suara: mengatur boleh/tidaknya fitur suara dipakai
import '../../../../core/theme/app_typography.dart'; // Gaya teks khusus aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema
import '../../data/transaction_model.dart'; // Model data transaksi & tipe (masuk/keluar)
import '../../data/transaksi_repository.dart'; // Sumber data transaksi & kategori
import 'record_transaction_modal.dart'; // Modal form catat transaksi

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
///
/// Satu-satunya titik masuk mikrofon di seluruh aplikasi (dipakai
/// tombol mic pencatat transaksi maupun "Ucapkan PIN" di layar kunci)
/// — sehingga sakelar Mode Suara di Pengaturan cukup dijaga di sini
/// saja untuk mematikan fitur suara di mana pun ia dipakai.
Future<String?> dengarkanUcapan(BuildContext context) { // Fungsi untuk membuka lembar dengar suara
  if (!KeamananController.instance.suaraAktif.value) { // Mode Suara sedang dimatikan lewat Pengaturan
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Mode Suara nonaktif. Nyalakan di Profil > Mode Suara untuk memakai fitur ini.',
        ),
      ),
    );
    return Future.value(null); // Batalkan tanpa membuka mikrofon sama sekali
  }

  return showModalBottomSheet<String>( // Tampilkan modal dari bawah dan tunggu hasil teksnya
    context: context,
    backgroundColor: Colors.transparent, // Latar transparan agar sudut modal terlihat membulat
    isDismissible: true, // Modal bisa ditutup dengan mengetuk di luar area
    builder: (_) => const _VoiceListenSheet(), // Widget lembar pendengar suara
  );
}

/// Mengirim [teks] ke AI untuk diuraikan jadi data transaksi. Kalau AI-nya
/// gagal dihubungi (mis. tidak ada koneksi ke proxy backend), TETAP
/// mengembalikan hasil — bukan null — berisi ucapan mentah sebagai
/// catatan saja, supaya pengguna tetap bisa lanjut mengisi form secara
/// manual alih-alih ucapannya terbuang sia-sia. Menampilkan snackbar
/// supaya pengguna tahu penguraian otomatis gagal.
Future<ParsedTransaction?> uraikanUcapanTransaksi(
  BuildContext context,
  String teks, // Teks hasil ucapan yang akan diuraikan
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context); // Simpan referensi sebelum async gap
  final TransaksiRepository repo = TransaksiRepository(); // Buat instance repository transaksi
  final List<String> kategoriMasuk =
      await repo.kategoriUntuk(TransactionType.masuk); // Ambil daftar kategori pemasukan
  final List<String> kategoriKeluar =
      await repo.kategoriUntuk(TransactionType.keluar); // Ambil daftar kategori pengeluaran

  if (!context.mounted) return null; // Batalkan jika context sudah tidak valid setelah await

  try {
    return await AiParserService().uraikanTransaksi( // Panggil AI untuk menguraikan teks jadi data transaksi
      teks: teks,
      kategoriMasuk: kategoriMasuk, // Beri konteks kategori yang tersedia agar tebakan lebih akurat
      kategoriKeluar: kategoriKeluar,
    );
  } catch (_) { // Jika terjadi error apa pun (mis. tidak ada koneksi)
    messenger.showSnackBar( // Tampilkan pesan error ke pengguna
      const SnackBar(
        content: Text(
          'Tidak bisa menguraikan otomatis. Ucapan disalin ke catatan — '
          'lengkapi sisanya secara manual.',
        ),
      ),
    );
    // Bukan null: ucapan mentah tetap dibawa sebagai catatan, supaya
    // pemanggil (mulaiCatatTransaksiSuara / _pakaiSuara) tetap membuka
    // form yang sudah terisi sebagian alih-alih berhenti total.
    return ParsedTransaction(catatan: teks);
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
Future<bool?> mulaiCatatTransaksiSuara(BuildContext context) async { // Entry point tombol mic global
  final String? teks = await dengarkanUcapan(context); // Dengarkan ucapan pengguna, tunggu hasilnya
  if (teks == null || teks.trim().isEmpty || !context.mounted) return null; // Batalkan jika kosong/dibatalkan

  final VoiceNavTarget? tujuanNavigasi = deteksiPerintahNavigasi(teks); // Cek apakah ucapan berupa perintah navigasi
  if (tujuanNavigasi != null) { // Jika terdeteksi sebagai perintah navigasi
    MainNavController.instance.pindahKe(tujuanNavigasi); // Pindah halaman langsung, tanpa AI
    // Perpindahan tab (IndexedStack) tidak memicu pengumuman otomatis
    // dari Flutter/TalkBack seperti halnya Navigator.push — dan bahkan
    // untuk yang push pun tidak bisa diandalkan konsisten. Diumumkan
    // eksplisit di sini supaya pengguna TalkBack selalu tahu ia mendarat
    // di halaman yang benar, dari perintah suara halaman mana pun.
    if (context.mounted) {
      SemanticsService.sendAnnouncement( // Umumkan halaman tujuan lewat screen reader
        View.of(context),
        'Membuka halaman ${labelHalaman(tujuanNavigasi)}',
        Directionality.of(context),
      );
    }
    return null; // Selesai, tidak lanjut ke alur pencatatan transaksi
  }

  final ParsedTransaction? hasil = await uraikanUcapanTransaksi(context, teks); // Uraikan ucapan jadi data transaksi lewat AI
  if (hasil == null || !context.mounted) return null; // Batalkan jika gagal atau context tidak valid

  return showModalBottomSheet<bool>( // Buka form catat transaksi yang sudah terisi hasil tebakan AI
    context: context,
    isScrollControlled: true, // Modal bisa memenuhi tinggi layar (untuk keyboard)
    backgroundColor: Colors.transparent,
    builder: (_) => RecordTransactionModal(
      prefillIsIncome: switch (hasil.jenis) { // Tentukan jenis transaksi awal dari hasil AI
        'masuk' => true,
        'keluar' => false,
        _ => null, // Tidak diketahui, biarkan pengguna memilih sendiri
      },
      prefillNominal: hasil.nominal, // Isi awal nominal dari hasil AI
      prefillKategori: hasil.kategori, // Isi awal kategori dari hasil AI
      prefillMetode: hasil.metode, // Isi awal metode bayar dari hasil AI
      prefillCatatan: hasil.catatan, // Isi awal catatan dari hasil AI
    ),
  );
}

class _VoiceListenSheet extends StatefulWidget { // Lembar bawah yang menampilkan status "sedang mendengarkan"
  const _VoiceListenSheet();

  @override
  State<_VoiceListenSheet> createState() => _VoiceListenSheetState(); // Buat objek state terkait
}

class _VoiceListenSheetState extends State<_VoiceListenSheet> {
  /// Jeda maksimum SEBELUM kata pertama terucap — lebih longgar karena
  /// pengguna masih menyusun kalimat, atau menunggu pengumuman "Sedang
  /// mendengarkan" selesai dibacakan TalkBack sebelum bisa mulai bicara.
  static const Duration _jedaSebelumBicara = Duration(seconds: 15); // Batas waktu tunggu sebelum ada suara

  /// Jeda hening SETELAH sempat bicara sebelum dianggap selesai — lebih
  /// pendek, karena di titik ini pengguna sudah pasti sedang mendikte,
  /// jadi hening singkat sudah cukup jadi tanda ia sudah selesai.
  static const Duration _jedaSetelahBicara = Duration(seconds: 3); // Batas hening setelah mulai bicara

  /// Plugin speech_to_text cuma punya SATU angka (pauseFor) yang berlaku
  /// dari awal listen() sampai akhir — tidak bisa membedakan "belum
  /// mulai bicara" dari "baru saja berhenti bicara". Makanya dua jeda di
  /// atas dikelola manual lewat [_timerHening], dijadwalkan ulang setiap
  /// [onResult] dengan durasi yang dipilih sesuai apakah [_teks] sudah
  /// terisi atau belum. pauseFor plugin sengaja tidak dipakai sama
  /// sekali; listenFor dipasang sebagai jaring pengaman kalau timer ini
  /// entah bagaimana gagal terpicu.
  static const Duration _batasTotal = Duration(seconds: 60); // Batas waktu total mendengarkan sebagai jaring pengaman

  final stt.SpeechToText _speech = stt.SpeechToText(); // Instance plugin pengenalan suara
  String _teks = ''; // Teks hasil pengenalan suara yang sedang terkumpul
  bool _mendengarkan = false; // Status apakah mikrofon sedang aktif mendengarkan
  bool _sudahDitutup = false; // Penjaga agar lembar hanya ditutup sekali
  String? _error; // Pesan error jika mikrofon bermasalah
  Timer? _timerHening; // Timer untuk mendeteksi jeda hening

  @override
  void initState() { // Dipanggil sekali saat widget pertama dibuat
    super.initState();
    _mulai(); // Mulai proses inisialisasi & mendengarkan
  }

  void _jadwalkanTimerHening() { // Menjadwalkan ulang timer deteksi hening
    _timerHening?.cancel(); // Batalkan timer lama jika ada
    final Duration jeda = // Pilih durasi jeda sesuai apakah sudah ada teks terucap
        _teks.trim().isEmpty ? _jedaSebelumBicara : _jedaSetelahBicara;
    _timerHening = Timer(jeda, () { // Jalankan sekali setelah durasi jeda berlalu
      _tutup(_teks.trim().isEmpty ? null : _teks.trim()); // Tutup lembar, kirim teks atau null
    });
  }

  Future<void> _mulai() async { // Inisialisasi plugin suara dan mulai mendengarkan
    final bool tersedia = await _speech.initialize( // Siapkan plugin, daftarkan callback status/error
      onError: (e) {
        if (!mounted) return; // Abaikan jika widget sudah dilepas
        setState(() => _error = 'Mikrofon bermasalah: ${e.errorMsg}'); // Tampilkan pesan error mikrofon
      },
      onStatus: (status) {
        if (!mounted) return; // Abaikan jika widget sudah dilepas
        if (status == 'done' || status == 'notListening') { // Status berhenti mendengarkan
          setState(() => _mendengarkan = false); // Update status tidak lagi mendengarkan
          // listenFor (jaring pengaman) berakhir, atau speech recognizer
          // berhenti sendiri lebih awal — dua-duanya diperlakukan sama
          // seperti timer hening kita habis.
          _tutup(_teks.trim().isEmpty ? null : _teks.trim()); // Tutup lembar dengan hasil teks yang ada
        }
      },
    );

    if (!mounted) return; // Abaikan jika widget sudah dilepas
    if (!tersedia) { // Jika plugin tidak berhasil diinisialisasi
      setState(() => _error = 'Pengenalan suara tidak tersedia di perangkat ini.'); // Tampilkan pesan error
      return;
    }

    await _speech.listen( // Mulai mendengarkan suara pengguna
      listenOptions: stt.SpeechListenOptions(
        localeId: 'id_ID', // Gunakan bahasa Indonesia untuk pengenalan suara
        listenFor: _batasTotal, // Batas waktu total sebagai jaring pengaman
      ),
      onResult: (result) { // Dipanggil setiap ada hasil pengenalan baru
        if (!mounted) return; // Abaikan jika widget sudah dilepas
        setState(() => _teks = result.recognizedWords); // Simpan teks terbaru yang dikenali
        _jadwalkanTimerHening(); // Jadwalkan ulang timer hening sesuai teks terbaru
      },
    );
    if (!mounted) return; // Abaikan jika widget sudah dilepas
    setState(() => _mendengarkan = true); // Tandai mikrofon mulai aktif mendengarkan
    _jadwalkanTimerHening(); // Mulai timer hening pertama kali
    SemanticsService.sendAnnouncement( // Umumkan ke screen reader bahwa mendengarkan sudah mulai
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
  void _tutup(String? hasil) { // Menutup lembar dan mengembalikan hasil teks (atau null)
    if (_sudahDitutup) return; // Cegah penutupan ganda
    _sudahDitutup = true; // Tandai sudah ditutup
    _timerHening?.cancel(); // Hentikan timer hening
    _speech.stop(); // Hentikan proses mendengarkan
    Navigator.pop(context, hasil); // Tutup modal dan kembalikan hasil ke pemanggil
  }

  void _batal() { // Dipanggil saat pengguna menekan tombol Batal
    _speech.cancel(); // Batalkan proses pengenalan suara sepenuhnya
    _tutup(null); // Tutup lembar tanpa hasil
  }

  @override
  void dispose() { // Dipanggil saat widget dihancurkan
    _timerHening?.cancel(); // Hentikan timer hening
    _speech.stop(); // Hentikan proses mendengarkan jika masih berjalan
    _speech.cancel(); // Pastikan sesi pengenalan suara dibatalkan
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme; // Skema warna tema aktif

    return SafeArea( // Hindari area sistem seperti notch/status bar
      child: Container(
        margin: const EdgeInsets.all(16), // Jarak luar dari tepi layar
        padding: const EdgeInsets.all(24), // Jarak dalam konten
        decoration: BoxDecoration(
          color: context.warnaKartu, // Warna latar kartu
          borderRadius: BorderRadius.circular(24), // Sudut membulat besar
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Tinggi kolom sekecil mungkin
          children: [
            Container( // Lingkaran ikon mikrofon
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mendengarkan // Warna lebih terang saat aktif mendengarkan
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
              _error ?? // Tampilkan error jika ada, atau...
                  (_mendengarkan
                      ? 'Sedang mendengarkan…' // ...status sedang mendengarkan, atau...
                      : (_teks.isEmpty
                          ? 'Menyiapkan mikrofon…' // ...masih menyiapkan, atau...
                          : 'Diam sebentar untuk selesai…')), // ...menunggu hening untuk selesai
              style: AppTypography.titleMedium.copyWith(
                color: context.warnaTeksUtama,
              ),
              textAlign: TextAlign.center,
            ),
            if (_teks.isNotEmpty) ...[ // Tampilkan teks hasil pengenalan jika sudah ada
              const SizedBox(height: 12),
              Text(
                _teks, // Tampilkan transkrip ucapan pengguna secara langsung
                style: AppTypography.bodyMedium.copyWith(
                  color: context.warnaTeksMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, // Tombol selebar area kartu
              child: OutlinedButton(
                onPressed: _batal, // Batalkan proses mendengarkan
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56), // Tinggi minimum tombol untuk target sentuh
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

/// Tombol mengambang pencatat transaksi suara, dipakai di Beranda,
/// Riwayat, Laporan, dan Profil.
///
/// Menghilang sepenuhnya (bukan sekadar nonaktif) saat Mode Suara mati
/// di Pengaturan — tombol yang tetap terlihat tapi cuma menampilkan
/// pesan galat saat ditekan membingungkan, seolah rusak.
/// [dengarkanUcapan] tetap punya penjagaan sendiri sebagai jaring
/// pengaman kedua untuk jalur lain yang tidak lewat tombol ini (mis.
/// mic di dalam RecordTransactionModal).
class VoiceFab extends StatelessWidget { // Tombol mengambang khusus catat transaksi via suara
  const VoiceFab({super.key, required this.heroTag, required this.onPressed});

  final String heroTag; // Tag unik agar tidak bentrok antar FAB di halaman lain
  final VoidCallback onPressed; // Aksi saat tombol ditekan

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>( // Bangun ulang saat sakelar Mode Suara berubah
      valueListenable: KeamananController.instance.suaraAktif,
      builder: (context, suaraAktif, _) {
        if (!suaraAktif) return const SizedBox.shrink(); // sembunyikan tombol sepenuhnya saat mode suara mati

        final scheme = Theme.of(context).colorScheme; // skema warna tema aktif
        return SizedBox( // bungkus tombol apung dengan ukuran tetap
          width: 64,
          height: 64,
          child: FloatingActionButton( // tombol bulat mengambang khas Material Design
            heroTag: heroTag,
            onPressed: onPressed,
            backgroundColor: scheme.primary, // warna latar tombol memakai warna utama tema
            elevation: 4, // tinggi bayangan tombol agar terlihat "mengambang"
            shape: const CircleBorder(), // bentuk tombol dibuat bulat sempurna
            tooltip: 'Catat transaksi dengan suara', // teks bantuan saat ditekan lama
            // Semantics eksplisit, bukan cuma mengandalkan tooltip.
            // Tanpa label ini pembaca layar hanya menyebutnya "tombol"
            // tanpa keterangan, tak terbedakan dari tombol tambah lain.
            child: Semantics(
              button: true,
              label: 'Catat transaksi dengan suara',
              excludeSemantics: true,
              child: Icon(
                Icons.mic_rounded,
                color: scheme.onPrimary, // warna ikon kontras dengan warna latar tombol
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }
}
