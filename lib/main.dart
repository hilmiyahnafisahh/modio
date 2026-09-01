import 'package:flutter/material.dart';

import 'core/services/aksesibilitas_controller.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/pages/pin_lock_page.dart';
import 'main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dimuat sebelum aplikasi tampil, agar tidak berkedip dari terang
  // ke gelap saat pertama dibuka.
  await ThemeController.instance.muat();
  await AksesibilitasController.instance.muat();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _terbuka = false;

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder membangun ulang MaterialApp setiap kali
    // nilai mode berubah, dari mana pun perubahan itu berasal (di
    // sini, dari sakelar di halaman Profil yang jauh di bawah pohon
    // widget ini).
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        // Dua ValueListenableBuilder bersarang tambahan: Kontras Tinggi
        // dan Teks Tebal tidak mengubah nilai warna/berat lewat parameter
        // builder ini (theme_extensions.dart dan AppTypography membaca
        // langsung dari AksesibilitasController), widget ini murni
        // memaksa seluruh MaterialApp dibangun ulang saat nilainya
        // berubah — sama seperti alasan ThemeMode dibungkus di sini.
        return ValueListenableBuilder<bool>(
          valueListenable: AksesibilitasController.instance.kontrasTinggi,
          builder: (context, _, _) {
            return ValueListenableBuilder<bool>(
              valueListenable: AksesibilitasController.instance.teksTebal,
              builder: (context, _, _) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  title: 'Modio',
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: mode,
                  home: _terbuka
                      ? const MainPage()
                      : PinLockPage(
                          onBerhasil: () => setState(() => _terbuka = true),
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