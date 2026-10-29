import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import 'core/services/aksesibilitas_controller.dart'; // Pengelola pengaturan aksesibilitas
import 'core/services/keamanan_controller.dart'; // Pengelola pengaturan metode masuk (suara/biometrik)
import 'core/theme/app_theme.dart'; // Definisi tema terang/gelap aplikasi
import 'core/theme/theme_controller.dart'; // Pengelola mode tema aktif
import 'features/auth/presentation/pages/pin_lock_page.dart'; // Halaman kunci PIN saat aplikasi dibuka
import 'features/onboarding/presentation/pages/registrasi_profil_page.dart'; // Registrasi langkah 1: profil
import 'features/onboarding/presentation/pages/registrasi_tema_page.dart'; // Registrasi langkah 3: tema
import 'features/onboarding/presentation/pages/splash_page.dart'; // Layar pembuka dengan logo
import 'main_page.dart'; // Halaman utama aplikasi setelah berhasil masuk

void main() async { // Titik masuk aplikasi Flutter
  WidgetsFlutterBinding.ensureInitialized(); // Pastikan binding Flutter siap sebelum kode async lain berjalan
  // Dimuat sebelum aplikasi tampil, agar tidak berkedip dari terang
  // ke gelap saat pertama dibuka.
  await ThemeController.instance.muat(); // Muat pengaturan tema tersimpan sebelum UI tampil
  await AksesibilitasController.instance.muat(); // Muat pengaturan aksesibilitas tersimpan sebelum UI tampil
  await KeamananController.instance.muat(); // Muat pengaturan metode masuk tersimpan sebelum UI tampil
  runApp(const MyApp()); // Jalankan aplikasi dengan widget akar MyApp
}

class MyApp extends StatefulWidget { // Widget akar aplikasi, punya state (status sudah terbuka atau belum)
  const MyApp({super.key}); // Konstruktor, key diteruskan ke superclass

  @override
  State<MyApp> createState() => _MyAppState(); // Buat objek state untuk widget ini
}

/// Layar yang sedang tampil. Pengguna baru melewati alur registrasi:
///   splash → profil → keamanan (pilih cara masuk + buat PIN) → tema → utama
/// Pengguna lama:
///   splash → kunci (PIN/sidik jari) → utama, atau langsung utama bila
///   Kunci PIN dimatikan.
enum _Layar { splash, profil, keamanan, tema, kunci, utama }

class _MyAppState extends State<MyApp> { // Kelas state yang menyimpan data berubah-ubah
  _Layar _layar = _Layar.splash; // Selalu mulai dari layar pembuka

  void _ke(_Layar l) => setState(() => _layar = l); // Pindah ke layar berikutnya

  void _splashSelesai(bool sudahTerdaftar) {
    if (!sudahTerdaftar) return _ke(_Layar.profil); // Pengguna baru: mulai registrasi
    _ke(KeamananController.instance.pinAktif.value ? _Layar.kunci : _Layar.utama);
  }

  Widget _halaman() => switch (_layar) {
        _Layar.splash => SplashPage(onSelesai: _splashSelesai),
        _Layar.profil => RegistrasiProfilPage(onLanjut: () => _ke(_Layar.keamanan)),
        _Layar.keamanan => PinLockPage(pendaftaran: true, onBerhasil: () => _ke(_Layar.tema)),
        _Layar.tema => RegistrasiTemaPage(onSelesai: () => _ke(_Layar.utama)),
        _Layar.kunci => PinLockPage(onBerhasil: () => _ke(_Layar.utama)),
        _Layar.utama => const MainPage(),
      };

  @override
  Widget build(BuildContext context) { // Membangun tampilan aplikasi
    // ValueListenableBuilder membangun ulang MaterialApp setiap kali
    // nilai mode berubah, dari mana pun perubahan itu berasal (di
    // sini, dari sakelar di halaman Profil yang jauh di bawah pohon
    // widget ini).
    return ValueListenableBuilder<ThemeMode>( // Dengarkan perubahan mode tema dan bangun ulang saat berubah
      valueListenable: ThemeController.instance.mode, // Sumber nilai mode tema yang didengarkan
      builder: (context, mode, _) {
        // Dua ValueListenableBuilder bersarang tambahan: Kontras Tinggi
        // dan Teks Tebal tidak mengubah nilai warna/berat lewat parameter
        // builder ini (theme_extensions.dart dan AppTypography membaca
        // langsung dari AksesibilitasController), widget ini murni
        // memaksa seluruh MaterialApp dibangun ulang saat nilainya
        // berubah — sama seperti alasan ThemeMode dibungkus di sini.
        return ValueListenableBuilder<bool>( // Dengarkan perubahan pengaturan Kontras Tinggi
          valueListenable: AksesibilitasController.instance.kontrasTinggi,
          builder: (context, _, _) {
            return ValueListenableBuilder<bool>( // Dengarkan perubahan pengaturan Teks Tebal
              valueListenable: AksesibilitasController.instance.teksTebal,
              builder: (context, _, _) {
                return MaterialApp( // Widget akar aplikasi Material
                  debugShowCheckedModeBanner: false, // Sembunyikan pita "debug" di pojok layar
                  title: 'Modio', // Judul aplikasi
                  theme: AppTheme.lightTheme, // Tema untuk mode terang
                  darkTheme: AppTheme.darkTheme, // Tema untuk mode gelap
                  themeMode: mode, // Mode tema yang aktif saat ini
                  // KeyedSubtree: setiap layar dibangun baru saat berganti,
                  // supaya PinLockPage registrasi dan PinLockPage masuk
                  // tidak berbagi state.
                  home: KeyedSubtree(key: ValueKey(_layar), child: _halaman()),
                );
              },
            );
          },
        );
      },
    );
  }
}
