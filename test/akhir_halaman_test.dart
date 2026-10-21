// Tes penanda akhir halaman dan getaran saat halaman sampai dasar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modio/core/services/aksesibilitas_controller.dart';
import 'package:modio/core/theme/app_theme.dart';
import 'package:modio/core/widgets/akhir_halaman.dart';

void main() {
  final List<String> getaran = [];

  setUp(() {
    getaran.clear();
    AksesibilitasController.instance.getaran.value = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
      if (call.method == 'HapticFeedback.vibrate') getaran.add(call.arguments as String);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pasang(WidgetTester tester, {required int jumlahBaris}) {
    return tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: GetarAkhirGulir(
          child: ListView(children: [
            for (int i = 0; i < jumlahBaris; i++)
              SizedBox(height: 60, child: Text('Baris $i')),
            const PenandaAkhirHalaman(
                teks: 'Akhir riwayat', labelSemantik: 'Akhir riwayat. 3 transaksi.'),
          ]),
        ),
      ),
    ));
  }

  Future<void> keDasar(WidgetTester tester) async {
    await tester.fling(find.byType(ListView), const Offset(0, -5000), 5000);
    await tester.pumpAndSettle();
  }

  testWidgets('bergetar sekali saat sampai dasar, tidak berulang', (tester) async {
    await pasang(tester, jumlahBaris: 50);
    expect(getaran, isEmpty); // Belum sampai dasar

    await keDasar(tester);
    expect(getaran, hasLength(1));

    await keDasar(tester); // Mencoba menggulir lagi saat sudah di dasar
    expect(getaran, hasLength(1));
  });

  testWidgets('bergetar lagi setelah naik lalu kembali ke dasar', (tester) async {
    await pasang(tester, jumlahBaris: 50);
    await keDasar(tester);
    await tester.drag(find.byType(ListView), const Offset(0, 400)); // Naik ±400 dp
    await tester.pumpAndSettle();
    await keDasar(tester);
    expect(getaran, hasLength(2));
  });

  testWidgets('halaman yang muat satu layar tidak bergetar', (tester) async {
    await pasang(tester, jumlahBaris: 2);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(getaran, isEmpty);
  });

  testWidgets('sakelar Getaran mati dihormati', (tester) async {
    AksesibilitasController.instance.getaran.value = false;
    await pasang(tester, jumlahBaris: 50);
    await keDasar(tester);
    expect(getaran, isEmpty);
  });

  testWidgets('penanda akhir dibacakan dengan ringkasan', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pasang(tester, jumlahBaris: 2);
    expect(find.bySemanticsLabel('Akhir riwayat. 3 transaksi.'), findsOneWidget);
    handle.dispose();
  });
}
