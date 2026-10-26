import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:modio/core/database/database_helper.dart';
import 'package:modio/features/reports/data/ai_analysis_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.tutup();
    await deleteDatabase(p.join(await getDatabasesPath(), 'modio.db'));
  });
  tearDown(() => DatabaseHelper.instance.tutup());

  test('analisis tersimpan per bulan & diperbarui dengan menimpa', () async {
    final simpan = AnalisisAiTersimpan();
    expect(await simpan.baca(2026, 10), isNull);

    final pertama = AnalisisAi(
      judul: 'Bulan Oktober Menguntungkan',
      saran: ['Pertahankan penjualan.', 'Kendalikan biaya bahan baku.'],
      nada: 'positif',
      dibuatPada: DateTime.utc(2026, 10, 20, 8),
    );
    await simpan.simpan(2026, 10, pertama);

    final dibaca = (await simpan.baca(2026, 10))!;
    expect(dibaca.judul, pertama.judul);
    expect(dibaca.saran, pertama.saran);
    expect(dibaca.nada, 'positif');
    expect(dibaca.dibuatPada, DateTime.utc(2026, 10, 20, 8));
    expect(await simpan.baca(2026, 11), isNull); // bulan lain terpisah

    await simpan.simpan(
      2026,
      10,
      AnalisisAi(judul: 'Biaya naik', saran: ['Kurangi ongkir.'], nada: 'negatif'),
    );
    final terbaru = (await simpan.baca(2026, 10))!;
    expect(terbaru.judul, 'Biaya naik'); // yang lama tertimpa, tanpa riwayat
    expect(terbaru.saran, ['Kurangi ongkir.']);
  });
}
