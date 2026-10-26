import 'package:flutter_test/flutter_test.dart';

import 'package:modio/features/profile/data/validasi_profil.dart';

void main() {
  test('isian wajib', () {
    expect(validasiWajib(''), 'wajib diisi');
    expect(validasiWajib('Warung Bu Siti'), isNull);
  });

  test('email', () {
    expect(validasiEmail(''), 'wajib diisi');
    expect(validasiEmail('siti@gmail.com'), isNull);
    expect(validasiEmail('siti.usaha@yahoo.co.id'), isNull);
    expect(validasiEmail('siti@gmail'), isNotNull);
    expect(validasiEmail('siti gmail.com'), isNotNull);
  });

  test('nomor HP Indonesia', () {
    expect(validasiNoHp(''), 'wajib diisi');
    expect(validasiNoHp('081234567890'), isNull);
    expect(validasiNoHp('0812 3456 7890'), isNull);
    expect(validasiNoHp('+62 812-3456-7890'), isNull);
    expect(validasiNoHp('6281234567890'), isNull);
    expect(validasiNoHp('12345'), isNotNull);
    expect(validasiNoHp('0212345678'), isNotNull); // telepon rumah, bukan HP
  });
}
