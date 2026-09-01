import 'package:flutter/material.dart';

import '../../../../core/services/aksesibilitas_controller.dart';
import '../../../../core/theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// PIN KEYPAD  –  Papan angka dan indikator digit
///
/// Dipakai bersama oleh layar kunci dan layar ganti PIN. Satu
/// komponen untuk keduanya: kalau ada dua salinan, perbaikan pada
/// salah satunya mudah terlewat di yang lain.
///
/// Tiga hal yang membuat komponen ini dapat dipakai tanpa melihat:
///
///   1. Getaran setiap kali tombol ditekan. Ini satu-satunya umpan
///      balik langsung yang dirasakan pengguna bahwa tekanannya
///      terbaca sistem.
///   2. Jumlah digit yang sudah masuk diumumkan pembaca layar.
///      Titik-titik indikator murni visual dan tidak berarti apa pun
///      bagi pengguna tunanetra.
///   3. Setiap tombol ditandai sebagai tombol, bukan teks biasa.
/// ─────────────────────────────────────────────────────────────────

/// Indikator berapa digit PIN yang sudah dimasukkan
class PinDots extends StatelessWidget {
  final int panjang;
  final String nilai;
  final bool tampilkanAngka;
  final bool galat;

  const PinDots({
    super.key,
    required this.nilai,
    this.panjang = 6,
    this.tampilkanAngka = false,
    this.galat = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Angka yang sudah diketik TIDAK ikut diucapkan, meski sedang
      // ditampilkan. Membacakan PIN dengan suara keras akan terdengar
      // orang di sekitar.
      label: nilai.isEmpty
          ? 'Belum ada digit dimasukkan. Butuh $panjang digit.'
          : '${nilai.length} dari $panjang digit dimasukkan',
      liveRegion: true,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(panjang, (i) {
          final bool terisi = i < nilai.length;
          final String? huruf =
              (terisi && tampilkanAngka) ? nilai[i] : null;
          final scheme = Theme.of(context).colorScheme;
          // Dot terisi butuh warna solid yang kontras dengan latarnya
          // sendiri, bukan cuma dengan latar halaman — onPrimary sudah
          // dirancang untuk pasangan ini di kedua tema (putih di atas
          // hijau tua mode terang, gelap di atas hijau terang mode
          // gelap).
          final Color isiWarna = scheme.primary;
          final Color isiTeks = scheme.onPrimary;

          return Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: terisi ? isiWarna : context.warnaKartu,
              border: Border.all(
                color: galat
                    ? context.warnaKeluar
                    : (terisi ? scheme.primary : context.warnaGaris),
                width: galat ? 2.5 : (terisi ? 2 : 1.5),
              ),
            ),
            alignment: Alignment.center,
            child: huruf != null
                ? Text(
                    huruf,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isiTeks,
                    ),
                  )
                : (terisi
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isiTeks,
                        ),
                      )
                    : null),
          );
        }),
      ),
    );
  }
}

/// Papan angka untuk memasukkan PIN
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onAngka;
  final VoidCallback onHapus;
  final bool nonaktif;

  const PinKeypad({
    super.key,
    required this.onAngka,
    required this.onHapus,
    this.nonaktif = false,
  });

  static const List<String> _tombol = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', 'HAPUS',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          for (int baris = 0; baris < 4; baris++) ...[
            Row(
              children: [
                for (int kolom = 0; kolom < 3; kolom++) ...[
                  Expanded(
                    child: _tombol[baris * 3 + kolom].isEmpty
                        ? const SizedBox(height: 64)
                        : _TombolAngka(
                            teks: _tombol[baris * 3 + kolom],
                            nonaktif: nonaktif,
                            onTekan: () {
                              final String t = _tombol[baris * 3 + kolom];
                              // Getaran ringan sebagai penanda tekanan
                              // terbaca. Tanpa ini, pengguna yang tidak
                              // melihat layar tidak punya kepastian
                              // apakah jarinya mengenai tombol. Tunduk
                              // pada sakelar Getaran di Pengaturan
                              // Aksesibilitas, bukan selalu menyala.
                              AksesibilitasController.instance.getar();
                              if (t == 'HAPUS') {
                                onHapus();
                              } else {
                                onAngka(t);
                              }
                            },
                          ),
                  ),
                  if (kolom < 2) const SizedBox(width: 10),
                ],
              ],
            ),
            if (baris < 3) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _TombolAngka extends StatelessWidget {
  const _TombolAngka({
    required this.teks,
    required this.onTekan,
    required this.nonaktif,
  });

  final String teks;
  final VoidCallback onTekan;
  final bool nonaktif;

  @override
  Widget build(BuildContext context) {
    final bool isHapus = teks == 'HAPUS';

    return Semantics(
      button: true,
      enabled: !nonaktif,
      label: isHapus ? 'Hapus satu digit' : 'Angka $teks',
      // Tanpa onTap di simpul semantik ini, keypad PIN — satu-satunya
      // jalan masuk ke aplikasi — tidak bisa diaktifkan dengan ketuk
      // dua kali TalkBack, meski terbaca sebagai tombol.
      onTap: nonaktif ? null : onTekan,
      excludeSemantics: true,
      child: InkWell(
        onTap: nonaktif ? null : onTekan,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          // Tinggi 64: di atas ambang minimum, dan cukup lega untuk
          // ditemukan jari tanpa melihat layar.
          height: 64,
          decoration: BoxDecoration(
            color: context.warnaKartu,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.warnaGaris),
          ),
          alignment: Alignment.center,
          child: isHapus
              ? Icon(
                  Icons.backspace_outlined,
                  size: 24,
                  color: context.warnaTeksUtama,
                )
              : Text(
                  teks,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: nonaktif
                        ? context.warnaTeksMuted
                        : context.warnaTeksUtama,
                  ),
                ),
        ),
      ),
    );
  }
}
