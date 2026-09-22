import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import 'core/services/aksesibilitas_controller.dart'; // Pengelola pengaturan aksesibilitas
import 'core/services/keamanan_controller.dart'; // Pengelola pengaturan metode masuk (suara/biometrik)
import 'core/theme/app_theme.dart'; // Definisi tema terang/gelap aplikasi
import 'core/theme/theme_controller.dart'; // Pengelola mode tema aktif
import 'features/auth/presentation/pages/pin_lock_page.dart'; // Halaman kunci PIN saat aplikasi dibuka
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

class _MyAppState extends State<MyApp> { // Kelas state yang menyimpan data berubah-ubah
  // KeamananController.instance.muat() sudah selesai di main() sebelum
  // runApp dipanggil, jadi nilai pinAktif di sini sudah nilai tersimpan
  // yang sebenarnya — bukan default sesaat. Kunci PIN nonaktif berarti
  // langsung anggap "terbuka" sejak awal, lewati layar kunci sama sekali.
  bool _terbuka = !KeamananController.instance.pinAktif.value; // Status apakah pengguna sudah berhasil melewati kunci PIN

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
                  home: _terbuka
                      ? const MainPage() // Tampilkan halaman utama jika sudah terbuka
                      : PinLockPage( // Tampilkan halaman kunci PIN jika belum terbuka
                          onBerhasil: () => setState(() => _terbuka = true), // Tandai terbuka setelah PIN benar
                        ),
                );
              },
            );
          },
        );
      },
    );
  }
}
