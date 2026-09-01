import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme_extensions.dart';
import '../../data/auth_repository.dart';
import '../widgets/pin_keypad.dart';

/// ─────────────────────────────────────────────────────────────────
/// PIN LOCK PAGE  –  Layar kunci aplikasi
///
/// Menangani dua keadaan sekaligus:
///   • Belum ada PIN  → pengguna membuat PIN, dua langkah
///   • Sudah ada PIN  → pengguna memasukkan PIN
///
/// Seluruh verifikasi berjalan di perangkat. Pengguna tetap dapat
/// membuka aplikasinya tanpa koneksi internet.
/// ─────────────────────────────────────────────────────────────────

class PinLockPage extends StatefulWidget {
  const PinLockPage({super.key, required this.onBerhasil});

  /// Dipanggil setelah PIN diterima
  final VoidCallback onBerhasil;

  @override
  State<PinLockPage> createState() => _PinLockPageState();
}

enum _Tahap { memuat, buatBaru, konfirmasiBaru, masuk }

class _PinLockPageState extends State<PinLockPage> {
  final AuthRepository _repo = AuthRepository.instance;

  _Tahap _tahap = _Tahap.memuat;
  String _pin = '';
  String _pinPertama = '';
  String? _galat;
  bool _sibuk = false;

  int _sisaKunci = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _mulai();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _mulai() async {
    final bool ada = await _repo.sudahAdaPin();
    final int kunci = await _repo.sisaPenguncian();
    if (!mounted) return;

    setState(() {
      _tahap = ada ? _Tahap.masuk : _Tahap.buatBaru;
      _sisaKunci = kunci;
    });

    if (kunci > 0) _jalankanHitungMundur();

    // Pengguna tunanetra tidak melihat layar apa yang terbuka.
    // Pengumuman ini yang memberitahunya.
    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _judul,
        Directionality.of(context),
      );
    }
  }

  void _jalankanHitungMundur() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final int sisa = await _repo.sisaPenguncian();
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _sisaKunci = sisa);
      if (sisa <= 0) t.cancel();
    });
  }

  String get _judul => switch (_tahap) {
        _Tahap.memuat => 'Memuat',
        _Tahap.buatBaru => 'Buat PIN baru',
        _Tahap.konfirmasiBaru => 'Ulangi PIN baru',
        _Tahap.masuk => 'Masukkan PIN Anda',
      };

  String get _keterangan => switch (_tahap) {
        _Tahap.memuat => '',
        _Tahap.buatBaru =>
          'PIN enam angka untuk mengunci catatan keuangan Anda',
        _Tahap.konfirmasiBaru => 'Masukkan sekali lagi untuk memastikan',
        _Tahap.masuk => 'Enam angka',
      };

  void _tekanAngka(String angka) {
    if (_sibuk || _sisaKunci > 0 || _pin.length >= 6) return;

    setState(() {
      _pin += angka;
      _galat = null;
    });

    if (_pin.length == 6) _proses();
  }

  void _hapus() {
    if (_sibuk || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _proses() async {
    setState(() => _sibuk = true);

    switch (_tahap) {
      case _Tahap.buatBaru:
        final String? galat = _repo.periksaKekuatan(_pin);
        if (galat != null) {
          _tampilkanGalat(galat);
          return;
        }
        _pinPertama = _pin;
        setState(() {
          _pin = '';
          _tahap = _Tahap.konfirmasiBaru;
          _sibuk = false;
        });
        _umumkan('PIN diterima. Sekarang masukkan sekali lagi.');

      case _Tahap.konfirmasiBaru:
        if (_pin != _pinPertama) {
          _tampilkanGalat('PIN tidak sama. Ulangi dari awal.');
          setState(() {
            _tahap = _Tahap.buatBaru;
            _pinPertama = '';
          });
          return;
        }
        await _repo.simpanPin(_pin);
        if (!mounted) return;
        _umumkan('PIN berhasil dibuat. Membuka aplikasi.');
        HapticFeedback.mediumImpact();
        widget.onBerhasil();

      case _Tahap.masuk:
        final bool cocok = await _repo.verifikasiPin(_pin);
        if (!mounted) return;

        if (cocok) {
          _umumkan('PIN benar. Membuka aplikasi.');
          HapticFeedback.mediumImpact();
          widget.onBerhasil();
          return;
        }

        final int kunci = await _repo.sisaPenguncian();
        if (!mounted) return;

        if (kunci > 0) {
          setState(() => _sisaKunci = kunci);
          _jalankanHitungMundur();
          _tampilkanGalat('Terlalu banyak percobaan. Coba lagi nanti.');
        } else {
          final int sisa = await _repo.sisaPercobaan();
          if (!mounted) return;
          _tampilkanGalat('PIN salah. Sisa $sisa percobaan.');
        }

      case _Tahap.memuat:
        setState(() => _sibuk = false);
    }
  }

  void _tampilkanGalat(String pesan) {
    // Getaran kuat sebagai penanda kegagalan. Berbeda dari getaran
    // ringan saat menekan tombol, sehingga terbedakan tanpa melihat.
    HapticFeedback.heavyImpact();
    setState(() {
      _galat = pesan;
      _pin = '';
      _sibuk = false;
    });
    _umumkan(pesan);
  }

  void _umumkan(String pesan) {
    if (!mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      pesan,
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tahap == _Tahap.memuat) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool terkunci = _sisaKunci > 0;
    final scheme = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.gelap ? Brightness.light : Brightness.dark,
        statusBarBrightness: context.gelap ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            Icon(
              terkunci ? Icons.lock_clock : Icons.lock_outline,
              size: 52,
              color: scheme.primary,
            ),
            const SizedBox(height: 20),

            Text(
              _judul,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.warnaTeksUtama,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                terkunci
                    ? 'Coba lagi dalam $_sisaKunci detik'
                    : _keterangan,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.warnaTeksMuted,
                ),
              ),
            ),

            const SizedBox(height: 28),
            PinDots(nilai: _pin, galat: _galat != null),

            if (_galat != null) ...[
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.latarKeluar,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.warnaKeluar),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 20,
                      color: context.warnaKeluar,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _galat!,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.warnaKeluar,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(flex: 3),

            PinKeypad(
              onAngka: _tekanAngka,
              onHapus: _hapus,
              nonaktif: _sibuk || terkunci,
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
      ),
    );
  }
}
