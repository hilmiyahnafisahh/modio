import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../../core/navigation/app_route.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/transaction_model.dart';
import '../../data/transaksi_repository.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/voice_transaction_flow.dart';
import 'transaction_detail_page.dart';

/// ─────────────────────────────────────────────────────────────────
/// HISTORY PAGE  –  Riwayat transaksi lengkap
///
/// Berbeda dari dashboard yang hanya menampilkan lima transaksi
/// terbaru, halaman ini memuat seluruh riwayat dan menyediakan
/// penyaringan berdasarkan periode, jenis, dan kata kunci.
/// ─────────────────────────────────────────────────────────────────

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TransaksiRepository _repo = TransaksiRepository();
  final TextEditingController _cariCtrl = TextEditingController();

  late Future<List<TransactionItem>> _transaksi;

  PeriodeFilter _periode = PeriodeFilter.semua;

  /// Tanggal spesifik hasil pilih di kalender. Diisi berarti mengganti
  /// [_periode] sepenuhnya — beda dari preset yang selalu relatif
  /// terhadap sekarang, ini bisa hari mana pun di masa lalu.
  DateTime? _tanggalKhusus;

  TransactionType? _jenis; // null berarti semua jenis

  /// Label periode yang sedang aktif, ditampilkan di tombol pemilih.
  String get _labelPeriode => _tanggalKhusus != null
      ? DateFormatter.dateWithMonth(_tanggalKhusus!)
      : _periode.label;

  /// Label jenis transaksi yang sedang aktif, ditampilkan di tombol
  /// pemilih jenis.
  String get _labelJenis => switch (_jenis) {
        null => 'Semua transaksi',
        TransactionType.masuk => 'Masuk',
        TransactionType.keluar => 'Keluar',
      };

  @override
  void initState() {
    super.initState();
    _muat();
  }

  @override
  void dispose() {
    _cariCtrl.dispose();
    super.dispose();
  }

  void _muat() {
    setState(() {
      // batas null: seluruh riwayat, bukan hanya sebagian.
      _transaksi = _repo.riwayat(
        batas: null,
        periode: _periode,
        tanggalKhusus: _tanggalKhusus,
        type: _jenis,
        cari: _cariCtrl.text,
      );
    });
  }

  /// Mengumumkan hasil penyaringan lewat pembaca layar.
  ///
  /// Pengguna tunanetra tidak bisa melihat daftar berubah setelah
  /// menekan filter. Tanpa pengumuman, ia tidak punya cara mengetahui
  /// apakah filter benar-benar diterapkan.
  Future<void> _umumkanHasil() async {
    final List<TransactionItem> daftar = await _transaksi;
    if (!mounted) return;

    final total = _repo.hitungTotal(daftar);
    final String pesan = daftar.isEmpty
        ? '$_labelPeriode. Tidak ada transaksi.'
        : '$_labelPeriode. ${daftar.length} transaksi. '
            'Masuk ${CurrencyFormatter.spoken(total.masuk)}, '
            'keluar ${CurrencyFormatter.spoken(total.keluar)}.';

    SemanticsService.sendAnnouncement(View.of(context), pesan, Directionality.of(context));
  }

  /// Menerapkan preset (Hari ini/Minggu ini/Bulan ini/Semua) — menghapus
  /// tanggal khusus yang mungkin sedang aktif, sebab keduanya saling
  /// meniadakan.
  void _terapkanPreset(PeriodeFilter p) {
    setState(() {
      _periode = p;
      _tanggalKhusus = null;
    });
    _muat();
    _umumkanHasil();
  }

  /// Menerapkan tanggal spesifik hasil pilih di kalender.
  void _terapkanTanggal(DateTime tanggal) {
    setState(() {
      _tanggalKhusus = tanggal;
      _periode = PeriodeFilter.semua;
    });
    _muat();
    _umumkanHasil();
  }

  Future<void> _bukaPeriodeDialog() async {
    final _PeriodeHasil? hasil = await showDialog<_PeriodeHasil>(
      context: context,
      builder: (_) => _PeriodeDialog(
        periodeAktif: _periode,
        tanggalAktif: _tanggalKhusus,
      ),
    );
    if (hasil == null) return;
    if (hasil.preset != null) {
      _terapkanPreset(hasil.preset!);
    } else if (hasil.tanggal != null) {
      _terapkanTanggal(hasil.tanggal!);
    }
  }

  void _ubahJenis(TransactionType? j) {
    setState(() => _jenis = j);
    _muat();
    _umumkanHasil();
  }

  /// Tombol pemilih periode: ikon kalender + label + panah bawah.
  Widget _buildTombolPeriode() {
    return Semantics(
      button: true,
      label: 'Pilih periode: $_labelPeriode',
      hint: 'Ketuk dua kali untuk memilih periode lewat kalender',
      onTap: _bukaPeriodeDialog,
      excludeSemantics: true,
      child: InkWell(
        onTap: _bukaPeriodeDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: context.warnaKartu,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.warnaGaris),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: context.warnaTeksMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _labelPeriode,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: context.warnaTeksUtama,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.warnaTeksMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tombol pemilih jenis transaksi (Semua transaksi/Masuk/Keluar),
  /// sejajar di sebelah tombol periode. Menggantikan tiga chip
  /// terpisah — satu tombol dropdown, sama seperti acuan desain yang
  /// diminta.
  Widget _buildTombolJenis() {
    // PopupMenuButton<T> BUKAN PopupMenuButton<TransactionType?> — nilai
    // null punya arti khusus bagi PopupMenuButton: showMenu() memakai
    // null sebagai penanda "menu ditutup tanpa memilih apa pun", jadi
    // item bernilai null literal TIDAK PERNAH memicu onSelected sama
    // sekali. Itu sebabnya "Semua transaksi" tidak berefek. String
    // penanda ('semua') di sini, lalu dipetakan ke TransactionType?
    // secara manual, menghindari tabrakan itu.
    return PopupMenuButton<String>(
      tooltip: 'Pilih jenis transaksi. Saat ini: $_labelJenis',
      onSelected: (String v) => _ubahJenis(
        switch (v) {
          'masuk' => TransactionType.masuk,
          'keluar' => TransactionType.keluar,
          _ => null,
        },
      ),
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'semua',
          child: Text('Semua transaksi'),
        ),
        PopupMenuItem<String>(
          value: 'masuk',
          child: Text('Masuk'),
        ),
        PopupMenuItem<String>(
          value: 'keluar',
          child: Text('Keluar'),
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: context.warnaKartu,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.warnaGaris),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _labelJenis,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: context.warnaTeksUtama,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: context.warnaTeksMuted,
            ),
          ],
        ),
      ),
    );
  }

  /// Group transaksi berdasarkan tanggal
  Map<String, List<TransactionItem>> _grupTransaksiByTanggal(List<TransactionItem> daftar) {
    final Map<String, List<TransactionItem>> grouped = {};
    final DateTime now = DateTime.now();
    final DateTime kemarin = now.subtract(const Duration(days: 1));

    for (final trx in daftar) {
      final DateTime tgl = trx.occurredAt.toLocal();
      final isSameDay = tgl.year == now.year && tgl.month == now.month && tgl.day == now.day;
      final isSameYesterday = tgl.year == kemarin.year && tgl.month == kemarin.month && tgl.day == kemarin.day;

      String label;
      if (isSameDay) {
        label = 'Hari Ini';
      } else if (isSameYesterday) {
        label = 'Kemarin';
      } else {
        label = DateFormatter.dateWithMonth(tgl); // e.g. "14 September 2025"
      }

      grouped.putIfAbsent(label, () => []);
      grouped[label]!.add(trx);
    }

    return grouped;
  }

  /// Build grouped transaction list dengan date headers.
  ///
  /// Column biasa, bukan ListView.builder — daftar ini sekarang ikut
  /// bergulir sebagai bagian dari satu halaman (lewat CustomScrollView
  /// di build()), bukan area scroll tersendiri, jadi tidak perlu
  /// viewport lazy-loading sendiri.
  Widget _buildGroupedTransactionList(List<TransactionItem> daftar) {
    final grouped = _grupTransaksiByTanggal(daftar);
    final sortedKeys = grouped.keys.toList();
    // Sort dengan "Hari Ini" dan "Kemarin" paling atas
    sortedKeys.sort((a, b) {
      if (a == 'Hari Ini') return -1;
      if (b == 'Hari Ini') return 1;
      if (a == 'Kemarin') return -1;
      if (b == 'Kemarin') return 1;
      // Sort sisanya by tanggal descending (paling baru duluan)
      return b.compareTo(a);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in sortedKeys) ...[
            // Padding atas 20 supaya tiap kelompok tanggal terasa
            // sebagai bagian terpisah, bukan menyambung rapat dengan
            // baris terakhir kelompok sebelumnya.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Text(
                key,
                style: AppTypography.labelSmall.copyWith(
                  color: context.warnaTeksMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (int i = 0; i < grouped[key]!.length; i++) ...[
              TransactionTile(
                item: grouped[key]![i],
                onTap: () => _bukaDetail(grouped[key]![i]),
              ),
              if (i < grouped[key]!.length - 1)
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
  Future<void> _bukaDetail(TransactionItem item) async {
    final bool? berubah = await Navigator.push<bool>(
      context,
      buatRute((_) => TransactionDetailPage(item: item)),
    );
    if (berubah == true && mounted) {
      _muat();
    }
  }

  Future<void> _handleVoiceInput() async {
    final bool? tersimpan = await mulaiCatatTransaksiSuara(context);
    if (tersimpan == true && mounted) _muat();
  }

  @override
  Widget build(BuildContext context) {
    // Tinggi header periode dihitung dari skala teks aktif, bukan
    // angka tetap. SliverPersistentHeader wajib tahu tingginya di
    // muka (tidak bisa "menyesuaikan isi" seperti Container biasa) —
    // kalau tingginya dipatok pada satu nilai, tombol periode akan
    // terpotong saat ukuran teks sistem dimaksimalkan, persis masalah
    // yang sebelumnya bikin bagian ini rusak. Skala ini memberi ruang
    // ekstra sebanding pembesaran teks.
    final double tinggiHeaderPeriode =
        MediaQuery.textScalerOf(context).scale(48.0).clamp(48.0, 96.0);

    final scheme = Theme.of(context).colorScheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            context.gelap ? Brightness.light : Brightness.dark,
        statusBarBrightness: context.gelap ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: SizedBox(
        width: 64,
        height: 64,
        child: FloatingActionButton(
        heroTag: 'fab_history',
        onPressed: _handleVoiceInput,
        backgroundColor: scheme.primary,
        elevation: 4,
        shape: const CircleBorder(),
        tooltip: 'Catat transaksi dengan suara',
        // Semantics eksplisit, bukan cuma mengandalkan tooltip.
        // Tanpa label ini pembaca layar hanya menyebutnya "tombol"
        // tanpa keterangan, tak terbedakan dari tombol tambah lain.
        child: Semantics(
          button: true,
          label: 'Catat transaksi dengan suara',
          excludeSemantics: true,
          child: Icon(
            Icons.mic_rounded,
            color: scheme.onPrimary,
            size: 30,
          ),
        ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _muat(),
          // Satu CustomScrollView untuk seluruh halaman — judul,
          // pencarian, filter jenis, ringkasan, dan daftar transaksi
          // bergulir bersama sebagai satu kesatuan. Satu-satunya yang
          // tetap di tempat adalah tombol pemilih periode, lewat
          // SliverPersistentHeader(pinned: true) di bawah ini.
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),
                      Text(
                        'Riwayat Transaksi',
                        style: AppTypography.headingMedium.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Pencarian ───────────────────────────────
                      TextField(
                        controller: _cariCtrl,
                        onSubmitted: (_) {
                          _muat();
                          _umumkanHasil();
                        },
                        style: AppTypography.bodyLarge.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari nama atau kategori',
                          prefixIcon: Icon(
                            Icons.search,
                            color: context.warnaTeksMuted,
                          ),
                          suffixIcon: _cariCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Hapus pencarian',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _cariCtrl.clear();
                                    _muat();
                                  },
                                ),
                          filled: true,
                          fillColor: context.warnaKartu,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(color: context.warnaGaris),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(color: context.warnaGaris),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(26),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── Filter periode + jenis — bagian yang menempel ────
              // Dua tombol sejajar dalam satu baris, sama tinggi
              // (Expanded 50/50) — menggantikan tombol periode sendiri
              // di atas deretan tiga chip jenis. Keduanya kini menempel
              // saat halaman digulir, bukan cuma periode.
              SliverPersistentHeader(
                pinned: true,
                delegate: _PeriodeHeaderDelegate(
                  height: tinggiHeaderPeriode,
                  child: Container(
                    // Latar wajib buram: konten lain meluncur di
                    // baliknya saat halaman digulir, tanpa latar ini
                    // akan tembus pandang bertumpuk dengan header.
                    color: Theme.of(context).scaffoldBackgroundColor,
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                    child: Row(
                      children: [
                        Expanded(child: _buildTombolPeriode()),
                        const SizedBox(width: 10),
                        Expanded(child: _buildTombolJenis()),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Ringkasan + daftar transaksi ────────────────────
              SliverToBoxAdapter(
                child: FutureBuilder<List<TransactionItem>>(
                  future: _transaksi,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
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

                    final List<TransactionItem> daftar =
                        snapshot.data ?? const <TransactionItem>[];

                    if (daftar.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            _periode == PeriodeFilter.semua &&
                                    _tanggalKhusus == null &&
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
                              '${daftar.length} transaksi',
                              style: AppTypography.labelMedium.copyWith(
                                color: context.warnaTeksMuted,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: context.warnaKartu,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                              border: Border.all(color: context.warnaGaris),
                            ),
                            child: _buildGroupedTransactionList(daftar),
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
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
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
class _PeriodeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _PeriodeHeaderDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PeriodeHeaderDelegate oldDelegate) => true;
}


/// Tombol filter berbentuk chip. Dipakai untuk preset periode di
/// [_PeriodeDialog].
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.terpilih,
    required this.onTap,
  });

  final String label;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: terpilih,
      label: label,
      // Tanpa onTap di sini, simpulnya diumumkan sebagai tombol tetapi
      // tidak punya aksi yang bisa dijalankan TalkBack.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: terpilih
                ? Theme.of(context).colorScheme.primary
                : context.warnaKartu,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: terpilih
                  ? Theme.of(context).colorScheme.primary
                  : context.warnaGaris,
              // Ketebalan garis ikut membedakan, bukan hanya warna.
              width: terpilih ? 2 : 1,
            ),
          ),
          // Bukan Center: di dalam Row/ListView horizontal, Align/Center
          // menerima lebar TAK TERBATAS dari induknya sehingga otomatis
          // menyusut mengikuti ukuran teks. Tapi di dalam Wrap, lebar
          // yang diterima TERBATAS (sebesar lebar Wrap), dan Align/Center
          // pada kondisi itu justru melebar mengisi seluruh ruang —
          // itulah yang membuat setiap chip melebar sepanjang layar
          // begitu filter periode/jenis dipindah ke Wrap.
          //
          // Row(mainAxisSize: min) selalu menyusut mengikuti lebar
          // teksnya sendiri di kedua jenis induk, sekaligus tetap
          // menengahkan teks secara vertikal (lewat crossAxisAlignment
          // bawaan) saat minHeight kartu lebih besar dari kebutuhan teks.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: terpilih
                    ? AppTypography.labelMedium.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      )
                    : AppTypography.labelMedium.copyWith(
                        color: context.warnaTeksUtama,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hasil pilihan dari [_PeriodeDialog]: salah satu dari preset relatif
/// atau tanggal spesifik, tidak pernah keduanya sekaligus.
class _PeriodeHasil {
  final PeriodeFilter? preset;
  final DateTime? tanggal;

  const _PeriodeHasil.preset(PeriodeFilter p)
      : preset = p,
        tanggal = null;

  const _PeriodeHasil.tanggal(DateTime t)
      : preset = null,
        tanggal = t;
}

/// Dialog pemilih periode: preset cepat (Hari ini/Minggu ini/Bulan
/// ini/Semua) di atas, dan kalender bulanan di bawah untuk memilih
/// tanggal tertentu di masa lalu — supaya rentang yang sedang dilihat
/// selalu jelas, bukan sekadar label abstrak.
class _PeriodeDialog extends StatefulWidget {
  final PeriodeFilter periodeAktif;
  final DateTime? tanggalAktif;

  const _PeriodeDialog({
    required this.periodeAktif,
    required this.tanggalAktif,
  });

  @override
  State<_PeriodeDialog> createState() => _PeriodeDialogState();
}

class _PeriodeDialogState extends State<_PeriodeDialog> {
  late DateTime _bulanTampil;

  static const List<String> _namaHari = [
    'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
  ];
  static const List<String> _namaBulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    // Kalender terbuka menampilkan bulan dari tanggal yang sedang
    // aktif (kalau ada), bukan selalu bulan sekarang — supaya
    // konsisten dengan apa yang sedang dilihat pengguna.
    final DateTime acuan = widget.tanggalAktif ?? DateTime.now();
    _bulanTampil = DateTime(acuan.year, acuan.month);
  }

  bool get _bulanTampilAdalahSekarang {
    final DateTime now = DateTime.now();
    return _bulanTampil.year == now.year && _bulanTampil.month == now.month;
  }

  void _gantiBulan(int delta) {
    setState(() {
      _bulanTampil = DateTime(_bulanTampil.year, _bulanTampil.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pilih Periode',
              style: AppTypography.titleMedium.copyWith(
                color: context.warnaTeksUtama,
              ),
            ),
            const SizedBox(height: 14),

            // ── Preset cepat ─────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final PeriodeFilter p in PeriodeFilter.values)
                  _Chip(
                    label: p.label,
                    terpilih:
                        widget.tanggalAktif == null && widget.periodeAktif == p,
                    onTap: () =>
                        Navigator.pop(context, _PeriodeHasil.preset(p)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: context.warnaGaris),
            const SizedBox(height: 14),

            // ── Atau tanggal spesifik ────────────────────────────
            Text(
              'Atau pilih tanggal',
              style: AppTypography.labelSmall.copyWith(
                color: context.warnaTeksUtama,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Semantics(
                  button: true,
                  label: 'Bulan sebelumnya',
                  onTap: () => _gantiBulan(-1),
                  excludeSemantics: true,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _gantiBulan(-1),
                  ),
                ),
                Flexible(
                  child: Text(
                    '${_namaBulan[_bulanTampil.month]} ${_bulanTampil.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Bulan berikutnya',
                  enabled: !_bulanTampilAdalahSekarang,
                  onTap:
                      _bulanTampilAdalahSekarang ? null : () => _gantiBulan(1),
                  excludeSemantics: true,
                  child: IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    // Bulan depan belum punya transaksi apa pun, jadi
                    // navigasi ke sana dinonaktifkan.
                    onPressed:
                        _bulanTampilAdalahSekarang ? null : () => _gantiBulan(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            Row(
              children: [
                for (final String h in _namaHari)
                  Expanded(
                    child: Center(
                      child: Text(
                        h,
                        style: AppTypography.captionSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.warnaTeksMuted,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            _buildGridTanggal(),

            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: TextStyle(color: context.warnaTeksMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridTanggal() {
    final DateTime firstDay = DateTime(_bulanTampil.year, _bulanTampil.month, 1);
    final int jumlahHari =
        DateTime(_bulanTampil.year, _bulanTampil.month + 1, 0).day;
    // weekday: Senin = 1 ... Minggu = 7, sehingga offset 0 saat tanggal
    // 1 jatuh pada hari Senin.
    final int offset = firstDay.weekday - 1;

    final DateTime now = DateTime.now();
    final DateTime hariIni = DateTime(now.year, now.month, now.day);
    final DateTime? terpilih = widget.tanggalAktif;

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (int i = 0; i < offset; i++) const SizedBox.shrink(),
        for (int d = 1; d <= jumlahHari; d++) _buildHari(d, hariIni, terpilih),
      ],
    );
  }

  Widget _buildHari(int hari, DateTime hariIni, DateTime? terpilih) {
    final DateTime tanggal = DateTime(_bulanTampil.year, _bulanTampil.month, hari);
    final bool isHariIni = tanggal == hariIni;
    final bool isTerpilih = terpilih != null &&
        terpilih.year == tanggal.year &&
        terpilih.month == tanggal.month &&
        terpilih.day == tanggal.day;
    // Transaksi tidak mungkin ada di masa depan, jadi tanggal itu
    // dinonaktifkan alih-alih ditampilkan seolah bisa dipilih.
    final bool isMasaDepan = tanggal.isAfter(hariIni);

    return Semantics(
      button: !isMasaDepan,
      selected: isTerpilih,
      label: '$hari ${_namaBulan[_bulanTampil.month]} ${_bulanTampil.year}'
          '${isHariIni ? ', hari ini' : ''}'
          '${isTerpilih ? ', dipilih' : ''}',
      onTap: isMasaDepan
          ? null
          : () => Navigator.pop(context, _PeriodeHasil.tanggal(tanggal)),
      excludeSemantics: true,
      child: InkWell(
        onTap: isMasaDepan
            ? null
            : () => Navigator.pop(context, _PeriodeHasil.tanggal(tanggal)),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isTerpilih
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isHariIni && !isTerpilih
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$hari',
            style: TextStyle(
              fontSize: 14,
              fontWeight:
                  isTerpilih || isHariIni ? FontWeight.w700 : FontWeight.w400,
              color: isMasaDepan
                  ? context.warnaTeksMuted.withValues(alpha: 0.4)
                  : (isTerpilih
                      ? Theme.of(context).colorScheme.onPrimary
                      : context.warnaTeksUtama),
            ),
          ),
        ),
      ),
    );
  }
}
