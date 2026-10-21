import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import 'package:flutter/semantics.dart'; // Untuk SemanticsService (pengumuman ke pembaca layar)

import '../theme/theme_extensions.dart'; // Warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// MONTH PICKER DIALOG  –  Dialog pemilih bulan & tahun
///
/// Dipakai bersama oleh halaman Laporan dan menu Riwayat di halaman
/// Transaksi. Mengembalikan DateTime(tahun, bulan) saat "Pilih"
/// ditekan, atau null saat dibatalkan.
/// ─────────────────────────────────────────────────────────────────
class MonthPickerDialog extends StatefulWidget { // dialog pemilih bulan & tahun
  final DateTime initialDate; // tanggal awal saat dialog dibuka
  const MonthPickerDialog({super.key, required this.initialDate});

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState(); // buat state terkait
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _tahun; // tahun yang sedang dipilih di dialog
  late int _bulan; // bulan yang sedang dipilih di dialog

  static const List<String> _singkat = [ // nama bulan singkat untuk grid
    'Jan', 'Feb', 'Mar', 'Apr',
    'Mei', 'Jun', 'Jul', 'Agu',
    'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const List<String> _namaPanjang = [ // nama bulan lengkap untuk label semantik
    'Januari', 'Februari', 'Maret', 'April',
    'Mei', 'Juni', 'Juli', 'Agustus',
    'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _tahun = widget.initialDate.year; // set tahun awal dari parameter
    _bulan = widget.initialDate.month; // set bulan awal dari parameter

    // Dialog ini muncul di atas fokus TalkBack sebelumnya tanpa
    // konteks apa pun — tanpa pengumuman ini, fokus otomatis jatuh ke
    // tombol "Tahun sebelumnya" duluan dan pengguna tidak pernah
    // diberi tahu bulan/tahun apa yang sedang ditampilkan.
    // addPostFrameCallback dipakai karena View.of(context) baru valid
    // setelah frame pertama dialog ini selesai dirender.
    WidgetsBinding.instance.addPostFrameCallback((_) { // jalankan setelah frame pertama selesai dirender
      if (!mounted) return; // batalkan jika widget sudah dilepas
      SemanticsService.sendAnnouncement( // umumkan bulan/tahun aktif ke pembaca layar
        View.of(context),
        'Pilih bulan. Saat ini menampilkan ${_namaPanjang[_bulan - 1]} $_tahun.',
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final int tahunSekarang = DateTime.now().year; // tahun sekarang, batas atas navigasi tahun
    return Dialog( // bungkus konten sebagai dialog modal
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // sudut dialog membulat
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // tinggi seminimal isinya
          children: [
            // Navigator tahun
            Row( // baris navigasi ganti tahun
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton( // tombol tahun sebelumnya
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _tahun--), // kurangi tahun
                  tooltip: 'Tahun sebelumnya',
                ),
                Semantics(
                  header: true, // tandai sebagai header bagi pembaca layar
                  label: 'Tahun $_tahun',
                  excludeSemantics: true,
                  child: Text(
                    '$_tahun', // tampilkan tahun aktif
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                ),
                IconButton( // tombol tahun berikutnya
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _tahun < tahunSekarang // hanya aktif jika belum tahun sekarang
                      ? () => setState(() => _tahun++) // tambah tahun
                      : null,
                  tooltip: 'Tahun berikutnya',
                ),
              ],
            ),
            const SizedBox(height: 12), // jarak vertikal

            // Grid bulan
            // Tinggi sel dipatok minimal 48 dp, bukan rasio lebar:tinggi.
            // Rasio 1,4 sebelumnya menghasilkan sel 54×39 dp di HP 360 dp,
            // di bawah target sentuh minimum 48 dp.
            GridView( // grid 12 bulan
              shrinkWrap: true, // tinggi menyesuaikan isi
              physics: const NeverScrollableScrollPhysics(), // grid tidak digulir sendiri
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, // 4 kolom
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: MediaQuery.textScalerOf(context).scale(48).clamp(48, 96), // ikut membesar bersama teks
              ),
              children: List.generate(12, (i) { // buat 12 tombol bulan
                final int b = i + 1; // nomor bulan 1-12
                final bool dipilih = b == _bulan; // apakah bulan ini sedang dipilih
                return Semantics(
                  button: true,
                  selected: dipilih,
                  label: '${_namaPanjang[i]}${dipilih ? ', dipilih' : ''}', // label sesuai status pilih
                  onTap: () => setState(() => _bulan = b), // pilih bulan ini
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => _bulan = b), // pilih bulan ini
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dipilih // warna latar sesuai status pilih
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _singkat[i], // teks nama bulan singkat
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: dipilih
                              ? Theme.of(context).colorScheme.onPrimary
                              : context.warnaTeksUtama,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16), // jarak vertikal

            // Tombol aksi
            Row( // baris tombol Batal & Pilih
              children: [
                Expanded(
                  child: TextButton( // tombol batal
                    onPressed: () => Navigator.pop(context), // tutup dialog tanpa hasil
                    child: Text(
                      'Batal',
                      style: TextStyle(color: context.warnaTeksMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8), // jarak horizontal
                Expanded(
                  child: ElevatedButton( // tombol konfirmasi pilih
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => // kembalikan tanggal terpilih ke pemanggil
                        Navigator.pop(context, DateTime(_tahun, _bulan)),
                    child: const Text('Pilih'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
