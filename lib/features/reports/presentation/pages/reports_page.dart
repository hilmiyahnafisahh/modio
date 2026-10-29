import 'package:flutter/material.dart'; // widget dasar Flutter (Scaffold, Text, dll)
import 'package:flutter/semantics.dart'; // untuk mengumumkan info ke pembaca layar (TalkBack)
import 'package:flutter/services.dart'; // untuk SystemUiOverlayStyle (warna status bar)

import '../../../../core/navigation/app_route.dart'; // helper buatRute() untuk navigasi antar halaman
import '../../../../core/widgets/akhir_halaman.dart'; // penanda & getaran saat halaman sampai dasar
import '../../../../core/widgets/month_picker_dialog.dart'; // dialog pemilih bulan & tahun bersama
import '../../../../core/theme/app_typography.dart'; // kumpulan gaya teks (font, ukuran) aplikasi
import '../../../../core/theme/theme_extensions.dart'; // ekstensi warna tema (context.warnaX, context.gelap)
import '../../../../core/utils/currency_formatter.dart'; // format angka menjadi teks Rupiah
import '../../data/laporan_repository.dart'; // sumber data laporan keuangan bulanan
import '../../data/report_model.dart'; // model data LaporanBulanan, RincianKategori, dll
import '../widgets/ai_analysis_sheet.dart'; // lembar saran AI untuk laporan bulan ini
import '../../../ai_chat/presentation/pages/ai_assistant_page.dart'; // halaman asisten AI
import '../../../dashboard/presentation/widgets/ai_assistant_banner.dart'; // banner ajakan asisten AI
import '../../../dashboard/presentation/widgets/balance_card.dart'; // kartu saldo/laba yang dipakai bareng dashboard
import '../../../transactions/presentation/widgets/voice_transaction_flow.dart'; // alur catat transaksi via suara

/// ─────────────────────────────────────────────────────────────────
/// REPORTS PAGE  –  Laporan keuangan bulanan
///
/// Tampilan sesuai desain: header dengan back button, period picker
/// berbasis kalender, kartu laba, rincian pendapatan & beban dengan
/// dot indicator, dan bagian Asisten Keuangan.
/// ─────────────────────────────────────────────────────────────────

class ReportsPage extends StatefulWidget { // widget halaman Laporan, punya state internal
  const ReportsPage({super.key}); // konstruktor const, key diteruskan ke induk

  @override
  State<ReportsPage> createState() => _ReportsPageState(); // buat objek state terkait halaman ini
}

class _ReportsPageState extends State<ReportsPage> { // kelas state untuk ReportsPage
  final LaporanRepository _repo = LaporanRepository(); // sumber data laporan, sekali dibuat

  late Future<LaporanBulanan> _laporan; // data laporan async, diisi belakangan di initState

  late int _tahun; // tahun periode yang sedang dipilih
  late int _bulan; // bulan periode yang sedang dipilih

  static const List<String> _namaBulanPanjang = [ // daftar nama bulan; index 0 kosong (1=Jan, dst)
    '',
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() { // dipanggil sekali saat widget pertama kali dibuat
    super.initState(); // wajib panggil versi induk terlebih dahulu
    final DateTime now = DateTime.now(); // ambil tanggal & waktu sekarang
    _tahun = now.year; // set tahun awal ke tahun sekarang
    _bulan = now.month; // set bulan awal ke bulan sekarang
    _muat(); // muat data laporan untuk periode awal ini
  }

  void _muat() { // fungsi untuk memuat/memuat ulang data laporan
    setState(() { // beri tahu Flutter agar UI dibangun ulang
      _laporan = _repo.laporanBulan(tahun: _tahun, bulan: _bulan); // ambil laporan sesuai periode aktif
    });
  }

  Future<void> _bukaKalender() async { // buka dialog pemilih bulan/tahun
    final DateTime? result = await showDialog<DateTime>( // tampilkan dialog, tunggu hasilnya
      context: context,
      builder: (_) => MonthPickerDialog( // bangun dialog pemilih bulan
        initialDate: DateTime(_tahun, _bulan), // tanggal awal sesuai periode aktif saat ini
      ),
    );
    if (result != null && mounted) { // proses hanya jika ada hasil & widget masih hidup
      setState(() { // perbarui state periode terpilih
        _tahun = result.year; // simpan tahun baru dari dialog
        _bulan = result.month; // simpan bulan baru dari dialog
      });
      _muat(); // muat ulang laporan untuk periode baru
      final LaporanBulanan l = await _laporan; // tunggu data laporan selesai dimuat
      if (!mounted) return; // batalkan jika widget sudah dilepas selagi menunggu
      SemanticsService.sendAnnouncement(View.of(context), l.narasi, Directionality.of(context)); // umumkan hasil ke pembaca layar
    }
  }

  String get _labelPeriode => '${_namaBulanPanjang[_bulan]} $_tahun'; // teks label periode, mis. "Januari 2026"

  Future<void> _handleVoiceInput() async { // tangani input suara dari tombol mic
    final bool? tersimpan = await mulaiCatatTransaksiSuara(context); // jalankan alur catat transaksi via suara
    if (tersimpan == true && mounted) _muat(); // jika ada transaksi baru tersimpan, muat ulang data
  }

  @override
  Widget build(BuildContext context) { // membangun tampilan halaman ini
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
        heroTag: 'fab_reports', // tag unik agar tak bentrok dengan FAB halaman lain
        onPressed: _handleVoiceInput, // aksi saat tombol ditekan
      ),
      body: SafeArea( // hindari area yang terpotong notch/status bar
        child: RefreshIndicator( // gestur tarik ke bawah untuk refresh data
          onRefresh: () async => _muat(), // muat ulang data saat ditarik
          child: GetarAkhirGulir( // getaran ringan sekali saat halaman sampai dasar
          child: SingleChildScrollView( // izinkan konten digulir
            physics: const AlwaysScrollableScrollPhysics(), // tetap bisa ditarik walau konten pendek
            child: Column( // susun konten secara vertikal
              crossAxisAlignment: CrossAxisAlignment.start, // rata kiri
              children: [
                // ── Header ──────────────────────────────────────
                _buildHeader(), // tampilkan judul halaman

                Padding( // beri jarak dari tepi kiri-kanan
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Disamakan dengan jarak header-ke-isi di halaman
                      // lain (Dashboard 20, History 16) — sebelumnya
                      // hanya 4, sehingga judul dan "Periode" terasa
                      // menempel.
                      const SizedBox(height: 20), // jarak vertikal antar bagian

                      // ── Label Periode ────────────────────────
                      Text( // label kecil "Periode"
                        'Periode',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                      ),
                      const SizedBox(height: 8), // jarak vertikal kecil

                      // ── Tombol Kalender ──────────────────────
                      _buildPeriodePicker(), // tombol pemilih periode (kalender)
                      const SizedBox(height: 22), // jarak vertikal

                      // ── Konten Laporan ───────────────────────
                      FutureBuilder<LaporanBulanan>( // bangun UI berdasarkan status Future
                        future: _laporan, // future data laporan yang dipantau
                        builder: (context, snapshot) { // dipanggil tiap kali status future berubah
                          if (snapshot.connectionState != ConnectionState.done) { // masih memuat data
                            return SizedBox( // area loading dengan tinggi tetap
                              height: 300,
                              child: Center(
                                child: CircularProgressIndicator( // indikator berputar
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) { // jika gagal memuat data laporan
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text( // pesan error ramah pengguna
                                'Laporan tidak bisa dimuat. Tutup aplikasi '
                                'lalu buka lagi. Data Anda masih tersimpan.',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: context.warnaTeksUtama,
                                ),
                              ),
                            );
                          }
                          return _buildIsi(snapshot.data!); // data siap, tampilkan isi laporan
                        },
                      ),

                      // 120: tinggi tombol mic (64) + jarak dari tepi
                      // bawah — tanpa ini konten terakhir tertutup
                      // separuh oleh tombol mic yang mengambang.
                      const SizedBox(height: 120), // jarak agar tak tertutup tombol mic
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader() { // bangun bagian judul halaman
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 0), // jarak tepi khusus judul
      child: Semantics( // judul halaman untuk navigasi Judul TalkBack
        header: true,
        // Hint dibacakan setelah judul: memberi tahu isi halaman di
        // awal, supaya pengguna tahu bagian apa saja yang bisa dilompati.
        hint: 'Berisi laba atau rugi, pendapatan, beban biaya, '
            'dan asisten keuangan per bulan.',
        child: Text(
          'Laporan Laba Rugi', // judul halaman
          style: AppTypography.headingMedium.copyWith(
            color: context.warnaTeksUtama,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodePicker() { // bangun tombol pemilih periode
    return Semantics( // info aksesibilitas untuk tombol ini
      button: true,
      label: 'Pilih periode: $_labelPeriode', // label yang diucapkan pembaca layar
      hint: 'Ketuk dua kali untuk memilih bulan dan tahun', // petunjuk aksi
      onTap: _bukaKalender, // aksi semantik saat diketuk
      excludeSemantics: true,
      child: InkWell( // efek ripple saat ditekan
        onTap: _bukaKalender, // buka dialog kalender
        borderRadius: BorderRadius.circular(10), // radius efek ripple
        child: Container( // kotak tombol
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration( // tampilan kotak
            color: context.warnaKartu, // warna latar kartu
            borderRadius: BorderRadius.circular(10), // sudut membulat
            border: Border.all(color: context.warnaGaris), // garis tepi
          ),
          child: Row( // ikon + teks sejajar
            mainAxisSize: MainAxisSize.min, // ukuran seminimal isinya
            children: [
              Icon(
                Icons.calendar_month_outlined, // ikon kalender
                size: 18,
                color: context.warnaTeksMuted,
              ),
              const SizedBox(width: 8), // jarak horizontal
              Text(
                _labelPeriode, // teks label periode aktif
                style: AppTypography.labelSmall.copyWith(
                  color: context.warnaTeksUtama,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIsi(LaporanBulanan l) { // bangun isi laporan setelah data siap
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Kartu Laba Usaha ─────────────────────────────────
        // Widget yang sama dengan kartu Saldo di dashboard, agar
        // gaya visualnya senada — bukan kartu terpisah dengan
        // tampilan sendiri.
        BalanceCard( // kartu ringkasan laba/rugi
          balance: l.labaBersih.abs(), // nilai absolut laba/rugi
          period: l.labelPeriode, // label periode laporan
          title: l.untung ? 'Laba Usaha' : 'Rugi', // judul sesuai status untung/rugi
        ),
        const SizedBox(height: 20), // jarak vertikal

        // ── Kartu Pendapatan ─────────────────────────────────
        _SeksiKeuangan( // kartu rincian pendapatan
          judul: 'Pendapatan',
          subjudul: 'Hasil penjualan',
          total: l.totalPendapatan, // total nilai pendapatan
          totalWarna: context.warnaMasuk, // warna khas transaksi masuk
          icon: Icons.arrow_outward_rounded, // ikon panah keluar (uang masuk)
          iconBgColor: context.latarMasuk, // warna latar lingkaran ikon
          iconColor: context.warnaMasuk, // warna ikon & garis tepinya
          rincian: l.rincianPendapatan, // daftar kategori pendapatan
          dotWarna: context.warnaMasuk, // warna titik penanda kategori
        ),
        const SizedBox(height: 16), // jarak vertikal

        // ── Kartu Beban Biaya ────────────────────────────────
        _SeksiKeuangan( // kartu rincian beban biaya
          judul: 'Beban Biaya',
          subjudul: 'Biaya biaya yang keluar',
          total: l.totalBeban, // total nilai beban
          totalWarna: context.warnaKeluar, // warna khas transaksi keluar
          icon: Icons.south_west_rounded, // ikon panah masuk (uang keluar)
          iconBgColor: context.latarKeluar, // warna latar lingkaran ikon
          iconColor: context.warnaKeluar, // warna ikon & garis tepinya
          rincian: l.rincianBeban, // daftar kategori beban
          dotWarna: context.warnaKeluar, // warna titik penanda kategori
        ),
        const SizedBox(height: 20), // jarak vertikal

        // ── Asisten Keuangan ─────────────────────────────────
        _AsistenKeuanganSection( // bagian ajakan pakai asisten AI
          tahun: _tahun,
          bulan: _bulan,
          repo: _repo,
        ), 
        _AsistenKeuanganSection(laporan: l), // bagian ajakan pakai asisten AI

        PenandaAkhirHalaman( // dibacakan TalkBack setelah elemen terakhir
          teks: 'Akhir laporan',
          labelSemantik: 'Akhir laporan ${l.labelPeriode}. '
              '${l.untung ? 'Laba' : 'Rugi'} ${CurrencyFormatter.spoken(l.labaBersih.abs())}.',
        ),
      ],
    );
  }
}

/*
// Blok ini adalah kode lama yang sudah dinonaktifkan (dikomentari),
// digantikan oleh _SeksiKeuangan & _KategoriRincianTile di bawah.
// Dibiarkan sebagai arsip/referensi, tidak lagi dijalankan.
/// Rekap transaksi per minggu pada bulan yang dipilih.
///
/// Detail sengaja ditampilkan langsung di halaman agar pengguna tidak perlu
/// berpindah ke bottom sheet untuk memeriksa asal setiap angka laporan.
class _RincianLaporanBulanan extends StatefulWidget {
  const _RincianLaporanBulanan({required this.laporan});

  final LaporanBulanan laporan;

  @override
  State<_RincianLaporanBulanan> createState() =>
      _RincianLaporanBulananState();
}

class _RincianLaporanBulananState extends State<_RincianLaporanBulanan> {
  final Set<int> _mingguTerbuka = <int>{1};

  Map<int, List<TransactionItem>> get _perMinggu {
    final List<TransactionItem> semua = [
      for (final kategori in widget.laporan.rincianPendapatan)
        ...kategori.transaksi,
      for (final kategori in widget.laporan.rincianBeban) ...kategori.transaksi,
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

    final Map<int, List<TransactionItem>> hasil = <int, List<TransactionItem>>{};
    for (final item in semua) {
      final int minggu = ((item.occurredAt.toLocal().day - 1) ~/ 7) + 1;
      hasil.putIfAbsent(minggu, () => <TransactionItem>[]).add(item);
    }
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    final laporan = widget.laporan;
    final perMinggu = _perMinggu;
    final bool untung = laporan.untung;
    final Color warnaLaba = untung ? AppColors.primary700 : AppColors.tertiary700;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.keyboard_arrow_down_rounded, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    laporan.labelPeriode,
                    style: AppTypography.titleSmall,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Laba', style: AppTypography.bodySmall),
                    Text(
                      '${untung ? '+' : '-'}${CurrencyFormatter.format(laporan.labaBersih.abs())}',
                      style: AppTypography.labelMedium.copyWith(
                        color: warnaLaba,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (perMinggu.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Belum ada transaksi pada periode ini.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final entry in perMinggu.entries) ...[
                    _KartuMinggu(
                      nomor: entry.key,
                      transaksi: entry.value,
                      terbuka: _mingguTerbuka.contains(entry.key),
                      onToggle: () => setState(() {
                        _mingguTerbuka.contains(entry.key)
                            ? _mingguTerbuka.remove(entry.key)
                            : _mingguTerbuka.add(entry.key);
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KartuMinggu extends StatelessWidget {
  const _KartuMinggu({
    required this.nomor,
    required this.transaksi,
    required this.terbuka,
    required this.onToggle,
  });

  final int nomor;
  final List<TransactionItem> transaksi;
  final bool terbuka;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final int masuk = transaksi
        .where((item) => item.type == TransactionType.masuk)
        .fold(0, (total, item) => total + item.nominal);
    final int keluar = transaksi
        .where((item) => item.type == TransactionType.keluar)
        .fold(0, (total, item) => total + item.nominal);
    final int laba = masuk - keluar;
    final Color warnaLaba = laba >= 0 ? AppColors.primary700 : AppColors.tertiary700;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: terbuka,
            label: 'Minggu $nomor, ${transaksi.length} transaksi',
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      terbuka
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.chevron_right_rounded,
                      size: 26,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Minggu $nomor', style: AppTypography.titleSmall),
                          Text('${transaksi.length} transaksi', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Laba', style: AppTypography.bodySmall),
                        Text(
                          '${laba >= 0 ? '+' : '-'}${CurrencyFormatter.format(laba.abs())}',
                          style: AppTypography.labelMedium.copyWith(
                            color: warnaLaba,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (terbuka) ...[
            const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: transaksi
                    .map((item) => _RincianTransaksi(item: item))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RincianTransaksi extends StatelessWidget {
  const _RincianTransaksi({required this.item});

  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final bool masuk = item.type == TransactionType.masuk;
    final Color warna = masuk ? AppColors.primary700 : AppColors.tertiary700;
    final String jenis = masuk ? 'Pemasukkan' : 'Pengeluaran';
    final DateTime tanggal = item.occurredAt.toLocal();

    return Semantics(
      label: '${item.title}, $jenis, ${CurrencyFormatter.spoken(item.nominal)}, ${DateFormatter.dateWithMonth(tanggal)}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTypography.labelMedium),
                  const SizedBox(height: 3),
                  Text(
                    '${tanggal.day} ${_namaBulanSingkat(tanggal.month)} · ${item.kategori}',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${masuk ? '+' : '-'}${CurrencyFormatter.format(item.nominal)}',
                  style: AppTypography.labelMedium.copyWith(
                    color: warna,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(jenis, style: AppTypography.bodySmall.copyWith(color: warna)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _namaBulanSingkat(int bulan) {
    const List<String> nama = <String>[
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return nama[bulan];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
*/

// ─────────────────────────────────────────────────────────────────────────────
// Kartu Seksi Keuangan (Pendapatan / Beban Biaya)
// ─────────────────────────────────────────────────────────────────────────────
class _SeksiKeuangan extends StatelessWidget { // kartu tampilan Pendapatan/Beban dengan daftar kategori
  final String judul; // judul kartu (mis. "Pendapatan")
  final String subjudul; // subjudul kartu (mis. "Hasil penjualan")
  final int total; // total nominal kartu ini
  final Color totalWarna; // warna teks nominal total
  final IconData icon; // ikon kategori kartu
  final Color iconBgColor; // warna latar lingkaran ikon
  final Color iconColor; // warna ikon & garis tepinya
  final List<RincianKategori> rincian; // daftar kategori beserta detailnya
  final Color dotWarna; // warna titik penanda tiap kategori

  const _SeksiKeuangan({ // konstruktor, semua field wajib diisi
    required this.judul,
    required this.subjudul,
    required this.total,
    required this.totalWarna,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.rincian,
    required this.dotWarna,
  });

  @override
  Widget build(BuildContext context) { // bangun tampilan kartu ini
    return Container( // bungkus dengan kartu bertepi & sudut membulat
      width: double.infinity, // lebar penuh
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.warnaGaris),
      ),
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────────
          // Header tidak lagi jadi tombol buka-tutup. Sebelumnya satu
          // tombol ini menyembunyikan SELURUH kategori sekaligus —
          // padahal daftar kategori seharusnya selalu terlihat, dan
          // yang perlu bisa disembunyikan hanyalah transaksi di dalam
          // tiap kategori, satu per satu.
          Semantics( // info aksesibilitas untuk header kartu
            header: true, // judul bagian, bisa dilompati lewat navigasi Judul TalkBack
            label: '$judul. Total ${CurrencyFormatter.spoken(total)}. ' // label lengkap yang diucapkan pembaca layar
                '${rincian.length} kategori.',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  // Ikon kategori
                  Container( // lingkaran ikon kategori
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                      // Tanpa garis tepi, lingkaran ini nyaris menyatu
                      // dengan latar kartu di mode gelap — latarnya
                      // sengaja gelap juga (lihat catatan warnaMasuk/
                      // warnaKeluar), sehingga butuh batas eksplisit
                      // supaya tetap terlihat sebagai lingkaran.
                      border: Border.all(color: iconColor, width: 1.5), // garis tepi agar lingkaran tetap terlihat
                    ),
                    child: Icon(icon, color: iconColor, size: 22), // ikon di tengah lingkaran
                  ),
                  const SizedBox(width: 12), // jarak horizontal
                  // Judul & subjudul
                  Expanded( // isi sisa ruang horizontal
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul, // teks judul kartu
                          style: AppTypography.titleMedium.copyWith(
                            color: context.warnaTeksUtama,
                          ),
                        ),
                        const SizedBox(height: 2), // jarak kecil
                        Text(
                          subjudul, // teks subjudul kartu
                          style: AppTypography.bodySmall.copyWith(
                            color: context.warnaTeksMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(total), // total dalam format Rupiah
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: totalWarna,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Daftar kategori ──────────────────────────────────────
          // Setiap kategori adalah baris sendiri yang selalu tampil.
          // Transaksi di dalamnya baru muncul kalau baris kategori itu
          // diketuk, dan itu tidak memengaruhi kategori lain.
          if (rincian.isNotEmpty) ...[ // hanya tampilkan daftar jika ada kategori
            Divider(height: 1, color: context.warnaGaris), // garis pemisah
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  for (final kategori in rincian) ...[ // ulangi untuk tiap kategori
                    _KategoriRincianTile( // baris satu kategori
                      kategori: kategori,
                      dotWarna: dotWarna,
                    ),
                    if (kategori != rincian.last) // beri garis kecuali kategori terakhir
                      Divider(height: 18, color: context.warnaGaris),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Satu baris kategori dalam kartu Pendapatan/Beban Biaya.
///
/// Daftar transaksinya bisa dibuka-tutup sendiri, terpisah dari
/// kategori lain di kartu yang sama.
class _KategoriRincianTile extends StatefulWidget { // baris kategori yang bisa dibuka-tutup
  final RincianKategori kategori; // data kategori & transaksinya
  final Color dotWarna; // warna titik penanda kategori

  const _KategoriRincianTile({
    required this.kategori,
    required this.dotWarna,
  });

  @override
  State<_KategoriRincianTile> createState() => _KategoriRincianTileState(); // buat state terkait
}

class _KategoriRincianTileState extends State<_KategoriRincianTile> {
  bool _terbuka = false; // status apakah daftar transaksi sedang terbuka

  // Kategori dari data lama mungkin belum menyimpan daftar
  // transaksinya, jadi tidak ada apa pun untuk dibuka.
  bool get _bisaBuka => widget.kategori.transaksi.isNotEmpty; // hanya bisa dibuka jika ada transaksi

  @override
  Widget build(BuildContext context) {
    final RincianKategori kategori = widget.kategori; // ambil data kategori dari widget

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: _bisaBuka, // hanya berperan sebagai tombol jika bisa dibuka
          expanded: _terbuka, // beri tahu status terbuka/tertutup
          label: 'Kategori ${kategori.nama}, total ' // label lengkap untuk pembaca layar
              '${CurrencyFormatter.spoken(kategori.total)}, '
              '${kategori.jumlahTransaksi} transaksi.',
          hint: _bisaBuka // petunjuk aksi sesuai status buka/tutup
              ? (_terbuka
                  ? 'Ketuk dua kali untuk menyembunyikan transaksi'
                  : 'Ketuk dua kali untuk menampilkan transaksi')
              : null,
          // onTap dipasang di simpul semantik ini sendiri, bukan
          // hanya di InkWell, supaya TalkBack bisa membuka DAN
          // menutup baris ini lewat ketuk dua kali.
          onTap: // aksi ketuk semantik: buka/tutup daftar transaksi
              _bisaBuka ? () => setState(() => _terbuka = !_terbuka) : null,
          excludeSemantics: true,
          child: InkWell( // efek ripple visual
            onTap: // toggle buka/tutup daftar transaksi
                _bisaBuka ? () => setState(() => _terbuka = !_terbuka) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container( // titik warna kecil penanda kategori
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: widget.dotWarna,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8), // jarak horizontal
                  Expanded(
                    child: Text(
                      kategori.nama, // nama kategori
                      style: AppTypography.bodySmall.copyWith(
                        color: context.warnaTeksUtama,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(kategori.total), // total kategori dalam Rupiah
                    style: AppTypography.bodySmall.copyWith(
                      color: context.warnaTeksUtama,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_bisaBuka) ...[ // tampilkan panah hanya jika bisa dibuka
                    const SizedBox(width: 4),
                    Icon(
                      _terbuka // panah arah sesuai status buka/tutup
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: context.warnaTeksMuted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_terbuka) // tampilkan daftar transaksi hanya jika terbuka
          Padding(
            padding: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
            child: Column(
              children: [
                for (final transaksi in kategori.transaksi) // ulangi untuk tiap transaksi
                  Semantics(
                    label: '${transaksi.title}. ' // label lengkap transaksi untuk pembaca layar
                        '${DateFormatter.dateWithMonth(transaksi.occurredAt.toLocal())}. '
                        '${transaksi.method}. '
                        '${CurrencyFormatter.spoken(transaksi.nominal)}.',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaksi.title, // judul transaksi
                                  style: AppTypography.labelMedium.copyWith(
                                    color: context.warnaTeksUtama,
                                  ),
                                ),
                                const SizedBox(height: 2), // jarak kecil
                                Text(
                                  '${DateFormatter.short(transaksi.occurredAt.toLocal())} · ${transaksi.method}', // tanggal singkat & metode
                                  style: AppTypography.bodySmall.copyWith(
                                    color: context.warnaTeksMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(transaksi.nominal), // nominal transaksi dalam Rupiah
                            style: AppTypography.bodySmall.copyWith(
                              color: context.warnaTeksUtama,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bagian Asisten Keuangan  –  pakai AiAssistantBanner yang sama dengan dashboard
// ─────────────────────────────────────────────────────────────────────────────
class _AsistenKeuanganSection extends StatelessWidget { // bagian ajakan pakai asisten AI
  const _AsistenKeuanganSection({
    required this.tahun,
    required this.bulan,
    required this.repo,
  });

  final int tahun;
  final int bulan;
  final LaporanRepository repo;
  const _AsistenKeuanganSection({required this.laporan});

  final LaporanBulanan laporan; // laporan bulan yang sedang dibuka, untuk dianalisis AI

  @override
  Widget build(BuildContext context) {
    return AiAssistantBanner( // banner ajakan analisis/chat dengan AI
      onAnalysisTap: () async { 
        // 1. Tampilkan dialog loading saat menyiapkan data laporan untuk AI
        showDialog(
          context: context,
          barrierDismissible: false, // dialog tidak bisa ditutup dengan ketuk di luar
          builder: (context) => const Center(
            child: CircularProgressIndicator(), // tampilkan indikator loading
          ),
        ); 
        
        // 2. Panggil fungsi analisis laba rugi dari repository
        final String hasilAnalisis = await repo.analisisLaporanDenganGemini(
          tahun: tahun,
          bulan: bulan,
        );

        // 3. Tutup dialog loading
        if (context.mounted) Navigator.pop(context);

        // 4. Tampilkan hasil analisis dari Gemini dalam kotak dialog popup
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Analisis Keuangan AI'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Text(
                    hasilAnalisis,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          );
        }
      },
      onAnalysisTap: () => tampilkanAnalisisAi(context, laporan), // minta saran AI untuk bulan ini
      // Chat masih dummy, jadi tetap membuka halaman asisten.
      onChatTap: () => Navigator.push( // buka halaman asisten AI saat "Chat" ditekan
        context,
        buatRute((_) => const AiAssistantPage()),
      ),
    );
  }
}
      
// ─────────────────────────────────────────────────────────────────────────────
// Dialog Pilih Bulan
// ─────────────────────────────────────────────────────────────────────────────
class _MonthPickerDialog extends StatefulWidget { // dialog pemilih bulan & tahun
  final DateTime initialDate; // tanggal awal saat dialog dibuka
  const _MonthPickerDialog({required this.initialDate});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState(); // buat state terkait
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
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
            GridView.count( // grid 12 bulan
              crossAxisCount: 4, // 4 kolom
              shrinkWrap: true, // tinggi menyesuaikan isi
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.4, // rasio lebar:tinggi tiap sel
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
