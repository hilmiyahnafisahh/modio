import 'package:flutter/material.dart'; // Import komponen UI utama Flutter (Widget, Text, Scaffold, dll)
import 'package:flutter/services.dart'; // Import untuk mengatur tampilan sistem, misalnya warna status bar

import '../../../../core/navigation/app_route.dart'; // Fungsi bantu untuk membuat rute navigasi antar halaman
import '../../../../core/theme/app_typography.dart'; // Kumpulan gaya teks (font, ukuran) standar aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi context untuk warna tema (mode gelap/terang)
import '../../../../core/services/profile_update_service.dart'; // Service untuk memberi tahu jika profil pengguna berubah
import '../../../profile/data/profile_repository.dart'; // Sumber data profil pengguna (baca dari penyimpanan lokal)
import '../../../transactions/data/transaction_model.dart'; // Model data transaksi & ringkasan keuangan
import '../../../transactions/data/transaksi_repository.dart'; // Sumber data transaksi (ambil dari database lokal)
import '../../../transactions/presentation/pages/transaction_detail_page.dart'; // Halaman detail satu transaksi
import '../../../transactions/presentation/widgets/transaction_tile.dart'; // Widget satu baris transaksi di daftar
import '../widgets/ai_assistant_banner.dart'; // Widget banner ajakan membuka Asisten AI
import '../widgets/balance_card.dart'; // Widget kartu penampil saldo
import '../widgets/summary_grid.dart'; // Widget grid ringkasan pemasukan/pengeluaran/laba
import '../../../transactions/presentation/widgets/voice_transaction_flow.dart';

/// ─────────────────────────────────────────────────────────────────
/// DASHBOARD PAGE  –  Halaman Beranda Utama Modio
///
/// Seluruh angka pada halaman ini berasal dari basis data lokal,
/// bukan nilai yang ditulis di kode. Angka dan ringkasan dihitung
/// oleh TransaksiRepository.
/// ─────────────────────────────────────────────────────────────────

class DashboardPage extends StatefulWidget { // Widget halaman ini bisa berubah tampilan (butuh State), maka StatefulWidget
  /// Callback untuk membuka halaman Asisten AI.
  final VoidCallback? onOpenAiChat; // Fungsi opsional yang dipanggil saat tombol/menu AI ditekan, diberikan dari luar

  /// Callback untuk beralih ke tab Laporan.
  final VoidCallback? onOpenReports; // Fungsi opsional yang dipanggil untuk pindah ke tab Laporan

  const DashboardPage({ // Constructor widget, memakai const supaya bisa dioptimalkan Flutter
    super.key, // Key bawaan Flutter untuk mengidentifikasi widget secara unik
    this.onOpenAiChat, // Menerima callback AI dari widget pemanggil (opsional)
    this.onOpenReports, // Menerima callback Laporan dari widget pemanggil (opsional)
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState(); // Membuat objek State yang menyimpan data & logika halaman
}

class _DashboardPageState extends State<DashboardPage> { // Kelas State: tempat menyimpan variabel yang bisa berubah dan method build tampilan
  final _repo = TransaksiRepository(); // Objek untuk mengambil data transaksi & ringkasan dari database
  final _profileRepo = ProfileRepository.instance; // Objek singleton untuk membaca data profil pengguna

  late Future<FinancialSummary> _ringkasan; // Menyimpan proses asinkron pengambilan ringkasan keuangan hari ini
  late Future<List<TransactionItem>> _transaksiTerbaru; // Menyimpan proses asinkron pengambilan daftar transaksi terbaru

  // Kosong berarti belum diisi — bukan ditampilkan sebagai nama,
  // ditangani lewat sapaan tanpa nama di _buildHeader().
  String _profilNama = ''; // Menyimpan nama profil pengguna, default string kosong sebelum data dimuat
  late final ProfileUpdateService _profileUpdateService; // Service listener yang memberi notifikasi saat profil diperbarui

  @override
  void initState() { // Dipanggil sekali saat widget pertama kali dibuat
    super.initState(); // Wajib memanggil versi induk agar inisialisasi dasar Flutter berjalan
    _profileUpdateService = ProfileUpdateService(); // Membuat instance service pemantau perubahan profil
    _profileUpdateService.updateNotifier.addListener(_muatProfilNama); // Mendaftarkan fungsi _muatProfilNama agar dipanggil ulang saat profil berubah
    _muat(); // Memulai pengambilan data ringkasan & transaksi saat halaman dibuka
    _muatProfilNama(); // Memulai pengambilan nama profil saat halaman dibuka
  }

  @override
  void dispose() { // Dipanggil saat widget dihancurkan (misalnya halaman ditutup)
    _profileUpdateService.updateNotifier.removeListener(_muatProfilNama); // Melepas listener supaya tidak terjadi memory leak
    super.dispose(); // Wajib memanggil versi induk untuk membersihkan resource Flutter lainnya
  }

  Future<void> _muatProfilNama() async { // Fungsi asinkron untuk mengambil dan memperbarui nama profil
    try { // Blok percobaan, untuk menangkap error jika pembacaan profil gagal
      final profil = await _profileRepo.bacaProfil(); // Menunggu hasil pembacaan data profil dari repository
      if (mounted) { // Memastikan widget masih ada di layar sebelum memanggil setState (mencegah error)
        setState(() { // Memberi tahu Flutter agar membangun ulang tampilan dengan data baru
          _profilNama = profil['profil_nama'] ?? ''; // Mengambil nama dari map profil, atau string kosong jika tidak ada
        });
      }
    } catch (_) { // Menangkap error apa pun tanpa perlu detailnya
      // Use default if error
    }
  }

  void _muat() { // Fungsi untuk memulai (atau memulai ulang) pengambilan data dashboard
    _ringkasan = _repo.ringkasanHariIni(); // Meminta ringkasan keuangan hari ini dari repository
    _transaksiTerbaru = _repo.riwayat( // Meminta daftar riwayat transaksi dari repository
      batas: null, // Tidak membatasi jumlah transaksi yang diambil
      periode: PeriodeFilter.hariIni, // Memfilter hanya transaksi periode hari ini
    );
  }

  Future<void> _segarkan() async { // Fungsi untuk menyegarkan data saat pengguna menarik layar ke bawah (pull-to-refresh)
    setState(_muat); // Memanggil _muat di dalam setState agar Future baru dibuat dan UI dibangun ulang
    await Future.wait([_ringkasan, _transaksiTerbaru]); // Menunggu kedua proses pengambilan data selesai sebelum indikator refresh berhenti
  }

  /// Membuka halaman Detail Transaksi dari baris di daftar "Transaksi
  /// Hari Ini". Sama seperti pola di Riwayat: Navigator.push (bukan
  /// pushReplacement) supaya posisi scroll dashboard tetap utuh saat
  /// kembali, dan hanya memuat ulang kalau memang ada perubahan.
  Future<void> _bukaDetail(TransactionItem item) async { // Fungsi untuk membuka halaman detail satu transaksi
    final bool? berubah = await Navigator.push<bool>( // Mendorong halaman baru ke tumpukan navigasi, menunggu hasil kembaliannya
      context, // Context saat ini, dibutuhkan Navigator untuk tahu posisi widget di tree
      buatRute((_) => TransactionDetailPage(item: item)), // Membuat rute menuju halaman detail dengan data transaksi terkait
    );
    if (berubah == true && mounted) { // Jika halaman detail melaporkan ada perubahan data, dan widget masih hidup
      setState(_muat); // Muat ulang data dashboard supaya angka & daftar transaksi ikut terbarui
    }
  }

  Future<void> _handleVoiceInput() async { // Fungsi yang dipanggil saat tombol mic (input suara) ditekan
    final bool? tersimpan = await mulaiCatatTransaksiSuara(context);
    if (tersimpan == true && mounted) setState(_muat);
  }

  @override
  Widget build(BuildContext context) { // Method wajib yang membangun tampilan (UI) halaman ini
    final scheme = Theme.of(context).colorScheme; // Mengambil skema warna tema aktif untuk dipakai di seluruh build
    return AnnotatedRegion<SystemUiOverlayStyle>( // Widget untuk mengatur tampilan status bar sistem (Android/iOS)
      value: SystemUiOverlayStyle( // Konfigurasi gaya status bar
        statusBarColor: Colors.transparent, // Membuat status bar transparan agar menyatu dengan latar halaman
        statusBarIconBrightness: // Mengatur warna ikon status bar (jam, baterai, sinyal)
            context.gelap ? Brightness.light : Brightness.dark, // Ikon terang jika mode gelap, gelap jika mode terang
        statusBarBrightness: context.gelap ? Brightness.dark : Brightness.light, // Kecerahan status bar (khusus iOS), kebalikan dari warna ikon
      ),
      child: Scaffold( // Kerangka dasar halaman: menyediakan body, tombol apung, dsb
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar halaman mengikuti tema aktif
      floatingActionButton: SizedBox( // Membungkus tombol apung dengan ukuran tetap
        width: 64, // Lebar tombol apung 64 pixel
        height: 64, // Tinggi tombol apung 64 pixel
        child: FloatingActionButton( // Tombol bulat mengambang khas Material Design
        heroTag: 'fab_dashboard',
        onPressed: _handleVoiceInput, // Saat ditekan, jalankan fungsi penanganan input suara
        backgroundColor: scheme.primary, // Warna latar tombol memakai warna utama tema
        elevation: 4, // Tinggi bayangan tombol agar terlihat "mengambang"
        shape: const CircleBorder(), // Bentuk tombol dibuat bulat sempurna
        tooltip: 'Catat transaksi dengan suara', // Teks bantuan yang muncul saat ditekan lama (long press)
        // Semantics eksplisit, bukan cuma mengandalkan tooltip.
        // Tanpa label ini pembaca layar hanya menyebutnya "tombol"
        // tanpa keterangan, tak terbedakan dari tombol tambah lain.
        child: Semantics( // Widget untuk memberi informasi tambahan ke pembaca layar (aksesibilitas)
          button: true, // Memberi tahu pembaca layar bahwa elemen ini adalah tombol
          label: 'Catat transaksi dengan suara', // Teks yang dibacakan oleh pembaca layar (TalkBack/VoiceOver)
          excludeSemantics: true, // Mencegah elemen anak (Icon) dibacakan lagi secara terpisah
          child: Icon( // Ikon yang ditampilkan di dalam tombol
            Icons.mic_rounded, // Ikon mikrofon (bulat)
            color: scheme.onPrimary, // Warna ikon kontras dengan warna latar tombol
            size: 30, // Ukuran ikon 30 pixel
          ),
        ),
        ),
      ),
      body: SafeArea( // Memastikan konten tidak tertutup notch, status bar, atau area sistem lain
        child: RefreshIndicator( // Widget yang menambahkan gestur "tarik untuk menyegarkan"
          onRefresh: _segarkan, // Fungsi yang dipanggil saat pengguna menarik layar ke bawah
          child: SingleChildScrollView( // Membuat konten bisa digulir jika lebih panjang dari layar
            physics: const AlwaysScrollableScrollPhysics(), // Tetap bisa digulir/ditarik meski konten pendek (agar refresh selalu bisa dipicu)
            // Bottom 120: tinggi tombol mic (64) + jarak dari tepi —
            // tanpa ini baris/konten terakhir tertutup separuh oleh
            // tombol mic yang mengambang.
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120), // Jarak dalam: kiri 20, atas 0, kanan 20, bawah 120
            child: Column( // Menyusun semua konten dashboard secara vertikal
              crossAxisAlignment: CrossAxisAlignment.start, // Semua anak diratakan ke kiri
              children: [ // Daftar widget yang disusun dari atas ke bawah
                const SizedBox(height: 24), // Jarak kosong 24 pixel di paling atas
                _buildHeader(), // Menampilkan sapaan & nama pengguna
                const SizedBox(height: 20), // Jarak kosong 20 pixel setelah header

                // ── Saldo & ringkasan harian ────────────────────
                FutureBuilder<FinancialSummary>( // Widget yang membangun UI berdasarkan status Future (loading/selesai/error)
                  future: _ringkasan, // Future yang dipantau: proses pengambilan ringkasan keuangan
                  builder: (context, snapshot) { // Fungsi yang dipanggil setiap kali status Future berubah
                    if (snapshot.connectionState != ConnectionState.done) { // Jika data belum selesai dimuat
                      return const SizedBox( // Tampilkan kotak dengan tinggi tetap berisi indikator loading
                        height: 320, // Tinggi kotak loading 320 pixel (mencegah layout melompat saat data muncul)
                        child: Center(child: CircularProgressIndicator()), // Indikator putar di tengah kotak
                      );
                    }

                    if (snapshot.hasError) { // Jika proses pengambilan data mengalami error
                      return _pesanGalat( // Tampilkan pesan error ramah pengguna
                        'Ringkasan tidak bisa dimuat. Tutup aplikasi ' // Bagian pertama pesan error
                        'lalu buka lagi. Data Anda masih tersimpan.', // Bagian kedua pesan error, menenangkan pengguna
                      );
                    }

                    final r = snapshot.data!; // Data ringkasan sudah pasti ada (tidak null) karena sudah lolos pengecekan di atas

                    return Column( // Menyusun kartu saldo, grid ringkasan, dan narasi secara vertikal
                      crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                      children: [ // Isi kolom
                        BalanceCard( // Kartu penampil saldo
                          balance: r.saldo, // Nilai saldo saat ini dari data ringkasan
                          period: _periodeSekarang(), // Teks periode (bulan & tahun) saat ini
                        ),
                        const SizedBox(height: 24), // Jarak 24 pixel setelah kartu saldo
                        SummaryGrid( // Grid berisi angka pemasukan, pengeluaran, laba, jumlah transaksi
                          income: r.pemasukanHariIni, // Total pemasukan hari ini
                          expense: r.pengeluaranHariIni, // Total pengeluaran hari ini
                          profit: r.labaHariIni, // Laba (pemasukan dikurangi pengeluaran) hari ini
                          transactionCount: r.jumlahTransaksi, // Jumlah transaksi yang tercatat hari ini
                        ),
                        const SizedBox(height: 16), // Jarak 16 pixel setelah grid ringkasan

                        // Ringkasan naratif – dibungkus Semantics agar
                        // TalkBack membacanya sebagai satu kalimat utuh,
                        // bukan memecah tanda baca menjadi elemen terpisah.
                        Semantics( // Bungkus dengan info aksesibilitas khusus
                          label: r.narasi, // Teks yang dibacakan pembaca layar (sama dengan teks yang tampil)
                          excludeSemantics: true, // Mencegah teks di dalam dibaca dua kali oleh pembaca layar
                          child: Container( // Kotak pembungkus kartu narasi
                            width: double.infinity, // Lebar kotak memenuhi ruang yang tersedia
                            padding: const EdgeInsets.all(16), // Jarak dalam 16 pixel di semua sisi
                            decoration: BoxDecoration( // Pengaturan tampilan kotak (warna, sudut, garis tepi)
                              color: context.warnaKartu, // Warna latar kartu sesuai tema aktif
                              borderRadius: BorderRadius.circular(14), // Sudut kotak melengkung 14 pixel
                              border: Border.all(color: context.warnaGaris), // Garis tepi tipis sesuai warna tema
                            ),
                            child: Text( // Teks narasi ringkasan keuangan
                              r.narasi, // Isi kalimat narasi dari data ringkasan
                              style: AppTypography.bodyMedium.copyWith( // Gaya teks dasar, dengan penyesuaian warna
                                color: context.warnaTeksUtama, // Warna teks utama sesuai tema
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24), // Jarak 24 pixel setelah bagian saldo & ringkasan

                // ── Daftar transaksi terbaru ────────────────────
                _buildTransactionSection(), // Menampilkan judul dan daftar transaksi hari ini
                const SizedBox(height: 20), // Jarak 20 pixel setelah daftar transaksi

                AiAssistantBanner( // Banner ajakan membuka fitur Asisten AI
                  onAnalysisTap: widget.onOpenReports ?? () {}, // Saat bagian "analisis" ditekan, buka tab Laporan (atau tidak lakukan apa-apa jika callback kosong)
                  onChatTap: widget.onOpenAiChat ?? () {}, // Saat bagian "chat" ditekan, buka Asisten AI (atau tidak lakukan apa-apa jika callback kosong)
                ),

                const SizedBox(height: 24), // Jarak kosong 24 pixel di paling bawah konten
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  String _periodeSekarang() { // Fungsi untuk membuat teks periode berjalan, misalnya "Periode Agustus 2026"
    final now = DateTime.now(); // Mengambil tanggal & waktu saat ini dari perangkat
    const bulan = [ // Daftar nama bulan dalam Bahasa Indonesia
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', // Indeks 0 sengaja kosong karena bulan dimulai dari 1
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember', // Lanjutan nama bulan
    ];
    return 'Periode ${bulan[now.month]} ${now.year}'; // Menggabungkan nama bulan sesuai now.month dengan tahun saat ini
  }

  Widget _pesanGalat(String teks) { // Widget bantu untuk menampilkan pesan error dengan gaya seragam
    return Padding( // Memberi jarak di sekeliling teks error
      padding: const EdgeInsets.symmetric(vertical: 32), // Jarak atas-bawah 32 pixel, kiri-kanan 0
      child: Text( // Teks pesan error yang ditampilkan
        teks, // Isi pesan error yang diterima dari parameter
        style: AppTypography.bodyLarge.copyWith(color: context.warnaTeksUtama), // Gaya teks besar dengan warna teks utama tema
      ),
    );
  }

  Widget _buildHeader() { // Widget bantu untuk menampilkan bagian sapaan di atas halaman
    // Profil belum diisi ditampilkan sebagai sapaan polos "Selamat
    // datang", bukan "Selamat Datang," diikuti baris nama kosong —
    // menampilkan nama contoh di sini akan terlihat seperti identitas
    // orang lain, seolah milik pengguna.
    if (_profilNama.trim().isEmpty) { // Jika nama profil masih kosong (setelah dihilangkan spasi)
      return Text( // Tampilkan sapaan sederhana tanpa nama
        'Selamat datang', // Teks sapaan default
        style: AppTypography.headingSmall.copyWith( // Gaya teks judul kecil
          color: context.warnaTeksUtama, // Warna teks utama sesuai tema
        ),
      );
    }
    return Column( // Jika nama sudah ada, tampilkan dua baris: sapaan lalu nama
      crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
      children: [ // Isi kolom sapaan
        Text( // Baris pertama: kata sapaan
          'Selamat Datang,', // Teks sapaan sebelum nama
          style: AppTypography.bodyMedium.copyWith( // Gaya teks ukuran sedang
            color: context.warnaTeksMuted, // Warna teks lebih redup (bukan warna utama) untuk sapaan
          ),
        ),
        const SizedBox(height: 2), // Jarak kecil 2 pixel antara sapaan dan nama
        Text( // Baris kedua: nama pengguna
          _profilNama, // Nama profil yang sudah dimuat dari repository
          style: AppTypography.headingSmall.copyWith( // Gaya teks judul kecil, lebih menonjol dari sapaan
            color: context.warnaTeksUtama, // Warna teks utama sesuai tema
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionSection() { // Widget bantu untuk menampilkan judul & daftar transaksi hari ini
    return Column( // Menyusun judul dan daftar secara vertikal
      crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
      children: [ // Isi kolom bagian transaksi
        Text( // Judul bagian
          'Transaksi Hari Ini', // Teks judul daftar transaksi
          style: AppTypography.titleLarge.copyWith( // Gaya teks judul besar
            color: context.warnaTeksUtama, // Warna teks utama sesuai tema
          ),
        ),
        const SizedBox(height: 12), // Jarak 12 pixel antara judul dan daftar

        FutureBuilder<List<TransactionItem>>( // Membangun UI berdasarkan status pengambilan daftar transaksi
          future: _transaksiTerbaru, // Future yang dipantau: daftar transaksi terbaru
          builder: (context, snapshot) { // Dipanggil setiap kali status Future berubah
            if (snapshot.connectionState != ConnectionState.done) { // Selama data masih dimuat
              return const SizedBox( // Tampilkan kotak berisi indikator loading
                height: 120, // Tinggi kotak loading 120 pixel
                child: Center(child: CircularProgressIndicator()), // Indikator putar di tengah
              );
            }

            final daftar = snapshot.data ?? const <TransactionItem>[]; // Ambil daftar transaksi, atau daftar kosong jika data null

            if (daftar.isEmpty) { // Jika belum ada transaksi sama sekali hari ini
              // Layar kosong adalah ajakan bertindak,
              // bukan permintaan maaf.
              //
              // Gaya teks memakai AppTypography, bukan TextStyle
              // lepasan: ukuran 15 yang ditulis manual tidak ikut
              // berubah saat pengguna mengatur ukuran teks aplikasi,
              // sehingga kartu ini terlihat beda sendiri dari kartu
              // transaksi yang terisi.
              return Semantics( // Bungkus kartu kosong dengan info aksesibilitas
                // Dibacakan sebagai satu kalimat utuh. Tanpa ini
                // TalkBack memecah kalimat pada tanda baris baru.
                label: 'Transaksi Hari Ini. Belum ada catatan. ' // Bagian pertama label yang dibacakan pembaca layar
                    'Tekan tombol tambah di bawah untuk mencatat ' // Bagian kedua label
                    'transaksi pertama Anda.', // Bagian ketiga/penutup label
                excludeSemantics: true, // Mencegah teks anak dibacakan dua kali
                child: Container( // Kotak kartu untuk kondisi kosong
                  width: double.infinity, // Lebar kotak memenuhi ruang tersedia
                  padding: const EdgeInsets.symmetric( // Jarak dalam kotak
                    horizontal: 20, // Jarak kiri-kanan 20 pixel
                    vertical: 32, // Jarak atas-bawah 32 pixel
                  ),
                  decoration: BoxDecoration( // Tampilan visual kotak
                    color: context.warnaKartu, // Warna latar kartu sesuai tema
                    borderRadius: BorderRadius.circular(16), // Sudut melengkung 16 pixel
                    border: Border.all(color: context.warnaGaris), // Garis tepi tipis sesuai tema
                  ),
                  child: Text( // Teks yang tampil secara visual di kartu kosong
                    'Belum ada catatan.\n' // Baris pertama: pemberitahuan belum ada data
                    'Tekan tombol tambah di bawah untuk mencatat ' // Baris kedua: ajakan bertindak
                    'transaksi pertama Anda.', // Lanjutan ajakan bertindak
                    textAlign: TextAlign.center, // Teks diratakan ke tengah
                    style: AppTypography.bodyMedium.copyWith( // Gaya teks ukuran sedang
                      color: context.warnaTeksMuted, // Warna teks redup karena bersifat info sekunder
                    ),
                  ),
                ),
              );
            }

            return Container( // Jika ada transaksi, tampilkan dalam satu kartu berisi daftar
              decoration: BoxDecoration( // Tampilan visual kartu daftar
                color: context.warnaKartu, // Warna latar kartu sesuai tema
                borderRadius: BorderRadius.circular(16), // Sudut melengkung 16 pixel
                border: Border.all(color: context.warnaGaris), // Garis tepi tipis sesuai tema
              ),
              child: Column( // Menyusun setiap baris transaksi secara vertikal
                children: List.generate(daftar.length, (index) { // Membuat satu widget untuk setiap item di daftar transaksi
                  final bool isLast = index == daftar.length - 1; // Menandai apakah ini item terakhir dalam daftar
                  return Column( // Bungkus setiap item beserta garis pemisahnya
                    children: [ // Isi: tile transaksi lalu (opsional) garis pemisah
                      TransactionTile( // Widget satu baris transaksi
                        item: daftar[index], // Data transaksi pada indeks ini
                        onTap: () => _bukaDetail(daftar[index]), // Saat baris ditekan, buka halaman detail transaksi ini
                      ),
                      if (!isLast) // Hanya tampilkan garis pemisah jika ini BUKAN item terakhir
                        Divider( // Garis pemisah horizontal antar transaksi
                          height: 1, // Tinggi total ruang garis 1 pixel
                          thickness: 1, // Ketebalan garis 1 pixel
                          indent: 56, // Garis dimulai agak menjorok ke kanan (56 pixel) agar sejajar dengan teks, bukan ikon
                          color: context.warnaGaris, // Warna garis sesuai tema
                        ),
                    ],
                  );
                }),
              ),
            );
          },
        ),
      ],
    );
  }
}
