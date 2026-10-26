import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:modio/core/database/database_helper.dart';
import 'package:modio/features/onboarding/presentation/pages/registrasi_profil_page.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    await DatabaseHelper.instance.tutup();
    await deleteDatabase(p.join(await getDatabasesPath(), 'modio.db'));
  });
  tearDown(() => DatabaseHelper.instance.tutup());

  Future<void> tunggu(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }

  Future<void> isi(WidgetTester tester, String label, String nilai) =>
      tester.enterText(find.widgetWithText(TextField, label), nilai);

  testWidgets('tidak bisa lanjut sebelum semua kolom wajib benar', (tester) async {
    var lanjut = false;
    await tester.pumpWidget(MaterialApp(home: RegistrasiProfilPage(onLanjut: () => lanjut = true)));
    await tunggu(tester);

    // Hanya nama yang diisi, email salah format.
    await isi(tester, 'Nama Lengkap (wajib)', 'Siti Rahma');
    await isi(tester, 'Email (wajib)', 'siti@gmail');
    await tester.tap(find.text('Lanjut'));
    await tunggu(tester);
    await tester.pump(const Duration(milliseconds: 300)); // Selesaikan jeda pola getar gagal

    expect(lanjut, isFalse);
    expect(find.textContaining('Email belum benar'), findsOneWidget);
    expect(find.text('Nomor HP wajib diisi'), findsOneWidget);
    expect(find.text('Nama Usaha wajib diisi'), findsOneWidget);
    expect(find.text('Jenis Usaha wajib diisi'), findsOneWidget);
    expect(find.text('Alamat wajib diisi'), findsNothing); // alamat boleh kosong
    await tester.pumpWidget(const SizedBox()); // Lepas halaman (hentikan timer kursor)
  });

  testWidgets('semua benar (alamat kosong) → lanjut ke langkah 2', (tester) async {
    var lanjut = false;
    await tester.pumpWidget(MaterialApp(home: RegistrasiProfilPage(onLanjut: () => lanjut = true)));
    await tunggu(tester);

    await isi(tester, 'Nama Lengkap (wajib)', 'Siti Rahma');
    await isi(tester, 'Email (wajib)', 'siti@gmail.com');
    await isi(tester, 'Nomor HP (wajib)', '0812 3456 7890');
    await isi(tester, 'Nama Usaha (wajib)', 'Warung Bu Siti');
    await isi(tester, 'Jenis Usaha (wajib)', 'Makanan');
    await tester.tap(find.text('Lanjut'));
    await tunggu(tester);
    await tunggu(tester);

    expect(lanjut, isTrue);
  });
}
