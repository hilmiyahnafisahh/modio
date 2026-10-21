import 'package:flutter/material.dart'; // Import komponen UI utama Flutter
import 'package:flutter/semantics.dart'; // Import untuk mengirim pengumuman ke pembaca layar (aksesibilitas)

import '../../../../core/services/aksesibilitas_controller.dart'; // Pola getaran berhasil/gagal
import '../../../../core/theme/app_typography.dart'; // Kumpulan gaya teks standar aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi context untuk warna tema
import '../../../../core/utils/currency_formatter.dart'; // Fungsi bantu format angka jadi mata uang & tanggal
import '../../../../core/widgets/app_card.dart'; // Widget kartu & baris info standar aplikasi
import '../../data/transaction_model.dart'; // Model data satu transaksi
import '../../data/transaksi_repository.dart'; // Sumber data transaksi (baca/ubah/hapus dari database)
import '../widgets/record_transaction_modal.dart'; // Modal form untuk mencatat/mengedit transaksi

/// ─────────────────────────────────────────────────────────────────
/// TRANSACTION DETAIL PAGE  –  Rincian satu transaksi
///
/// Dibuka dengan mengetuk baris mana pun di daftar riwayat — tombol
/// titik tiga dihapus, seluruh baris jadi satu target sentuh. Aksi
/// Edit dan Hapus ada di satu tempat yang jelas di sini, bukan
/// tersembunyi di menu kecil yang mudah terlewat pengguna tunanetra.
/// ─────────────────────────────────────────────────────────────────

class TransactionDetailPage extends StatefulWidget { // Halaman detail transaksi, butuh State karena data bisa berubah (edit)
  final TransactionItem item; // Data transaksi yang ditampilkan, diberikan dari halaman pemanggil

  const TransactionDetailPage({super.key, required this.item}); // Constructor, item wajib diisi

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState(); // Membuat objek State halaman ini
}

class _TransactionDetailPageState extends State<TransactionDetailPage> { // Kelas State: data & logika halaman detail transaksi
  final _repo = TransaksiRepository(); // Objek untuk mengambil/mengubah/menghapus transaksi di database

  late TransactionItem _item; // Data transaksi yang sedang ditampilkan, bisa berubah setelah edit

  /// true kalau data sempat diubah (edit) atau dihapus — dipakai
  /// pemanggil (halaman riwayat) untuk tahu apakah daftarnya perlu
  /// dimuat ulang.
  bool _berubah = false; // Menandai apakah ada perubahan yang perlu diketahui halaman sebelumnya

  @override
  void initState() { // Dipanggil sekali saat halaman pertama kali dibuat
    super.initState(); // Panggil inisialisasi bawaan Flutter
    _item = widget.item; // Salin data transaksi awal dari widget induk ke variabel state
  }

  bool get _isMasuk => _item.type == TransactionType.masuk; // True jika transaksi ini jenis pemasukan

  Color get _warna => _isMasuk ? context.warnaMasuk : context.warnaKeluar; // Warna tema mengikuti jenis transaksi (masuk/keluar)

  Future<void> _edit() async { // Membuka modal edit dan memuat ulang data setelah selesai
    final bool? tersimpan = await showModalBottomSheet<bool>( // Tampilkan modal dari bawah layar, tunggu hasilnya
      context: context, // Context halaman saat ini
      isScrollControlled: true, // Modal bisa mengatur tinggi sendiri (biasanya untuk form dengan keyboard)
      backgroundColor: Colors.transparent, // Latar modal transparan, biar sudut kartu modal terlihat
      builder: (_) => RecordTransactionModal(existingItem: _item), // Bangun modal edit dengan data transaksi saat ini
    );
    if (tersimpan != true || !mounted) return; // Batalkan jika modal ditutup tanpa simpan, atau halaman sudah hilang

    // Ambil ulang transaksi ini dari basis data supaya halaman detail
    // menampilkan hasil perubahan, bukan data lama yang masih di memori.
    final List<TransactionItem> semua = await _repo.riwayat(batas: null); // Ambil seluruh riwayat transaksi tanpa batas jumlah
    final Iterable<TransactionItem> cocok = // Cari transaksi dengan id yang sama seperti yang sedang ditampilkan
        semua.where((t) => t.id == _item.id);
    if (cocok.isEmpty || !mounted) return; // Batalkan jika transaksi tidak ditemukan lagi atau halaman sudah hilang

    setState(() { // Perbarui tampilan dengan data transaksi terbaru
      _item = cocok.first; // Ganti data lama dengan hasil terbaru dari database
      _berubah = true; // Tandai bahwa ada perubahan untuk diberitahu ke halaman sebelumnya
    });
    SemanticsService.sendAnnouncement( // Kirim pengumuman ke pembaca layar bahwa data sudah diperbarui
      View.of(context), // Referensi tampilan aplikasi saat ini
      'Detail diperbarui. ${_item.narasi}', // Teks yang dibacakan pembaca layar
      Directionality.of(context), // Arah teks (kiri-ke-kanan/kanan-ke-kiri) sesuai lokal
    );
  }

  Future<void> _hapus() async { // Menampilkan dialog konfirmasi lalu menghapus transaksi jika disetujui
    final bool? konfirmasi = await showDialog<bool>( // Tampilkan dialog konfirmasi, tunggu jawaban pengguna
      context: context, // Context halaman saat ini
      builder: (dialogContext) => AlertDialog( // Bangun isi dialog konfirmasi hapus
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Sudut dialog melengkung
        title: Text( // Judul dialog konfirmasi
          'Hapus transaksi ini?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: dialogContext.warnaTeksUtama, // Warna judul sesuai tema
          ),
        ),
        content: Text( // Penjelasan tambahan di dialog
          'Yakin ingin menghapus transaksi ini? '
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            fontSize: 15,
            color: dialogContext.warnaTeksMuted, // Warna teks redup untuk penjelasan
            height: 1.5, // Jarak antar baris teks
          ),
        ),
        actions: [ // Tombol aksi di bagian bawah dialog
          TextButton( // Tombol batal
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)), // Ukuran minimum tombol agar mudah disentuh
            onPressed: () => Navigator.pop(dialogContext, false), // Tutup dialog, kembalikan hasil false (batal)
            child: Text( // Label tombol batal
              'Batal',
              style: TextStyle(
                color: dialogContext.warnaTeksMuted, // Warna teks netral/redup
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton( // Tombol hapus (konfirmasi)
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)), // Ukuran minimum tombol agar mudah disentuh
            onPressed: () => Navigator.pop(dialogContext, true), // Tutup dialog, kembalikan hasil true (setuju hapus)
            child: Text( // Label tombol hapus
              'Hapus',
              style: TextStyle(
                color: dialogContext.warnaKeluar, // Warna merah/keluar menandakan aksi berbahaya
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return; // Batalkan jika pengguna tidak menyetujui hapus, atau halaman sudah hilang

    try { // Coba proses hapus, tangkap jika gagal
      await _repo.hapus(_item.id); // Minta repository menghapus transaksi ini dari database
      if (!mounted) return; // Batalkan lanjutan jika halaman sudah ditutup selama menunggu
      SemanticsService.sendAnnouncement( // Beri tahu pembaca layar bahwa transaksi berhasil dihapus
        View.of(context),
        'Transaksi dihapus.',
        Directionality.of(context),
      );
      AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
      Navigator.pop(context, true); // Tutup halaman detail, kembalikan true agar halaman riwayat memuat ulang
    } catch (e) { // Jika penghapusan gagal
      if (!mounted) return; // Batalkan jika halaman sudah ditutup
      AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
      ScaffoldMessenger.of(context).showSnackBar( // Tampilkan notifikasi kecil di bawah layar
        const SnackBar( // Isi notifikasi kegagalan
          content: Text('Transaksi belum bisa dihapus. Coba lagi.'),
        ),
      );
    }
  }

  String _kapital(String s) => // Fungsi bantu untuk membuat huruf pertama kapital
      s.trim().isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}'; // Jika kosong kembalikan apa adanya, jika tidak kapitalkan huruf pertama

  @override
  Widget build(BuildContext context) { // Membangun tampilan halaman detail transaksi
    // canPop: false + pop manual di sini supaya tombol back sistem
    // (gesture/tombol fisik) ikut mengembalikan _berubah ke halaman
    // riwayat, sama seperti tombol back kustom di header — bukan cuma
    // menutup halaman tanpa memberi tahu perlu dimuat ulang atau tidak.
    return PopScope( // Widget untuk mengendalikan perilaku tombol kembali sistem
      canPop: false, // Cegah penutupan otomatis, kita tangani manual di bawah
      onPopInvokedWithResult: (bool didPop, Object? result) { // Dipanggil saat pengguna mencoba kembali (gesture/tombol)
        if (didPop) return; // Jika sudah terlanjur ditutup, tidak perlu lakukan apa-apa lagi
        Navigator.pop(context, _berubah); // Tutup halaman sambil mengirim status perubahan ke pemanggil
      },
      child: Scaffold( // Kerangka dasar halaman
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar mengikuti tema
        body: SafeArea( // Hindari konten tertutup notch/status bar
          child: Column( // Susun header dan konten secara vertikal
            crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
            children: [
              Padding( // Jarak di sekitar baris header (tombol kembali + judul)
                padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                child: Row( // Tombol kembali dan judul berdampingan
                  children: [
                    IconButton( // Tombol kembali kustom
                      constraints: const BoxConstraints( // Ukuran minimum tombol agar mudah disentuh
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.pop(context, _berubah), // Tutup halaman, kirim status perubahan
                      tooltip: 'Kembali', // Teks bantuan aksesibilitas
                      icon: Icon( // Ikon panah kembali
                        Icons.chevron_left,
                        size: 30,
                        color: context.warnaTeksUtama, // Warna ikon sesuai tema
                      ),
                    ),
                    const SizedBox(width: 4), // Jarak kecil antara tombol dan judul
                    Text( // Judul halaman
                      'Detail Transaksi',
                      style: AppTypography.titleLarge.copyWith(
                        color: context.warnaTeksUtama, // Warna judul sesuai tema
                      ),
                    ),
                  ],
                ),
              ),
              Expanded( // Sisa ruang halaman diisi konten yang bisa digulir
                child: SingleChildScrollView( // Konten bisa digulir jika lebih panjang dari layar
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20), // Jarak dalam konten
                  child: Column( // Susun semua bagian detail secara vertikal
                    crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                    children: [
                      // ── Ringkasan atas: ikon, judul, arah ────────────
                      Semantics( // Bungkus ringkasan atas dengan info aksesibilitas khusus
                        label: _item.narasi, // Teks yang dibacakan pembaca layar untuk seluruh baris ini
                        excludeSemantics: true, // Cegah elemen anak dibacakan lagi secara terpisah
                        child: Row( // Ikon arah, judul, dan jenis transaksi berdampingan
                          children: [
                            Container( // Lingkaran ikon arah transaksi
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _isMasuk // Warna latar berbeda untuk pemasukan/pengeluaran
                                    ? context.latarMasuk
                                    : context.latarKeluar,
                                shape: BoxShape.circle, // Bentuk lingkaran
                                border: Border.all(color: _warna, width: 1.5), // Garis tepi sesuai warna jenis transaksi
                              ),
                              child: Icon( // Ikon panah arah transaksi
                                _isMasuk // Panah beda arah untuk pemasukan/pengeluaran
                                    ? Icons.north_east
                                    : Icons.south_west,
                                color: _warna, // Warna ikon sesuai jenis transaksi
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14), // Jarak antara ikon dan teks
                            Expanded( // Kolom judul & jenis mengisi sisa ruang baris
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                                children: [
                                  Text( // Judul/nama transaksi
                                    _item.title,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: context.warnaTeksUtama, // Warna teks utama
                                    ),
                                  ),
                                  const SizedBox(height: 2), // Jarak kecil antara judul dan jenis
                                  Text( // Label jenis transaksi (pemasukan/pengeluaran)
                                    _isMasuk ? 'Pemasukan' : 'Pengeluaran',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: _warna, // Warna sesuai jenis transaksi
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18), // Jarak setelah ringkasan atas
                      Text( // Nominal transaksi dengan tanda +/- dan format mata uang
                        '${_isMasuk ? '+' : '-'}' // Tanda plus untuk pemasukan, minus untuk pengeluaran
                        '${CurrencyFormatter.format(_item.nominal)}', // Nominal diformat jadi teks mata uang
                        style: AppTypography.headingSmall.copyWith(
                          color: _warna, // Warna angka sesuai jenis transaksi
                        ),
                      ),
                      const SizedBox(height: 24), // Jarak sebelum kartu rincian field

                      // ── Rincian field ─────────────────────────────
                      AppCard( // Kartu berisi daftar rincian informasi transaksi
                        padding: const EdgeInsets.symmetric(horizontal: 16), // Jarak dalam kartu kiri-kanan
                        child: Column( // Susun setiap baris info secara vertikal
                          children: [
                            AppInfoCard( // Baris info: tanggal transaksi
                              label: 'Tanggal',
                              value: DateFormatter.dateWithMonth( // Format tanggal jadi teks dengan nama bulan
                                _item.occurredAt.toLocal(), // Konversi waktu UTC tersimpan ke waktu lokal perangkat
                              ),
                            ),
                            Divider(height: 1, color: context.warnaGaris), // Garis pemisah antar baris info
                            AppInfoCard( // Baris info: jam transaksi
                              label: 'Jam',
                              value: DateFormatter.time( // Format waktu jadi teks jam:menit
                                _item.occurredAt.toLocal(), // Konversi ke waktu lokal
                              ),
                            ),
                            Divider(height: 1, color: context.warnaGaris), // Garis pemisah
                            AppInfoCard( // Baris info: jenis transaksi
                              label: 'Jenis',
                              value: _isMasuk ? 'Pemasukan' : 'Pengeluaran',
                            ),
                            Divider(height: 1, color: context.warnaGaris), // Garis pemisah
                            AppInfoCard( // Baris info: metode pembayaran
                              label: 'Metode bayar',
                              value: _kapital(_item.method), // Huruf pertama metode dikapitalkan
                            ),
                            Divider(height: 1, color: context.warnaGaris), // Garis pemisah
                            AppInfoCard( // Baris info: kategori transaksi
                              label: 'Kategori',
                              value: _item.kategori,
                            ),
                            if (_item.catatan != null && // Hanya tampilkan baris catatan jika ada isinya
                                _item.catatan!.trim().isNotEmpty) ...[
                              Divider(
                                  height: 1, color: context.warnaGaris), // Garis pemisah sebelum catatan
                              AppInfoCard( // Baris info: catatan tambahan pengguna
                                label: 'Catatan',
                                value: _item.catatan!,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28), // Jarak sebelum tombol aksi

                      // ── Aksi: Edit & Hapus ────────────────────────
                      Row( // Tombol Edit dan Hapus berdampingan, masing-masing mengisi setengah lebar
                        children: [
                          Expanded( // Tombol Edit mengisi setengah ruang
                            child: OutlinedButton.icon( // Tombol bergaris tepi dengan ikon + teks
                              onPressed: _edit, // Buka modal edit saat ditekan
                              icon: const Icon(Icons.edit_outlined, size: 20), // Ikon pensil edit
                              label: const Text('Edit'), // Label tombol
                              style: OutlinedButton.styleFrom( // Gaya visual tombol edit
                                minimumSize: const Size.fromHeight(52), // Tinggi minimum tombol
                                side: BorderSide( // Garis tepi tombol
                                  color: context.warnaMasuk, // Warna hijau/masuk untuk aksi edit
                                  width: 1.5,
                                ),
                                foregroundColor: context.warnaMasuk, // Warna ikon & teks tombol
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder( // Sudut tombol melengkung
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12), // Jarak antara tombol Edit dan Hapus
                          Expanded( // Tombol Hapus mengisi setengah ruang lainnya
                            child: OutlinedButton.icon( // Tombol bergaris tepi dengan ikon + teks
                              onPressed: _hapus, // Tampilkan dialog konfirmasi hapus saat ditekan
                              icon:
                                  const Icon(Icons.delete_outline, size: 20), // Ikon tempat sampah
                              label: const Text('Hapus'), // Label tombol
                              style: OutlinedButton.styleFrom( // Gaya visual tombol hapus
                                minimumSize: const Size.fromHeight(52), // Tinggi minimum tombol
                                side: BorderSide( // Garis tepi tombol
                                  color: context.warnaKeluar, // Warna merah/keluar menandakan aksi berbahaya
                                  width: 1.5,
                                ),
                                foregroundColor: context.warnaKeluar, // Warna ikon & teks tombol
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder( // Sudut tombol melengkung
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
