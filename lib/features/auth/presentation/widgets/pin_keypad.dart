import 'package:flutter/material.dart'; // Widget dasar Flutter

import '../../../../core/services/aksesibilitas_controller.dart'; // Pengaturan aksesibilitas (getar, teks tebal, dll)
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi warna tema kontekstual

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
  final int panjang; // Total digit PIN yang dibutuhkan
  final String nilai; // Digit yang sudah diketik sejauh ini
  final bool tampilkanAngka; // Apakah angka ditampilkan, bukan hanya titik
  final bool galat; // Apakah sedang menunjukkan status PIN salah

  const PinDots({
    super.key,
    required this.nilai,
    this.panjang = 6, // Default PIN 6 digit
    this.tampilkanAngka = false, // Default: sembunyikan angka demi privasi
    this.galat = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics( // Info tambahan untuk pembaca layar
      // Angka yang sudah diketik TIDAK ikut diucapkan, meski sedang
      // ditampilkan. Membacakan PIN dengan suara keras akan terdengar
      // orang di sekitar.
      label: nilai.isEmpty
          ? 'Belum ada digit dimasukkan. Butuh $panjang digit.'
          : '${nilai.length} dari $panjang digit dimasukkan', // Umumkan progres, bukan isi PIN
      liveRegion: true, // Beri tahu pembaca layar setiap kali label ini berubah
      excludeSemantics: true, // Cegah child menambah info semantik ganda
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // Titik-titik disusun rata tengah
        children: List.generate(panjang, (i) { // Buat satu widget dot untuk tiap digit yang dibutuhkan
          final bool terisi = i < nilai.length; // Apakah posisi ke-i ini sudah diisi
          final String? huruf =
              (terisi && tampilkanAngka) ? nilai[i] : null; // Angka ditampilkan hanya bila diizinkan
          final scheme = Theme.of(context).colorScheme; // Skema warna tema aktif
          // Dot terisi butuh warna solid yang kontras dengan latarnya
          // sendiri, bukan cuma dengan latar halaman — onPrimary sudah
          // dirancang untuk pasangan ini di kedua tema (putih di atas
          // hijau tua mode terang, gelap di atas hijau terang mode
          // gelap).
          final Color isiWarna = scheme.primary; // Warna latar dot yang terisi
          final Color isiTeks = scheme.onPrimary; // Warna isi (angka/titik kecil) di atas dot terisi

          return Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 6), // Jarak antar dot
            decoration: BoxDecoration(
              shape: BoxShape.circle, // Dot berbentuk lingkaran
              color: terisi ? isiWarna : context.warnaKartu, // Warna berbeda tergantung terisi atau tidak
              border: Border.all(
                color: galat
                    ? context.warnaKeluar // Merah/warna galat saat PIN salah
                    : (terisi ? scheme.primary : context.warnaGaris),
                width: galat ? 2.5 : (terisi ? 2 : 1.5), // Garis lebih tebal saat galat
              ),
            ),
            alignment: Alignment.center,
            child: huruf != null
                ? Text( // Tampilkan angka bila mode tampilkanAngka aktif
                    huruf,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isiTeks,
                    ),
                  )
                : (terisi
                    ? Container( // Titik kecil solid sebagai penanda terisi tanpa angka
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isiTeks,
                        ),
                      )
                    : null), // Kosong bila belum terisi
          );
        }),
      ),
    );
  }
}

/// Papan angka untuk memasukkan PIN
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onAngka; // Dipanggil dengan digit yang ditekan
  final VoidCallback onHapus; // Dipanggil saat tombol hapus ditekan
  final bool nonaktif; // Bila true, semua tombol tidak bisa ditekan

  const PinKeypad({
    super.key,
    required this.onAngka,
    required this.onHapus,
    this.nonaktif = false,
  });

  static const List<String> _tombol = [ // Susunan label tombol, baris demi baris
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '', '0', 'HAPUS', // String kosong = slot kosong tanpa tombol
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          for (int baris = 0; baris < 4; baris++) ...[ // Bangun 4 baris tombol
            Row(
              children: [
                for (int kolom = 0; kolom < 3; kolom++) ...[ // Tiap baris berisi 3 kolom
                  Expanded(
                    child: _tombol[baris * 3 + kolom].isEmpty // Hitung indeks tombol dari baris & kolom
                        ? const SizedBox(height: 64) // Slot kosong tetap mengambil ruang, tanpa tombol
                        : _TombolAngka(
                            teks: _tombol[baris * 3 + kolom],
                            nonaktif: nonaktif,
                            onTekan: () {
                              final String t = _tombol[baris * 3 + kolom]; // Label tombol yang ditekan
                              // Getaran ringan sebagai penanda tekanan
                              // terbaca. Tanpa ini, pengguna yang tidak
                              // melihat layar tidak punya kepastian
                              // apakah jarinya mengenai tombol. Tunduk
                              // pada sakelar Getaran di Pengaturan
                              // Aksesibilitas, bukan selalu menyala.
                              AksesibilitasController.instance.getar(); // Getarkan perangkat sebagai umpan balik
                              if (t == 'HAPUS') {
                                onHapus(); // Panggil callback hapus digit terakhir
                              } else {
                                onAngka(t); // Panggil callback dengan digit yang ditekan
                              }
                            },
                          ),
                  ),
                  if (kolom < 2) const SizedBox(width: 10), // Jarak antar tombol, kecuali kolom terakhir
                ],
              ],
            ),
            if (baris < 3) const SizedBox(height: 10), // Jarak antar baris, kecuali baris terakhir
          ],
        ],
      ),
    );
  }
}

class _TombolAngka extends StatelessWidget { // Satu tombol angka/hapus pada keypad
  const _TombolAngka({
    required this.teks,
    required this.onTekan,
    required this.nonaktif,
  });

  final String teks; // Label tombol: angka atau "HAPUS"
  final VoidCallback onTekan; // Aksi saat tombol ditekan
  final bool nonaktif; // Bila true, tombol tidak merespons

  @override
  Widget build(BuildContext context) {
    final bool isHapus = teks == 'HAPUS'; // Cek apakah ini tombol hapus, bukan angka

    return Semantics(
      button: true, // Umumkan sebagai tombol ke pembaca layar
      enabled: !nonaktif, // Status aktif/nonaktif untuk pembaca layar
      label: isHapus ? 'Hapus satu digit' : 'Angka $teks',
      // Tanpa onTap di simpul semantik ini, keypad PIN — satu-satunya
      // jalan masuk ke aplikasi — tidak bisa diaktifkan dengan ketuk
      // dua kali TalkBack, meski terbaca sebagai tombol.
      onTap: nonaktif ? null : onTekan, // Nonaktifkan aksi bila tombol dinonaktifkan
      excludeSemantics: true,
      child: InkWell( // Efek riak visual saat disentuh
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
              ? Icon( // Ikon hapus untuk tombol HAPUS
                  Icons.backspace_outlined,
                  size: 24,
                  color: context.warnaTeksUtama,
                )
              : Text( // Angka untuk tombol biasa
                  teks,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: nonaktif
                        ? context.warnaTeksMuted // Warna pudar saat nonaktif
                        : context.warnaTeksUtama,
                  ),
                ),
        ),
      ),
    );
  }
}
