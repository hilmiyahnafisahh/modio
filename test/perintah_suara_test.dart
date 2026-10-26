import 'package:flutter_test/flutter_test.dart';

import 'package:modio/core/navigation/main_nav_controller.dart';

void main() {
  test('perintah tutup aplikasi dikenali', () {
    for (final ucapan in [
      'tutup aplikasi',
      'Tutup Aplikasi',
      'keluar aplikasi',
      'keluar dari aplikasi',
      'tolong tutup aplikasinya',
      'tutup modio',
      'keluar dari Modio',
    ]) {
      expect(perintahTutupAplikasi(ucapan), isTrue, reason: ucapan);
    }
  });

  test('ucapan transaksi tidak dianggap perintah keluar', () {
    for (final ucapan in [
      'keluar uang lima ribu buat parkir',
      'uang keluar dua puluh ribu',
      'tutup warung lebih awal beli es lima ribu',
      'bayar langganan aplikasi kasir lima puluh ribu',
      'keluar uang buat langganan aplikasi kasir',
      'tutup toko, bayar aplikasi ojek',
    ]) {
      expect(perintahTutupAplikasi(ucapan), isFalse, reason: ucapan);
    }
  });

  test('analisis AI diarahkan ke Laporan', () {
    expect(deteksiPerintahNavigasi('analisis AI'), VoiceNavTarget.laporan);
    expect(deteksiPerintahNavigasi('chat AI'), VoiceNavTarget.aiChat);
  });
}
