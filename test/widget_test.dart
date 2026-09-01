// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:modio/main.dart';

void main() {
  testWidgets('Report and account tabs show the correct screens', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();

    expect(find.text('Laporan Keuangan'), findsOneWidget);
    expect(find.text('Profil Saya'), findsNothing);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    expect(find.text('Profil Saya'), findsOneWidget);
    expect(find.text('Laporan Keuangan'), findsNothing);
  });
}
