import 'package:flutter/material.dart'; // widget dasar Flutter (Scaffold, Text, dll)
import 'package:flutter/semantics.dart'; // untuk mengumumkan info ke pembaca layar (TalkBack)
import 'package:flutter/services.dart'; // untuk SystemUiOverlayStyle (warna status bar)

import '../../../../core/navigation/app_route.dart'; // helper buatRute() untuk navigasi antar halaman
import '../../../../core/theme/app_typography.dart'; // kumpulan gaya teks (font, ukuran) aplikasi
import '../../../../core/theme/theme_extensions.dart'; // ekstensi warna tema (context.warnaX, context.gelap)
import '../../../../core/utils/currency_formatter.dart'; // format angka menjadi teks Rupiah
import '../../data/transaction_model.dart'; // model data TransactionItem, TransactionType, dll
import '../../data/transaksi_repository.dart'; // sumber data riwayat transaksi
import '../widgets/transaction_tile.dart'; // widget satu baris transaksi di daftar
import '../widgets/voice_transaction_flow.dart'; // alur catat transaksi via suara
import 'transaction_detail_page.dart'; // halaman detail satu transaksi

/// ─────────────────────────────────────────────────────────────────
/// HISTORY PAGE  –  Riwayat transaksi lengkap
///
/// Berbeda dari dashboard yang hanya menampilkan lima transaksi
/// terbaru, halaman ini memuat seluruh riwayat dan menyediakan
/// penyaringan berdasarkan periode, jenis, dan kata kunci.
/// ─────────────────────────────────────────────────────────────────

class HistoryPage extends StatefulWidget { // widget halaman Riwayat, punya state internal
  const HistoryPage({super.key}); // konstruktor const, key diteruskan ke induk

  @override
  State<HistoryPage> createState() => _HistoryPageState(); // buat objek state terkait halaman ini
}

/// Pilihan periode riwayat: cuma dua hari terakhir, tanpa kalender atau
/// preset minggu/bulan/semua waktu — riwayat penuh tetap bisa dicari
/// lewat kolom pencarian di atasnya kalau perlu tanggal yang lebih lama.
enum _RiwayatPeriode { hariIni, kemarin }

class _HistoryPageState extends State<HistoryPage> { // kelas state untuk HistoryPage
  final TransaksiRepository _repo = TransaksiRepository(); // sumber data transaksi, sekali dibuat
  final TextEditingController _cariCtrl = TextEditingController(); // pengendali teks kolom pencarian

  late Future<List<TransactionItem>> _transaksi; // daftar transaksi async, diisi belakangan

  _RiwayatPeriode _periode = _RiwayatPeriode.hariIni; // periode aktif, awalnya "Hari Ini"

  TransactionType? _jenis; // null berarti semua jenis

  /// Label periode yang sedang aktif, ditampilkan di tombol pemilih.
  String get _labelPeriode => switch (_periode) {
        _RiwayatPeriode.hariIni => 'Hari Ini',
        _RiwayatPeriode.kemarin => 'Kemarin',
      };

  /// Label jenis transaksi yang sedang aktif, ditampilkan di tombol
  /// pemilih jenis.
  String get _labelJenis => switch (_jenis) { // pilih teks label sesuai jenis aktif
        null => 'Semua transaksi', // tidak difilter jenisnya
        TransactionType.masuk => 'Masuk', // hanya transaksi masuk
        TransactionType.keluar => 'Keluar', // hanya transaksi keluar
      };

  @override
  void initState() { // dipanggil sekali saat widget pertama kali dibuat
    super.initState(); // wajib panggil versi induk terlebih dahulu
    _muat(); // muat data riwayat transaksi awal
  }

  @override
  void dispose() { // dipanggil saat widget dihapus dari pohon widget
    _cariCtrl.dispose(); // bebaskan resource controller pencarian
    super.dispose(); // wajib panggil versi induk terakhir
  }

  void _muat() { // fungsi untuk memuat/memuat ulang daftar transaksi
    setState(() { // beri tahu Flutter agar UI dibangun ulang
      final bool kemarin = _periode == _RiwayatPeriode.kemarin; // true bila periode aktif adalah "Kemarin"
      // batas null: seluruh riwayat hari itu, bukan hanya sebagian.
      _transaksi = _repo.riwayat( // ambil data sesuai filter aktif
        batas: null, // tanpa batas jumlah, ambil semua
        periode: kemarin ? PeriodeFilter.semua : PeriodeFilter.hariIni, // diabaikan repo saat tanggalKhusus diisi
        tanggalKhusus: kemarin // "Kemarin" selalu satu hari kalender spesifik: hari ini dikurangi satu
            ? DateTime.now().subtract(const Duration(days: 1))
            : null,
        type: _jenis, // filter jenis transaksi
        cari: _cariCtrl.text, // kata kunci pencarian
      );
    });
  }

  /// Mengumumkan hasil penyaringan lewat pembaca layar.
  ///
  /// Pengguna tunanetra tidak bisa melihat daftar berubah setelah
  /// menekan filter. Tanpa pengumuman, ia tidak punya cara mengetahui
  /// apakah filter benar-benar diterapkan.
  Future<void> _umumkanHasil() async { // umumkan hasil filter terbaru ke pembaca layar
    final List<TransactionItem> daftar = await _transaksi; // tunggu data transaksi selesai dimuat
    if (!mounted) return; // batalkan jika widget sudah dilepas

    final total = _repo.hitungTotal(daftar); // hitung total masuk & keluar dari daftar
    final String pesan = daftar.isEmpty // susun pesan sesuai ada/tidaknya hasil
        ? '$_labelPeriode. Tidak ada transaksi.'
        : '$_labelPeriode. ${daftar.length} transaksi. '
            'Masuk ${CurrencyFormatter.spoken(total.masuk)}, '
            'keluar ${CurrencyFormatter.spoken(total.keluar)}.';

    SemanticsService.sendAnnouncement(View.of(context), pesan, Directionality.of(context)); // ucapkan pesan lewat pembaca layar
  }

  /// Menerapkan pilihan periode (Hari Ini/Kemarin).
  void _pilihPeriode(_RiwayatPeriode p) { // terapkan pilihan periode baru
    if (p == _periode) return; // sudah aktif, tidak perlu memuat ulang
    setState(() => _periode = p); // simpan periode baru
    _muat(); // muat ulang data sesuai periode baru
    _umumkanHasil(); // umumkan hasilnya ke pembaca layar
  }

  void _ubahJenis(TransactionType? j) { // ubah filter jenis transaksi
    setState(() => _jenis = j); // simpan jenis baru
    _muat(); // muat ulang data sesuai jenis baru
    _umumkanHasil(); // umumkan hasilnya ke pembaca layar
  }

  /// Sakelar dua pilihan periode: Hari Ini / Kemarin — menggantikan
  /// dialog pemilih periode (preset minggu/bulan/semua + kalender),
  /// sebab riwayat kini sengaja dibatasi ke dua hari terakhir saja.
  Widget _buildTombolPeriode() { // bangun sakelar segmen dua pilihan periode
    return Container(
      constraints: const BoxConstraints(minHeight: 40), // tinggi minimum sakelar
      decoration: BoxDecoration(
        color: context.warnaKartu, // warna latar kartu
        borderRadius: BorderRadius.circular(10), // sudut membulat
        border: Border.all(color: context.warnaGaris), // garis tepi
      ),
      child: Row(
        children: [
          Expanded(child: _buildSegmenPeriode('Hari Ini', _RiwayatPeriode.hariIni)),
          Container(width: 1, height: 22, color: context.warnaGaris), // pemisah antar segmen
          Expanded(child: _buildSegmenPeriode('Kemarin', _RiwayatPeriode.kemarin)),
        ],
      ),
    );
  }

  Widget _buildSegmenPeriode(String label, _RiwayatPeriode p) { // bangun satu segmen (Hari Ini atau Kemarin)
    final bool terpilih = _periode == p; // status apakah segmen ini yang sedang aktif
    return Semantics( // info aksesibilitas untuk segmen ini
      button: true,
      selected: terpilih,
      label: label, // teks yang diucapkan pembaca layar
      hint: terpilih ? null : 'Ketuk dua kali untuk memilih', // petunjuk aksi, kosong bila sudah aktif
      onTap: () => _pilihPeriode(p), // aksi semantik saat diketuk
      excludeSemantics: true,
      child: InkWell( // efek ripple saat ditekan
        onTap: () => _pilihPeriode(p), // pindah ke periode ini
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: terpilih ? Theme.of(context).colorScheme.primary : Colors.transparent, // isi latar jika aktif
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Text(
            label, // teks label segmen
            overflow: TextOverflow.ellipsis, // potong dengan "..." jika kepanjangan
            style: AppTypography.labelSmall.copyWith(
              color: terpilih
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.warnaTeksUtama,
              fontWeight: terpilih ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol pemilih jenis transaksi (Semua transaksi/Masuk/Keluar),
  /// sejajar di sebelah tombol periode. Menggantikan tiga chip
  /// terpisah — satu tombol dropdown, sama seperti acuan desain yang
  /// diminta.
  Widget _buildTombolJenis() { // bangun tombol pemilih jenis transaksi
    // PopupMenuButton<T> BUKAN PopupMenuButton<TransactionType?> — nilai
    // null punya arti khusus bagi PopupMenuButton: showMenu() memakai
    // null sebagai penanda "menu ditutup tanpa memilih apa pun", jadi
    // item bernilai null literal TIDAK PERNAH memicu onSelected sama
    // sekali. Itu sebabnya "Semua transaksi" tidak berefek. String
    // penanda ('semua') di sini, lalu dipetakan ke TransactionType?
    // secara manual, menghindari tabrakan itu.
    return PopupMenuButton<String>( // tombol dengan menu pop-up pilihan jenis
      tooltip: 'Pilih jenis transaksi. Saat ini: $_labelJenis', // teks bantuan
      onSelected: (String v) => _ubahJenis( // saat item menu dipilih, ubah filter jenis
        switch (v) { // petakan string penanda ke TransactionType?
          'masuk' => TransactionType.masuk,
          'keluar' => TransactionType.keluar,
          _ => null,
        },
      ),
      itemBuilder: (context) => const [ // daftar item menu yang ditampilkan
        PopupMenuItem<String>(
          value: 'semua', // penanda "semua jenis"
          child: Text('Semua transaksi'),
        ),
        PopupMenuItem<String>(
          value: 'masuk', // penanda "transaksi masuk"
          child: Text('Masuk'),
        ),
        PopupMenuItem<String>(
          value: 'keluar', // penanda "transaksi keluar"
          child: Text('Keluar'),
        ),
      ],
      child: Container( // tampilan tombol saat menu belum dibuka
        constraints: const BoxConstraints(minHeight: 40), // tinggi minimum tombol
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.warnaKartu,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.warnaGaris),
        ),
        child: Row(
          children: [
            Expanded( // isi sisa ruang horizontal
              child: Text(
                _labelJenis, // teks label jenis aktif
                overflow: TextOverflow.ellipsis, // potong dengan "..." jika kepanjangan
                style: AppTypography.labelSmall.copyWith(
                  color: context.warnaTeksUtama,
                ),
              ),
            ),
            const SizedBox(width: 4), // jarak horizontal kecil
            Icon(
              Icons.keyboard_arrow_down_rounded, // ikon panah bawah
              size: 18,
              color: context.warnaTeksMuted,
            ),
          ],
        ),
      ),
    );
  }

  /// Group transaksi berdasarkan tanggal
  Map<String, List<TransactionItem>> _grupTransaksiByTanggal(List<TransactionItem> daftar) { // kelompokkan transaksi per label tanggal
    final Map<String, List<TransactionItem>> grouped = {}; // wadah hasil pengelompokan
    final DateTime now = DateTime.now(); // tanggal & waktu sekarang
    final DateTime kemarin = now.subtract(const Duration(days: 1)); // tanggal kemarin

    for (final trx in daftar) { // ulangi untuk setiap transaksi
      final DateTime tgl = trx.occurredAt.toLocal(); // tanggal transaksi dalam waktu lokal
      final isSameDay = tgl.year == now.year && tgl.month == now.month && tgl.day == now.day; // cek apakah hari ini
      final isSameYesterday = tgl.year == kemarin.year && tgl.month == kemarin.month && tgl.day == kemarin.day; // cek apakah kemarin

      String label; // label kelompok tanggal untuk transaksi ini
      if (isSameDay) {
        label = 'Hari Ini'; // kelompokkan sebagai "Hari Ini"
      } else if (isSameYesterday) {
        label = 'Kemarin'; // kelompokkan sebagai "Kemarin"
      } else {
        label = DateFormatter.dateWithMonth(tgl); // e.g. "14 September 2025"
      }

      grouped.putIfAbsent(label, () => []); // buat list baru jika label belum ada
      grouped[label]!.add(trx); // masukkan transaksi ke kelompok labelnya
    }

    return grouped; // kembalikan hasil pengelompokan
  }

  /// Build grouped transaction list dengan date headers.
  ///
  /// Column biasa, bukan ListView.builder — daftar ini sekarang ikut
  /// bergulir sebagai bagian dari satu halaman (lewat CustomScrollView
  /// di build()), bukan area scroll tersendiri, jadi tidak perlu
  /// viewport lazy-loading sendiri.
  Widget _buildGroupedTransactionList(List<TransactionItem> daftar) { // bangun daftar transaksi terkelompok per tanggal
    final grouped = _grupTransaksiByTanggal(daftar); // kelompokkan transaksi dulu
    final sortedKeys = grouped.keys.toList(); // ambil semua label kelompok
    // Sort dengan "Hari Ini" dan "Kemarin" paling atas
    sortedKeys.sort((a, b) { // urutkan label kelompok
      if (a == 'Hari Ini') return -1; // "Hari Ini" selalu paling atas
      if (b == 'Hari Ini') return 1;
      if (a == 'Kemarin') return -1; // "Kemarin" di bawah "Hari Ini"
      if (b == 'Kemarin') return 1;
      // Sort sisanya by tanggal descending (paling baru duluan)
      return b.compareTo(a); // urutkan label tanggal lain secara menurun
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in sortedKeys) ...[ // ulangi untuk tiap kelompok tanggal
            // Padding atas 20 supaya tiap kelompok tanggal terasa
            // sebagai bagian terpisah, bukan menyambung rapat dengan
            // baris terakhir kelompok sebelumnya.
            Padding( // header label tanggal kelompok
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                key, // teks label tanggal (mis. "Hari Ini")
                style: AppTypography.labelSmall.copyWith(
                  color: context.warnaTeksMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (int i = 0; i < grouped[key]!.length; i++) ...[ // ulangi tiap transaksi dalam kelompok ini
              TransactionTile( // baris satu transaksi
                item: grouped[key]![i], // data transaksi ke-i pada kelompok ini
                onTap: () => _bukaDetail(grouped[key]![i]), // buka detail saat diketuk
              ),
              if (i < grouped[key]!.length - 1) // beri garis kecuali baris terakhir kelompok
                Divider(
                  height: 1,
                  indent: 64,
                  color: context.warnaGaris,
                ),
            ],
          ],
        ],
      ),
    );
  }

  /// Membuka halaman Detail Transaksi. Dipanggil dengan mengetuk baris
  /// mana pun di daftar — tidak ada lagi menu titik tiga terpisah.
  ///
  /// Navigator.push (bukan pushReplacement) membuat halaman ini tetap
  /// hidup di balik Detail — saat pengguna kembali, posisi scroll-nya
  /// otomatis persis seperti sebelum dibuka, tanpa kode tambahan apa
  /// pun untuk mengingat posisi itu.
  Future<void> _bukaDetail(TransactionItem item) async { // buka halaman detail satu transaksi
    final bool? berubah = await Navigator.push<bool>( // pindah ke halaman detail, tunggu hasilnya
      context,
      buatRute((_) => TransactionDetailPage(item: item)),
    );
    if (berubah == true && mounted) { // jika ada perubahan data & widget masih hidup
      _muat(); // muat ulang daftar transaksi
    }
  }

  Future<void> _handleVoiceInput() async { // tangani input suara dari tombol mic
    final bool? tersimpan = await mulaiCatatTransaksiSuara(context); // jalankan alur catat transaksi via suara
    if (tersimpan == true && mounted) _muat(); // jika ada transaksi baru tersimpan, muat ulang data
  }

  @override
  Widget build(BuildContext context) { // membangun tampilan halaman ini
    // Tinggi header periode dihitung dari skala teks aktif, bukan
    // angka tetap. SliverPersistentHeader wajib tahu tingginya di
    // muka (tidak bisa "menyesuaikan isi" seperti Container biasa) —
    // kalau tingginya dipatok pada satu nilai, tombol periode akan
    // terpotong saat ukuran teks sistem dimaksimalkan, persis masalah
    // yang sebelumnya bikin bagian ini rusak. Skala ini memberi ruang
    // ekstra sebanding pembesaran teks.
    final double tinggiHeaderPeriode = // tinggi header periode, menyesuaikan skala teks
        MediaQuery.textScalerOf(context).scale(48.0).clamp(48.0, 96.0); // dibatasi antara 48 dan 96

    return AnnotatedRegion<SystemUiOverlayStyle>( // atur tampilan status bar sistem
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // status bar transparan
        statusBarIconBrightness:
            context.gelap ? Brightness.light : Brightness.dark, // ikon terang di mode gelap, gelap di mode terang
        statusBarBrightness: context.gelap ? Brightness.dark : Brightness.light, // untuk iOS
      ),
      child: Scaffold( // kerangka halaman (body, floating action button, dll)
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // warna latar sesuai tema
      // VoiceFab menghilang sendiri saat Mode Suara dimatikan di Pengaturan.
      floatingActionButton: VoiceFab(
        heroTag: 'fab_history', // tag unik agar tak bentrok dengan FAB halaman lain
        onPressed: _handleVoiceInput, // aksi saat tombol ditekan
      ),
      body: SafeArea( // hindari area yang terpotong notch/status bar
        child: RefreshIndicator( // gestur tarik ke bawah untuk refresh data
          onRefresh: () async => _muat(), // muat ulang data saat ditarik
          // Satu CustomScrollView untuk seluruh halaman — judul,
          // pencarian, filter jenis, ringkasan, dan daftar transaksi
          // bergulir bersama sebagai satu kesatuan. Satu-satunya yang
          // tetap di tempat adalah tombol pemilih periode, lewat
          // SliverPersistentHeader(pinned: true) di bawah ini.
          child: CustomScrollView( // area gulir tunggal berbasis sliver
            slivers: [
              SliverToBoxAdapter( // bungkus widget biasa agar bisa jadi sliver
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28), // jarak vertikal atas
                      Text(
                        'Riwayat Transaksi', // judul halaman
                        style: AppTypography.headingMedium.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                      ),
                      const SizedBox(height: 16), // jarak vertikal

                      // ── Pencarian ───────────────────────────────
                      TextField( // kolom input pencarian
                        controller: _cariCtrl, // pengendali teks pencarian
                        onSubmitted: (_) { // dipanggil saat pengguna menekan enter/submit
                          _muat(); // muat ulang data sesuai kata kunci
                          _umumkanHasil(); // umumkan hasil ke pembaca layar
                        },
                        style: AppTypography.bodyLarge.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                        decoration: InputDecoration( // tampilan kolom pencarian
                          hintText: 'Cari nama atau kategori', // teks petunjuk saat kosong
                          prefixIcon: Icon(
                            Icons.search, // ikon kaca pembesar
                            color: context.warnaTeksMuted,
                          ),
                          suffixIcon: _cariCtrl.text.isEmpty // tombol hapus hanya muncul jika ada teks
                              ? null
                              : IconButton(
                                  tooltip: 'Hapus pencarian',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () { // saat tombol hapus ditekan
                                    _cariCtrl.clear(); // kosongkan teks pencarian
                                    _muat(); // muat ulang data tanpa kata kunci
                                  },
                                ),
                          filled: true, // latar kolom terisi warna
                          fillColor: context.warnaKartu, // warna latar kolom
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder( // bentuk garis tepi default
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(color: context.warnaGaris),
                          ),
                          enabledBorder: OutlineInputBorder( // garis tepi saat tidak fokus
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(color: context.warnaGaris),
                          ),
                          focusedBorder: OutlineInputBorder( // garis tepi saat sedang fokus
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8), // jarak vertikal
                    ],
                  ),
                ),
              ),

              // ── Filter periode + jenis — bagian yang menempel ────
              // Dua tombol sejajar dalam satu baris, sama tinggi
              // (Expanded 50/50) — menggantikan tombol periode sendiri
              // di atas deretan tiga chip jenis. Keduanya kini menempel
              // saat halaman digulir, bukan cuma periode.
              SliverPersistentHeader( // header yang menempel di atas saat digulir
                pinned: true, // tetap terlihat, tidak ikut hilang saat digulir
                delegate: _PeriodeHeaderDelegate( // delegate pengatur tinggi & isi header
                  height: tinggiHeaderPeriode, // tinggi mengikuti skala teks
                  child: Container(
                    // Latar wajib buram: konten lain meluncur di
                    // baliknya saat halaman digulir, tanpa latar ini
                    // akan tembus pandang bertumpuk dengan header.
                    color: Theme.of(context).scaffoldBackgroundColor, // latar buram sesuai tema
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                    child: Row(
                      children: [
                        Expanded(child: _buildTombolPeriode()), // tombol periode, separuh lebar
                        const SizedBox(width: 10), // jarak horizontal antar tombol
                        Expanded(child: _buildTombolJenis()), // tombol jenis, separuh lebar
                      ],
                    ),
                  ),
                ),
              ),

              // ── Ringkasan + daftar transaksi ────────────────────
              SliverToBoxAdapter( // bungkus widget biasa agar bisa jadi sliver
                child: FutureBuilder<List<TransactionItem>>( // bangun UI berdasarkan status Future
                  future: _transaksi, // future daftar transaksi yang dipantau
                  builder: (context, snapshot) { // dipanggil tiap kali status future berubah
                    if (snapshot.connectionState != ConnectionState.done) { // masih memuat data
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()), // indikator berputar
                      );
                    }

                    if (snapshot.hasError) { // jika gagal memuat data transaksi
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text( // pesan error ramah pengguna
                            'Catatan tidak bisa dibuka. Tutup aplikasi '
                            'lalu buka lagi. Data Anda masih tersimpan.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: context.warnaTeksUtama,
                            ),
                          ),
                        ),
                      );
                    }

                    final List<TransactionItem> daftar = // daftar transaksi hasil filter, kosong jika null
                        snapshot.data ?? const <TransactionItem>[];

                    if (daftar.isEmpty) { // tidak ada transaksi yang cocok
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text( // pesan berbeda tergantung ada filter aktif atau belum
                            _periode == _RiwayatPeriode.hariIni &&
                                    _jenis == null &&
                                    _cariCtrl.text.isEmpty
                                ? 'Belum ada catatan.\n'
                                    'Tekan tombol tambah untuk mencatat '
                                    'transaksi pertama Anda.'
                                : 'Tidak ada transaksi yang cocok '
                                    'dengan penyaringan ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: context.warnaTeksMuted,
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ringkasan seadanya: cuma jumlah transaksi,
                          // teks polos tanpa kartu maupun nominal —
                          // rincian Masuk/Keluar sudah ada di tiap
                          // baris transaksi sendiri-sendiri.
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${daftar.length} transaksi', // jumlah transaksi hasil filter
                              style: AppTypography.labelMedium.copyWith(
                                color: context.warnaTeksMuted,
                              ),
                            ),
                          ),
                          Container( // kartu pembungkus daftar transaksi
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.warnaKartu,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                              border: Border.all(color: context.warnaGaris),
                            ),
                            child: _buildGroupedTransactionList(daftar), // daftar transaksi terkelompok per tanggal
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // 120: tinggi tombol mic (64) + jarak dari tepi bawah —
              // tanpa ini transaksi terakhir tertutup separuh oleh
              // tombol mic yang mengambang.
              const SliverToBoxAdapter(child: SizedBox(height: 120)), // jarak agar tak tertutup tombol mic
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Delegate tinggi tetap untuk header periode yang menempel di atas
/// saat halaman digulir. `height` dihitung ulang tiap build dari
/// skala teks aktif (lihat pemanggilnya), sehingga tombol periode
/// tetap punya ruang cukup pada ukuran teks besar.
class _PeriodeHeaderDelegate extends SliverPersistentHeaderDelegate { // delegate pengatur header yang menempel
  final Widget child; // isi widget header
  final double height; // tinggi tetap header

  const _PeriodeHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height; // tinggi minimum sama dengan tinggi tetap

  @override
  double get maxExtent => height; // tinggi maksimum sama dengan tinggi tetap

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) { // bangun isi header
    return child; // tampilkan widget child apa adanya
  }

  @override
  bool shouldRebuild(covariant _PeriodeHeaderDelegate oldDelegate) => true; // selalu bangun ulang saat berubah
}
