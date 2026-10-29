// Tes aksesibilitas otomatis (WCAG).
//
// Bagian pertama memeriksa rasio kontras palet AppColors dengan rumus
// relative luminance WCAG, supaya klaim di komentar app_colors.dart
// tidak bisa diam-diam salah lagi saat warna diganti. Bagian kedua
// memakai guideline bawaan flutter_test untuk label dan ukuran target
// sentuh pada widget yang sebelumnya bermasalah.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modio/core/theme/app_colors.dart';
import 'package:modio/core/theme/app_theme.dart';
import 'package:modio/core/widgets/month_picker_dialog.dart';
import 'package:modio/features/ai_chat/presentation/widgets/chat_bubble.dart';
import 'package:modio/features/ai_chat/presentation/widgets/voice_input_bar.dart';
import 'package:modio/features/dashboard/presentation/widgets/balance_card.dart';
import 'package:modio/features/dashboard/presentation/widgets/summary_grid.dart';
import 'package:modio/features/transactions/data/transaction_model.dart';
import 'package:modio/features/transactions/presentation/widgets/transaction_tile.dart';

double _rasioKontras(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Pasangan warna teks/latar yang benar-benar dipakai di aplikasi.
const Map<String, (Color, Color)> _pasanganTeks = {
  'primary700 / putih': (AppColors.primary700, AppColors.white),
  'secondary700 / putih': (AppColors.secondary700, AppColors.white),
  'tertiary700 / putih': (AppColors.tertiary700, AppColors.white),
  'tertiary700 / tertiary50': (AppColors.tertiary700, AppColors.tertiary50),
  'primary700 / primary50': (AppColors.primary700, AppColors.primary50),
  'amber700 / amber50': (AppColors.amber700, AppColors.amber50),
  'textMuted / putih': (AppColors.textMuted, AppColors.white),
  'textMuted / inputFill': (AppColors.textMuted, AppColors.inputFill),
  'textMuted / tertiary50': (AppColors.textMuted, AppColors.tertiary50),
  'baseDark / putih': (AppColors.baseDark, AppColors.white),
  'darkText / darkBg': (AppColors.darkText, AppColors.darkBg),
  'darkTextMuted / darkSurfaceHi':
      (AppColors.darkTextMuted, AppColors.darkSurfaceHi),
  'darkPrimary / darkSurfaceHi': (AppColors.darkPrimary, AppColors.darkSurfaceHi),
  'darkExpense / darkSurface': (AppColors.darkExpense, AppColors.darkSurface),
  'darkInfo / darkBg': (AppColors.darkInfo, AppColors.darkBg),
  'darkAmber / darkAmberBg': (AppColors.darkAmber, AppColors.darkAmberBg),
};

/// Batas kontrol dan ikon penting (WCAG 1.4.11, minimum 3:1).
const Map<String, (Color, Color)> _pasanganNonTeks = {
  'inputBorder / putih': (AppColors.inputBorder, AppColors.white),
  'inputBorder / inputFill': (AppColors.inputBorder, AppColors.inputFill),
  'darkInputBorder / darkBg': (AppColors.darkInputBorder, AppColors.darkBg),
  'darkInputBorder / darkSurface': (AppColors.darkInputBorder, AppColors.darkSurface),
  'darkInputBorder / darkSurfaceHi':
      (AppColors.darkInputBorder, AppColors.darkSurfaceHi),
  'ikon putih / tombol Catat (primary700)': (AppColors.white, AppColors.primary700),
  'ikon gelap / tombol Catat mode gelap': (AppColors.darkBg, AppColors.darkPrimary),
};

Widget _bungkus(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

void main() {
  group('Kontras teks (WCAG 1.4.6, AAA ≥ 7:1)', () {
    for (final MapEntry<String, (Color, Color)> e in _pasanganTeks.entries) {
      test(e.key, () {
        final double rasio = _rasioKontras(e.value.$1, e.value.$2);
        expect(rasio, greaterThanOrEqualTo(7.0),
            reason: '${e.key} hanya ${rasio.toStringAsFixed(2)}:1');
      });
    }
  });

  group('Kontras non-teks (WCAG 1.4.11, ≥ 3:1)', () {
    for (final MapEntry<String, (Color, Color)> e in _pasanganNonTeks.entries) {
      test(e.key, () {
        final double rasio = _rasioKontras(e.value.$1, e.value.$2);
        expect(rasio, greaterThanOrEqualTo(3.0),
            reason: '${e.key} hanya ${rasio.toStringAsFixed(2)}:1');
      });
    }
  });

  // Pengguna low vision sering memakai ukuran font sistem terbesar.
  // WCAG 1.4.4: teks harus bisa diperbesar 200% tanpa terpotong atau
  // tumpang tindih. Overflow di Flutter dilaporkan sebagai exception,
  // jadi tes ini gagal bila ada yang meluber.
  group('Teks diperbesar 200% (WCAG 1.4.4)', () {
    Future<void> pasang(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3); // HP kecil, 360×800 dp
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: 2,
          maxScaleFactor: 2,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ));
    }

    testWidgets('kartu saldo', (WidgetTester tester) async {
      await pasang(tester,
          const BalanceCard(balance: 125000000, period: 'Oktober 2026'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('ringkasan hari ini', (WidgetTester tester) async {
      await pasang(tester, const SummaryGrid(
          income: 12500000, expense: 8750000, profit: -250000, transactionCount: 124));
      expect(tester.takeException(), isNull);
    });

    testWidgets('baris transaksi', (WidgetTester tester) async {
      await pasang(tester, TransactionTile(
        item: TransactionItem(
          id: '01',
          title: 'Penjualan kopi susu gula aren dua puluh gelas',
          nominal: 1500000,
          method: 'non tunai',
          kategori: 'Penjualan',
          type: TransactionType.masuk,
          occurredAt: DateTime(2026, 10, 18, 9, 30),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bar input Asisten AI', (WidgetTester tester) async {
      final TextEditingController ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await pasang(tester,
          VoiceInputBar(controller: ctrl, onSend: (_) {}, onVoice: () {}));
      expect(tester.takeException(), isNull);
    });
  });

  group('Bar input Asisten AI', () {
    for (final (String nama, ThemeData tema) in [
      ('terang', AppTheme.lightTheme),
      ('gelap', AppTheme.darkTheme),
    ]) {
      testWidgets('tombol berlabel dan target sentuh cukup ($nama)',
          (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final TextEditingController ctrl = TextEditingController();
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(_bungkus(
          Align(
            alignment: Alignment.bottomCenter,
            child: VoiceInputBar(controller: ctrl, onSend: (_) {}, onVoice: () {}),
          ),
          theme: tema,
        ));

        expect(find.bySemanticsLabel('Tanya dengan suara'), findsOneWidget);
        expect(find.bySemanticsLabel('Kirim pertanyaan'), findsOneWidget);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
    }
  });

  testWidgets('Gelembung chat menyebut pengirimnya', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_bungkus(const Column(children: [
      ChatBubble(message: ChatMessage(text: 'Halo', isUser: false)),
      ChatBubble(message: ChatMessage(text: 'Untung bulan ini?', isUser: true)),
    ])));

    expect(find.bySemanticsLabel('Asisten AI: Halo'), findsOneWidget);
    expect(find.bySemanticsLabel('Anda: Untung bulan ini?'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Dialog pilih bulan: berlabel dan target sentuh cukup', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3); // HP kecil, 360×800 dp
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(_bungkus(MonthPickerDialog(initialDate: DateTime(2025, 3))));
    await tester.pump();
    expect(find.bySemanticsLabel('Maret, dipilih'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
