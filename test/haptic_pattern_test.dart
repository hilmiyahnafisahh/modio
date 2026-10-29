// Tes pola getaran berhasil/gagal (feedback dosen poin 2–3).
//
// HapticFeedback dikirim lewat SystemChannels.platform, jadi panggilan
// dicegat di sini dan dihitung — tes ini memastikan polanya dibedakan
// dari JUMLAH getaran dan sakelar Getaran di pengaturan dihormati.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:modio/core/services/aksesibilitas_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final AksesibilitasController ak = AksesibilitasController.instance;
  final List<String> getaran = [];

  setUp(() {
    getaran.clear();
    ak.getaran.value = true;
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

  test('berhasil = 1 getaran pendek', () {
    ak.getarBerhasil();
    expect(getaran, hasLength(1));
  });

  test('gagal = 2 getaran pendek, berbeda dari berhasil', () async {
    await ak.getarGagal();
    expect(getaran, hasLength(2));
  });

  test('ketukan tombol = getaran ringan, berbeda dari berhasil', () {
    ak.getar();
    ak.getarBerhasil();
    expect(getaran, hasLength(2));
    expect(getaran[0], isNot(getaran[1]));
  });

  test('sakelar Getaran mati → tidak ada getaran sama sekali', () async {
    ak.getaran.value = false;
    ak.getar();
    ak.getarBerhasil();
    await ak.getarGagal();
    expect(getaran, isEmpty);
  });
}
