import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/services/aksesibilitas_controller.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../auth/data/auth_repository.dart';

/// ─────────────────────────────────────────────────────────────────
/// GANTI PIN PAGE  –  Ubah PIN keamanan pengguna
/// ─────────────────────────────────────────────────────────────────

class GantiPinPage extends StatefulWidget {
  const GantiPinPage({super.key});

  @override
  State<GantiPinPage> createState() => _GantiPinPageState();
}

class _GantiPinPageState extends State<GantiPinPage> {
  // Step: 0 = PIN lama, 1 = PIN baru, 2 = konfirmasi PIN baru
  int _step = 0;
  final List<String> _pins = ['', '', ''];

  static const int _pinLength = 6;

  final List<String> _stepLabels = [
    'Masukkan PIN saat ini',
    'Buat PIN baru',
    'Konfirmasi PIN baru',
  ];

  final List<String> _stepSubs = [
    'Masukkan 6 digit PIN Anda yang sekarang',
    'Masukkan 6 digit PIN baru Anda',
    'Masukkan kembali PIN baru untuk konfirmasi',
  ];

  bool _hasError    = false;
  bool _obscure     = true;
  bool _isChecking  = false; // sedang verifikasi/simpan ke DB
  String _errorMessage = '';

  // AuthRepository, bukan ProfileRepository. Sebelumnya halaman ini
  // menyimpan PIN lewat ProfileRepository sementara layar kunci
  // aplikasi (PinLockPage) memverifikasi lewat AuthRepository —
  // dua sistem PIN terpisah yang tidak saling tahu. Akibatnya
  // mengganti PIN di sini tidak pernah benar-benar mengubah PIN yang
  // dipakai untuk membuka aplikasi; PIN lama tetap berlaku selamanya.
  final _repo = AuthRepository.instance;

  // AuthRepository sendiri tidak menolak percobaan baru saat sedang
  // terkunci — ia akan tetap memproses dan menghitung ulang. UI inilah
  // yang wajib menahan input selama terkunci, persis pola yang sudah
  // dipakai di PinLockPage (layar kunci utama).
  int _sisaKunci = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _jalankanHitungMundur() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      final int sisa = await _repo.sisaPenguncian();
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _sisaKunci = sisa;
        _errorMessage = sisa > 0
            ? 'Terlalu banyak percobaan. Coba lagi dalam $sisa detik.'
            : '';
      });
      if (sisa <= 0) {
        t.cancel();
        setState(() => _hasError = false);
      }
    });
  }

  void _onKeyTap(String val) {
    if (_isChecking || _sisaKunci > 0) return; // jangan input saat proses DB/terkunci
    AksesibilitasController.instance.getar();
    final current = _pins[_step];
    if (current.length < _pinLength) {
      setState(() {
        _pins[_step] = current + val;
        _hasError = false;
      });
      if (_pins[_step].length == _pinLength) {
        _onPinComplete();
      }
    }
  }

  void _onDelete() {
    if (_isChecking || _sisaKunci > 0) return;
    AksesibilitasController.instance.getar();
    final current = _pins[_step];
    if (current.isNotEmpty) {
      setState(() => _pins[_step] = current.substring(0, current.length - 1));
    }
  }

  Future<void> _onPinComplete() async {
    if (_step == 0) {
      // Verifikasi PIN lama dari database
      setState(() => _isChecking = true);
      final bool valid = await _repo.verifikasiPin(_pins[0]);
      if (!mounted) return;
      setState(() => _isChecking = false);

      if (!valid) {
        // AuthRepository menghitung percobaan gagal dan mengunci
        // sementara setelah terlalu banyak salah — sama seperti layar
        // kunci, sebab keduanya kini memakai penghitung yang sama.
        // Tanpa pesan ini pengguna terkunci tanpa tahu sebabnya.
        final int kunci = await _repo.sisaPenguncian();
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _pins[0] = '';
          _sisaKunci = kunci;
          _errorMessage = kunci > 0
              ? 'Terlalu banyak percobaan. Coba lagi dalam $kunci detik.'
              : 'PIN saat ini tidak sesuai';
        });
        if (kunci > 0) _jalankanHitungMundur();
        return;
      }
    }

    if (_step == 1) {
      // PIN terlalu mudah ditebak ditolak di sini juga — sama seperti
      // saat membuat PIN pertama kali di layar kunci, bukan cuma saat
      // pendaftaran awal.
      final String? galat = _repo.periksaKekuatan(_pins[1]);
      if (galat != null) {
        setState(() {
          _hasError = true;
          _pins[1] = '';
          _errorMessage = galat;
        });
        return;
      }
    }

    if (_step == 2) {
      // Validasi kecocokan PIN baru
      if (_pins[1] != _pins[2]) {
        setState(() {
          _hasError = true;
          _pins[2] = '';
          _errorMessage = 'Konfirmasi PIN tidak cocok';
        });
        return;
      }
      // Simpan PIN baru ke database
      setState(() => _isChecking = true);
      await _repo.simpanPin(_pins[1]);
      if (!mounted) return;
      setState(() => _isChecking = false);
      _onSuccess();
      return;
    }

    setState(() {
      _step++;
      _hasError = false;
    });
  }

  void _onSuccess() {
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 28),
            const SizedBox(width: 8),
            Text('PIN Berhasil Diubah',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.warnaTeksUtama)),
          ],
        ),
        content: Text(
          'PIN Anda telah berhasil diperbarui. Gunakan PIN baru saat masuk ke aplikasi.',
          style: TextStyle(fontSize: 14, color: dialogContext.warnaTeksMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // tutup dialog
              Navigator.pop(context); // kembali ke profil
            },
            child: Text('OK',
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _pins[_step];
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.warnaTeksUtama,
          onPressed: () {
            if (_step > 0) {
              setState(() {
                _step--;
                _pins[_step] = '';
                _hasError = false;
              });
            } else {
              Navigator.pop(context);
            }
          },
          tooltip: 'Kembali',
        ),
        title: Text(
          'Ganti PIN',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
            color: context.warnaTeksMuted,
            onPressed: () => setState(() => _obscure = !_obscure),
            tooltip: _obscure ? 'Tampilkan PIN' : 'Sembunyikan PIN',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progres ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i <= _step ? scheme.primary : context.warnaGaris,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40),

          // ── Label ─────────────────────────────────────────────────
          Text(
            _stepLabels[_step],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.warnaTeksUtama,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _stepSubs[_step],
            style: TextStyle(fontSize: 14, color: context.warnaTeksMuted),
          ),

          if (_hasError) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.latarKeluar,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.warnaKeluar.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: context.warnaKeluar),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.warnaKeluar,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Indikator dot PIN ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) {
              final filled = i < currentPin.length;
              final char = (filled && !_obscure) ? currentPin[i] : null;
              return Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? scheme.primary : context.warnaKartu,
                  border: Border.all(
                    color: _hasError
                        ? context.warnaKeluar
                        : (filled ? scheme.primary : context.warnaGaris),
                    width: filled ? 0 : 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: char != null
                    ? Text(
                        char,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimary,
                        ),
                      )
                    : (filled
                        ? Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.onPrimary,
                            ),
                          )
                        : null),
              );
            }),
          ),

          const Spacer(),

          // ── Loading indicator saat verifikasi / simpan DB ─────────
          if (_isChecking)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: scheme.primary),
            ),

          // ── Numpad ─────────────────────────────────────────────────
          _buildNumpad(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildNumpad() {
    final bool nonaktif = _isChecking || _sisaKunci > 0;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'DEL'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: keys.length,
        itemBuilder: (_, i) {
          final key = keys[i];
          if (key.isEmpty) return const SizedBox();
          if (key == 'DEL') {
            return InkWell(
              onTap: nonaktif ? null : _onDelete,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: context.warnaKartu,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: nonaktif ? context.warnaTeksMuted : context.warnaTeksUtama,
                ),
              ),
            );
          }
          return InkWell(
            onTap: nonaktif ? null : () => _onKeyTap(key),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                color: context.warnaKartu,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                key,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: nonaktif ? context.warnaTeksMuted : context.warnaTeksUtama,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
