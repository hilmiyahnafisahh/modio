import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:modio/core/database/database_helper.dart';
import 'package:modio/features/reports/data/ai_analysis_service.dart';
import 'package:modio/features/reports/data/report_model.dart';
import 'package:modio/features/reports/presentation/widgets/ai_analysis_card.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.tutup();
    await deleteDatabase(p.join(await getDatabasesPath(), 'modio.db'));
  });
  tearDown(() => DatabaseHelper.instance.tutup());

  const laporan = LaporanBulanan(tahun: 2026, bulan: 10, jumlahTransaksi: 3, rincian: []);

  Future<void> pasang(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: AnalisisAiCard(laporan: laporan))),
    ));
    // Pembacaan SQLite berjalan di luar fake-async bawaan widget test.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }

  testWidgets('belum ada analisis: tampil ajakan & tombol Buat analisis', (tester) async {
    await pasang(tester);
    expect(find.text('Analisis AI'), findsOneWidget);
    expect(find.textContaining('Belum ada analisis untuk Oktober 2026'), findsOneWidget);
    expect(find.text('Buat analisis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('analisis tersimpan langsung tampil di card, lengkap dengan teksnya', (tester) async {
    await tester.runAsync(() => AnalisisAiTersimpan().simpan(
          2026,
          10,
          AnalisisAi(
            judul: 'Bulan Oktober Menguntungkan',
            saran: ['Pertahankan penjualan.', 'Kendalikan biaya bahan baku.'],
            nada: 'positif',
          ),
        ));
    await pasang(tester);

    expect(find.text('Bulan Oktober Menguntungkan'), findsOneWidget);
    expect(find.text('Pertahankan penjualan.'), findsOneWidget);
    expect(find.text('Kendalikan biaya bahan baku.'), findsOneWidget);
    expect(find.text('Perbarui analisis'), findsOneWidget);
    expect(tester.takeException(), isNull); // tidak ada galat saat menggambar card

    await tester.tap(find.text('Perbarui analisis'));
    await tester.pumpAndSettle();
    expect(find.text('Perbarui analisis?'), findsOneWidget);
    expect(find.textContaining('Analisis sebelumnya akan diganti dan tidak disimpan'), findsOneWidget);
  });
}
