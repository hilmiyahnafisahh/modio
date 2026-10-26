// Tes alur registrasi awal: splash, penanda langkah, dan validasi profil.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modio/core/services/aksesibilitas_controller.dart';
import 'package:modio/core/theme/app_theme.dart';
import 'package:modio/features/onboarding/presentation/pages/registrasi_profil_page.dart';
import 'package:modio/features/onboarding/presentation/pages/splash_page.dart';
import 'package:modio/features/onboarding/presentation/widgets/penanda_langkah.dart';

Widget _app(Widget home) => MaterialApp(theme: AppTheme.lightTheme, home: home);

void main() {
  setUp(() => AksesibilitasController.instance.kurangiAnimasi.value = false);

  testWidgets('Splash menampilkan logo lalu selesai sesudah jeda', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    bool? hasil;
    await tester.pumpWidget(_app(SplashPage(onSelesai: (v) => hasil = v)));

    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Modio. Memuat aplikasi.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(hasil, isNull); // Masih dalam jeda minimal, belum pindah layar
    await tester.pump(const Duration(milliseconds: 700));
    // Basis data tidak tersedia di tes: dianggap pengguna baru.
    expect(hasil, isFalse);
    handle.dispose();
  });

  testWidgets('Splash lebih singkat saat Kurangi Animasi aktif', (tester) async {
    AksesibilitasController.instance.kurangiAnimasi.value = true;
    bool? hasil;
    await tester.pumpWidget(_app(SplashPage(onSelesai: (v) => hasil = v)));
    await tester.pump(const Duration(milliseconds: 600));
    expect(hasil, isFalse);
  });

  testWidgets('Penanda langkah dibacakan sebagai satu kalimat', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const Scaffold(body: PenandaLangkah(langkah: 2))));
    expect(find.bySemanticsLabel('Langkah 2 dari 3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Profil: Lanjut ditolak bila Nama Lengkap kosong', (tester) async {
    bool lanjut = false;
    await tester.pumpWidget(_app(RegistrasiProfilPage(onLanjut: () => lanjut = true)));
    await tester.pump();

    expect(find.text('Nama Lengkap (wajib)'), findsOneWidget); // Label kolom dibacakan TalkBack
    await tester.tap(find.text('Lanjut'));
    await tester.pump(const Duration(milliseconds: 300)); // Selesaikan jeda pola getar gagal

    expect(find.text('Nama Lengkap wajib diisi'), findsOneWidget);
    expect(lanjut, isFalse);
  });
}
