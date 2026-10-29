// Tes halaman mengikuti mode tampilan yang dipilih pengguna.
//
// Halaman Pilih Kategori sebelumnya memakai warna tetap (latar putih,
// teks hitam), sehingga tetap putih walaupun Mode gelap aktif.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modio/core/theme/app_colors.dart';
import 'package:modio/core/theme/app_theme.dart';
import 'package:modio/features/transactions/data/transaction_model.dart';
import 'package:modio/features/transactions/presentation/pages/category_picker_page.dart';

Future<void> _pasang(WidgetTester tester, ThemeMode mode) async {
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: mode,
    home: const CategoryPickerPage(type: TransactionType.masuk),
  ));
  // Basis data tidak tersedia di lingkungan tes; FutureBuilder menangkap
  // galatnya dan halaman tetap menampilkan baris "Tambah kategori baru".
  await tester.pumpAndSettle();
}

Color _warnaTeks(WidgetTester tester, String teks) =>
    tester.widget<Text>(find.text(teks)).style!.color!;

void main() {
  testWidgets('Pilih Kategori gelap saat Mode gelap aktif', (tester) async {
    await _pasang(tester, ThemeMode.dark);

    final Scaffold scaffold = tester.widget(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.darkBg);
    expect(_warnaTeks(tester, 'Pilih Kategori'), AppColors.darkText);
  });

  testWidgets('Pilih Kategori terang saat Mode terang aktif', (tester) async {
    await _pasang(tester, ThemeMode.light);

    final Scaffold scaffold = tester.widget(find.byType(Scaffold));
    expect(scaffold.backgroundColor, AppColors.bgPage);
    expect(_warnaTeks(tester, 'Pilih Kategori'), AppColors.baseDark);
  });

  testWidgets('Dialog Kategori Baru gelap saat Mode gelap aktif', (tester) async {
    await _pasang(tester, ThemeMode.dark);
    await tester.tap(find.text('Tambah kategori baru'));
    await tester.pumpAndSettle();

    final Material permukaan = tester.widget(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Material),
    ).first);
    expect(permukaan.color, isNot(AppColors.white));
    expect(permukaan.color!.computeLuminance(), lessThan(0.1)); // latar gelap
    expect(_warnaTeks(tester, 'Kategori Baru'), AppColors.darkText);
  });
}
