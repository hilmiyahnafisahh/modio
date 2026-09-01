import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/transaction_model.dart';
import '../../data/transaksi_repository.dart';
import '../widgets/record_transaction_modal.dart';

/// ─────────────────────────────────────────────────────────────────
/// TRANSACTION DETAIL PAGE  –  Rincian satu transaksi
///
/// Dibuka dengan mengetuk baris mana pun di daftar riwayat — tombol
/// titik tiga dihapus, seluruh baris jadi satu target sentuh. Aksi
/// Edit dan Hapus ada di satu tempat yang jelas di sini, bukan
/// tersembunyi di menu kecil yang mudah terlewat pengguna tunanetra.
/// ─────────────────────────────────────────────────────────────────

class TransactionDetailPage extends StatefulWidget {
  final TransactionItem item;

  const TransactionDetailPage({super.key, required this.item});

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  final _repo = TransaksiRepository();
  late TransactionItem _item;

  /// true kalau data sempat diubah (edit) atau dihapus — dipakai
  /// pemanggil (halaman riwayat) untuk tahu apakah daftarnya perlu
  /// dimuat ulang.
  bool _berubah = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  bool get _isMasuk => _item.type == TransactionType.masuk;

  Color get _warna => _isMasuk ? context.warnaMasuk : context.warnaKeluar;

  Future<void> _edit() async {
    final bool? tersimpan = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordTransactionModal(existingItem: _item),
    );
    if (tersimpan != true || !mounted) return;

    // Ambil ulang transaksi ini dari basis data supaya halaman detail
    // menampilkan hasil perubahan, bukan data lama yang masih di memori.
    final List<TransactionItem> semua = await _repo.riwayat(batas: null);
    final Iterable<TransactionItem> cocok =
        semua.where((t) => t.id == _item.id);
    if (cocok.isEmpty || !mounted) return;

    setState(() {
      _item = cocok.first;
      _berubah = true;
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Detail diperbarui. ${_item.narasi}',
      Directionality.of(context),
    );
  }

  Future<void> _hapus() async {
    final bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus transaksi ini?',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: dialogContext.warnaTeksUtama,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus transaksi ini? '
          'Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(
            fontSize: 15,
            color: dialogContext.warnaTeksMuted,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: dialogContext.warnaTeksMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Hapus',
              style: TextStyle(
                color: dialogContext.warnaKeluar,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (konfirmasi != true || !mounted) return;

    try {
      await _repo.hapus(_item.id);
      if (!mounted) return;
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Transaksi dihapus.',
        Directionality.of(context),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi belum bisa dihapus. Coba lagi.'),
        ),
      );
    }
  }

  String _kapital(String s) =>
      s.trim().isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    // canPop: false + pop manual di sini supaya tombol back sistem
    // (gesture/tombol fisik) ikut mengembalikan _berubah ke halaman
    // riwayat, sama seperti tombol back kustom di header — bukan cuma
    // menutup halaman tanpa memberi tahu perlu dimuat ulang atau tidak.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        Navigator.pop(context, _berubah);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => Navigator.pop(context, _berubah),
                      tooltip: 'Kembali',
                      icon: Icon(
                        Icons.chevron_left,
                        size: 30,
                        color: context.warnaTeksUtama,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Detail Transaksi',
                      style: AppTypography.titleLarge.copyWith(
                        color: context.warnaTeksUtama,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Ringkasan atas: ikon, judul, arah ────────────
                      Semantics(
                        label: _item.narasi,
                        excludeSemantics: true,
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _isMasuk
                                    ? context.latarMasuk
                                    : context.latarKeluar,
                                shape: BoxShape.circle,
                                border: Border.all(color: _warna, width: 1.5),
                              ),
                              child: Icon(
                                _isMasuk
                                    ? Icons.north_east
                                    : Icons.south_west,
                                color: _warna,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _item.title,
                                    style: AppTypography.titleMedium.copyWith(
                                      color: context.warnaTeksUtama,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _isMasuk ? 'Pemasukan' : 'Pengeluaran',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: _warna,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${_isMasuk ? '+' : '-'}'
                        '${CurrencyFormatter.format(_item.nominal)}',
                        style: AppTypography.headingSmall.copyWith(
                          color: _warna,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Rincian field ─────────────────────────────
                      AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            AppInfoCard(
                              label: 'Tanggal',
                              value: DateFormatter.dateWithMonth(
                                _item.occurredAt.toLocal(),
                              ),
                            ),
                            Divider(height: 1, color: context.warnaGaris),
                            AppInfoCard(
                              label: 'Jam',
                              value: DateFormatter.time(
                                _item.occurredAt.toLocal(),
                              ),
                            ),
                            Divider(height: 1, color: context.warnaGaris),
                            AppInfoCard(
                              label: 'Jenis',
                              value: _isMasuk ? 'Pemasukan' : 'Pengeluaran',
                            ),
                            Divider(height: 1, color: context.warnaGaris),
                            AppInfoCard(
                              label: 'Metode bayar',
                              value: _kapital(_item.method),
                            ),
                            Divider(height: 1, color: context.warnaGaris),
                            AppInfoCard(
                              label: 'Kategori',
                              value: _item.kategori,
                            ),
                            if (_item.catatan != null &&
                                _item.catatan!.trim().isNotEmpty) ...[
                              Divider(
                                  height: 1, color: context.warnaGaris),
                              AppInfoCard(
                                label: 'Catatan',
                                value: _item.catatan!,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Aksi: Edit & Hapus ────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _edit,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              label: const Text('Edit'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                side: BorderSide(
                                  color: context.warnaMasuk,
                                  width: 1.5,
                                ),
                                foregroundColor: context.warnaMasuk,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _hapus,
                              icon:
                                  const Icon(Icons.delete_outline, size: 20),
                              label: const Text('Hapus'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(52),
                                side: BorderSide(
                                  color: context.warnaKeluar,
                                  width: 1.5,
                                ),
                                foregroundColor: context.warnaKeluar,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
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
