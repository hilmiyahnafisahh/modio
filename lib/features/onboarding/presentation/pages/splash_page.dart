import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import 'package:flutter/semantics.dart'; // Untuk SemanticsService (pengumuman ke pembaca layar)

import '../../../../core/services/aksesibilitas_controller.dart'; // Sakelar Kurangi Animasi
import '../../../../core/theme/theme_extensions.dart'; // Warna sesuai tema
import '../../../auth/data/auth_repository.dart'; // Cek apakah pengguna sudah terdaftar (PIN ada)

/// ─────────────────────────────────────────────────────────────────
/// SPLASH PAGE  –  Layar pembuka: logo beranimasi + indikator memuat
///
/// Tampil setiap aplikasi dibuka. Sambil animasi berjalan, halaman ini
/// memeriksa apakah PIN sudah pernah dibuat, lalu memanggil
/// [onSelesai] dengan hasilnya:
///   • false → pengguna baru, lanjut ke registrasi
///   • true  → pengguna lama, lanjut ke layar masuk
///
/// Sakelar "Kurangi Animasi" dihormati: logo langsung tampil tanpa
/// gerakan dan layar ini hanya sebentar.
/// ─────────────────────────────────────────────────────────────────
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.onSelesai});

  final ValueChanged<bool> onSelesai; // Dipanggil sekali: true bila PIN sudah ada

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final bool _tanpaAnimasi = AksesibilitasController.instance.kurangiAnimasi.value;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _tanpaAnimasi ? 0 : 900),
  );
  late final Animation<double> _skala = Tween<double>(begin: 0.6, end: 1)
      .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutBack)); // Logo "muncul" sedikit memantul
  late final Animation<double> _pudar =
      CurvedAnimation(parent: _anim, curve: const Interval(0, 0.6, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _anim.forward();
    _mulai();
  }

  Future<void> _mulai() async {
    // Tampil minimal sejenak supaya logo sempat terlihat dan pengumuman
    // sempat dibacakan, walau pengecekan basis data jauh lebih cepat.
    final Future<void> jedaMinimal =
        Future<void>.delayed(Duration(milliseconds: _tanpaAnimasi ? 500 : 1600));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(View.of(context), 'Modio. Memuat aplikasi.', Directionality.of(context));
    });

    bool sudahTerdaftar = false;
    try {
      sudahTerdaftar = await AuthRepository.instance.sudahAdaPin();
    } catch (_) {
      sudahTerdaftar = false; // Gagal membaca: perlakukan sebagai baru, PinLockPage akan memeriksa ulang
    }
    await jedaMinimal;
    if (mounted) widget.onSelesai(sudahTerdaftar);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Semantics(
        label: 'Modio. Memuat aplikasi.', // Satu kalimat utuh untuk pembaca layar
        excludeSemantics: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _pudar,
                child: ScaleTransition(
                  scale: _skala,
                  child: Image.asset('assets/logo/logo.png', width: 120, height: 120),
                ),
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: _pudar,
                child: Text(
                  'Modio',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: context.warnaTeksUtama,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Keuangan UMKM yang mudah dan aksesibel',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: context.warnaTeksMuted),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: scheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
