import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../../core/navigation/app_route.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/laporan_repository.dart';
import '../../data/report_model.dart';
import '../../../ai_chat/presentation/pages/ai_assistant_page.dart';
import '../../../dashboard/presentation/widgets/ai_assistant_banner.dart';
import '../../../dashboard/presentation/widgets/balance_card.dart';
import '../../../transactions/presentation/widgets/voice_transaction_flow.dart';

/// ─────────────────────────────────────────────────────────────────
/// REPORTS PAGE  –  Laporan keuangan bulanan
///
/// Tampilan sesuai desain: header dengan back button, period picker
/// berbasis kalender, kartu laba, rincian pendapatan & beban dengan
/// dot indicator, dan bagian Asisten Keuangan.
/// ─────────────────────────────────────────────────────────────────

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final LaporanRepository _repo = LaporanRepository();

  late Future<LaporanBulanan> _laporan;

  late int _tahun;
  late int _bulan;

  static const List<String> _namaBulanPanjang = [
    '',
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _tahun = now.year;
    _bulan = now.month;
    _muat();
  }

  void _muat() {
    setState(() {
      _laporan = _repo.laporanBulan(tahun: _tahun, bulan: _bulan);
    });
  }

  Future<void> _bukaKalender() async {
    final DateTime? result = await showDialog<DateTime>(
      context: context,
      builder: (_) => _MonthPickerDialog(
        initialDate: DateTime(_tahun, _bulan),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _tahun = result.year;
        _bulan = result.month;
      });
      _muat();
      final LaporanBulanan l = await _laporan;
      if (!mounted) return;
      SemanticsService.sendAnnouncement(View.of(context), l.narasi, Directionality.of(context));
    }
  }

  String get _labelPeriode => '${_namaBulanPanjang[_bulan]} $_tahun';

  Future<void> _handleVoiceInput() async {
    final bool? tersimpan = await mulaiCatatTransaksiSuara(context);
    if (tersimpan == true && mounted) _muat();
  }

  @override
  Widget build(BuildContext context) {
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
        heroTag: 'fab_reports',
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
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────
                _buildHeader(),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Disamakan dengan jarak header-ke-isi di halaman
                      // lain (Dashboard 20, History 16) — sebelumnya
                      // hanya 4, sehingga judul dan "Periode" terasa
                      // menempel.
                      const SizedBox(height: 20),

                      // ── Label Periode ────────────────────────
                      Text(
                        'Periode',
                        style: AppTypography.labelSmall.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Tombol Kalender ──────────────────────
                      _buildPeriodePicker(),
                      const SizedBox(height: 22),

                      // ── Konten Laporan ───────────────────────
                      FutureBuilder<LaporanBulanan>(
                        future: _laporan,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return SizedBox(
                              height: 300,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'Laporan tidak bisa dimuat. Tutup aplikasi '
                                'lalu buka lagi. Data Anda masih tersimpan.',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: context.warnaTeksUtama,
                                ),
                              ),
                            );
                          }
                          return _buildIsi(snapshot.data!);
                        },
                      ),

                      // 120: tinggi tombol mic (64) + jarak dari tepi
                      // bawah — tanpa ini konten terakhir tertutup
                      // separuh oleh tombol mic yang mengambang.
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
      child: Text(
        'Laporan Laba Rugi',
        style: AppTypography.headingMedium.copyWith(
          color: context.warnaTeksUtama,
        ),
      ),
    );
  }

  Widget _buildPeriodePicker() {
    return Semantics(
      button: true,
      label: 'Pilih periode: $_labelPeriode',
      hint: 'Ketuk dua kali untuk memilih bulan dan tahun',
      onTap: _bukaKalender,
      excludeSemantics: true,
      child: InkWell(
        onTap: _bukaKalender,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: context.warnaKartu,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.warnaGaris),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 18,
                color: context.warnaTeksMuted,
              ),
              const SizedBox(width: 8),
              Text(
                _labelPeriode,
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

  Widget _buildIsi(LaporanBulanan l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Kartu Laba Usaha ─────────────────────────────────
        // Widget yang sama dengan kartu Saldo di dashboard, agar
        // gaya visualnya senada — bukan kartu terpisah dengan
        // tampilan sendiri.
        BalanceCard(
          balance: l.labaBersih.abs(),
          period: l.labelPeriode,
          title: l.untung ? 'Laba Usaha' : 'Rugi',
        ),
        const SizedBox(height: 20),

        // ── Kartu Pendapatan ─────────────────────────────────
        _SeksiKeuangan(
          judul: 'Pendapatan',
          subjudul: 'Hasil penjualan',
          total: l.totalPendapatan,
          totalWarna: context.warnaMasuk,
          icon: Icons.arrow_outward_rounded,
          iconBgColor: context.latarMasuk,
          iconColor: context.warnaMasuk,
          rincian: l.rincianPendapatan,
          dotWarna: context.warnaMasuk,
        ),
        const SizedBox(height: 16),

        // ── Kartu Beban Biaya ────────────────────────────────
        _SeksiKeuangan(
          judul: 'Beban Biaya',
          subjudul: 'Biaya biaya yang keluar',
          total: l.totalBeban,
          totalWarna: context.warnaKeluar,
          icon: Icons.south_west_rounded,
          iconBgColor: context.latarKeluar,
          iconColor: context.warnaKeluar,
          rincian: l.rincianBeban,
          dotWarna: context.warnaKeluar,
        ),
        const SizedBox(height: 20),

        // ── Asisten Keuangan ─────────────────────────────────
        _AsistenKeuanganSection(),
      ],
    );
  }
}

/*
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
class _SeksiKeuangan extends StatelessWidget {
  final String judul;
  final String subjudul;
  final int total;
  final Color totalWarna;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final List<RincianKategori> rincian;
  final Color dotWarna;

  const _SeksiKeuangan({
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Semantics(
            label: '$judul. Total ${CurrencyFormatter.spoken(total)}. '
                '${rincian.length} kategori.',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Row(
                children: [
                  // Ikon kategori
                  Container(
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
                      border: Border.all(color: iconColor, width: 1.5),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  // Judul & subjudul
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          judul,
                          style: AppTypography.titleMedium.copyWith(
                            color: context.warnaTeksUtama,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subjudul,
                          style: AppTypography.bodySmall.copyWith(
                            color: context.warnaTeksMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(total),
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
          if (rincian.isNotEmpty) ...[
            Divider(height: 1, color: context.warnaGaris),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                children: [
                  for (final kategori in rincian) ...[
                    _KategoriRincianTile(
                      kategori: kategori,
                      dotWarna: dotWarna,
                    ),
                    if (kategori != rincian.last)
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
class _KategoriRincianTile extends StatefulWidget {
  final RincianKategori kategori;
  final Color dotWarna;

  const _KategoriRincianTile({
    required this.kategori,
    required this.dotWarna,
  });

  @override
  State<_KategoriRincianTile> createState() => _KategoriRincianTileState();
}

class _KategoriRincianTileState extends State<_KategoriRincianTile> {
  bool _terbuka = false;

  // Kategori dari data lama mungkin belum menyimpan daftar
  // transaksinya, jadi tidak ada apa pun untuk dibuka.
  bool get _bisaBuka => widget.kategori.transaksi.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final RincianKategori kategori = widget.kategori;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: _bisaBuka,
          expanded: _terbuka,
          label: 'Kategori ${kategori.nama}, total '
              '${CurrencyFormatter.spoken(kategori.total)}, '
              '${kategori.jumlahTransaksi} transaksi.',
          hint: _bisaBuka
              ? (_terbuka
                  ? 'Ketuk dua kali untuk menyembunyikan transaksi'
                  : 'Ketuk dua kali untuk menampilkan transaksi')
              : null,
          // onTap dipasang di simpul semantik ini sendiri, bukan
          // hanya di InkWell, supaya TalkBack bisa membuka DAN
          // menutup baris ini lewat ketuk dua kali.
          onTap:
              _bisaBuka ? () => setState(() => _terbuka = !_terbuka) : null,
          excludeSemantics: true,
          child: InkWell(
            onTap:
                _bisaBuka ? () => setState(() => _terbuka = !_terbuka) : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: widget.dotWarna,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      kategori.nama,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.warnaTeksUtama,
                      ),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(kategori.total),
                    style: AppTypography.bodySmall.copyWith(
                      color: context.warnaTeksUtama,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_bisaBuka) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _terbuka
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
        if (_terbuka)
          Padding(
            padding: const EdgeInsets.only(left: 17, top: 2, bottom: 2),
            child: Column(
              children: [
                for (final transaksi in kategori.transaksi)
                  Semantics(
                    label: '${transaksi.title}. '
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
                                  transaksi.title,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: context.warnaTeksUtama,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.short(transaksi.occurredAt.toLocal())} · ${transaksi.method}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: context.warnaTeksMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(transaksi.nominal),
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
// ignore: unused_element
class _AsistenKeuanganSection extends StatelessWidget {
  const _AsistenKeuanganSection();

  @override
  Widget build(BuildContext context) {
    return AiAssistantBanner(
      onAnalysisTap: () => Navigator.push(
        context,
        buatRute((_) => const AiAssistantPage()),
      ),
      onChatTap: () => Navigator.push(
        context,
        buatRute((_) => const AiAssistantPage()),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog Pilih Bulan
// ─────────────────────────────────────────────────────────────────────────────
class _MonthPickerDialog extends StatefulWidget {
  final DateTime initialDate;
  const _MonthPickerDialog({required this.initialDate});

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _tahun;
  late int _bulan;

  static const List<String> _singkat = [
    'Jan', 'Feb', 'Mar', 'Apr',
    'Mei', 'Jun', 'Jul', 'Agu',
    'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const List<String> _namaPanjang = [
    'Januari', 'Februari', 'Maret', 'April',
    'Mei', 'Juni', 'Juli', 'Agustus',
    'September', 'Oktober', 'November', 'Desember',
  ];

  @override
  void initState() {
    super.initState();
    _tahun = widget.initialDate.year;
    _bulan = widget.initialDate.month;

    // Dialog ini muncul di atas fokus TalkBack sebelumnya tanpa
    // konteks apa pun — tanpa pengumuman ini, fokus otomatis jatuh ke
    // tombol "Tahun sebelumnya" duluan dan pengguna tidak pernah
    // diberi tahu bulan/tahun apa yang sedang ditampilkan.
    // addPostFrameCallback dipakai karena View.of(context) baru valid
    // setelah frame pertama dialog ini selesai dirender.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Pilih bulan. Saat ini menampilkan ${_namaPanjang[_bulan - 1]} $_tahun.',
        Directionality.of(context),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final int tahunSekarang = DateTime.now().year;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Navigator tahun
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => setState(() => _tahun--),
                  tooltip: 'Tahun sebelumnya',
                ),
                Semantics(
                  header: true,
                  label: 'Tahun $_tahun',
                  excludeSemantics: true,
                  child: Text(
                    '$_tahun',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: _tahun < tahunSekarang
                      ? () => setState(() => _tahun++)
                      : null,
                  tooltip: 'Tahun berikutnya',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Grid bulan
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.4,
              children: List.generate(12, (i) {
                final int b = i + 1;
                final bool dipilih = b == _bulan;
                return Semantics(
                  button: true,
                  selected: dipilih,
                  label: '${_namaPanjang[i]}${dipilih ? ', dipilih' : ''}',
                  onTap: () => setState(() => _bulan = b),
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => _bulan = b),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: dipilih
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _singkat[i],
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
            const SizedBox(height: 16),

            // Tombol aksi
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Batal',
                      style: TextStyle(color: context.warnaTeksMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () =>
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
