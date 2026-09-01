import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/transaction_model.dart';

/// ─────────────────────────────────────────────────────────────────
/// TRANSACTION TILE  –  Baris satu item transaksi
///
/// Seluruh baris adalah satu target sentuh menuju Detail Transaksi.
/// Tidak ada menu titik tiga terpisah — pengguna tunanetra tidak
/// perlu menemukan target kecil tersembunyi untuk membuka detail,
/// mengedit, atau menghapus; semua itu ada di halaman Detail.
///
/// Struktur baris:
///   Baris 1: [ikon] [Nama Transaksi]              [Nominal, 1 baris]
///   Baris 2: [Masuk/Keluar]  [waktu · metode bayar, 1 baris, abu-abu]
///
/// Cara pakai:
///   TransactionTile(item: transaksi, onTap: () { ... })
/// ─────────────────────────────────────────────────────────────────

class TransactionTile extends StatelessWidget {
  final TransactionItem item;

  /// Callback saat baris ditekan — biasanya membuka halaman Detail
  /// Transaksi.
  final VoidCallback? onTap;

  /// Tampilkan tanda plus atau minus di depan nominal
  final bool tampilkanTanda;

  const TransactionTile({
    super.key,
    required this.item,
    this.onTap,
    this.tampilkanTanda = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool isMasuk = item.type == TransactionType.masuk;

    // tertiary700, bukan tertiary500. Yang terakhir hanya mencapai
    // rasio 3,8:1 terhadap putih — gagal bahkan standar AA, padahal
    // dipakai untuk menampilkan nominal.
    final Color warna = isMasuk ? context.warnaMasuk : context.warnaKeluar;
    final Color latarIkon = isMasuk ? context.latarMasuk : context.latarKeluar;

    // Nominal dan label Masuk/Keluar memakai ukuran font tetap kecil
    // (bukan skala AppTypography yang lebih besar) supaya baris 1 dan
    // baris 2 selalu satu baris tanpa melipat, dan tinggi tiap item
    // jadi konsisten — bukan sekadar preferensi visual, ini yang
    // menjaga daftar tidak "melar" tidak beraturan antar baris.
    const TextStyle gayaNominal = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    const TextStyle gayaLabelArah = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    final TextStyle gayaMeta =
        AppTypography.captionLarge.copyWith(color: context.warnaTeksMuted);
    final TextStyle gayaJudul =
        AppTypography.titleSmall.copyWith(color: context.warnaTeksUtama);

    return Semantics(
      button: onTap != null,
      // Seluruh transaksi dibacakan sebagai satu kalimat, termasuk
      // petunjuk bahwa mengetuknya membuka detail. Tanpa ini TalkBack
      // mengeja judul, nominal, dan waktu sebagai elemen terpisah.
      label: item.narasi,
      hint: onTap != null ? 'Ketuk dua kali untuk lihat detail' : null,
      // Aksi tap dipasang di simpul semantik itu sendiri. excludeSemantics
      // membuang aksi milik InkWell, jadi tanpa baris ini simpulnya
      // berlabel tombol tetapi tidak bisa diaktifkan lewat ketuk dua kali.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Baris 1: ikon, judul, nominal ────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: latarIkon,
                      shape: BoxShape.circle,
                      border: Border.all(color: warna, width: 1.5),
                    ),
                    child: Icon(
                      isMasuk ? Icons.north_east : Icons.south_west,
                      size: 16,
                      color: warna,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: gayaJudul,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tanpa Flexible/Expanded — nominal tidak pernah
                  // menyusut atau melipat baris (setara flexShrink: 0).
                  // Judul di atas yang Expanded, jadi tekanan ruang
                  // diserap oleh judul (lewat ellipsis), bukan nominal.
                  Text(
                    '${tampilkanTanda ? (isMasuk ? '+' : '-') : ''}'
                    '${CurrencyFormatter.format(item.nominal)}',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: gayaNominal.copyWith(color: warna),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // ── Baris 2: label arah + waktu (+ catatan/metode) ───
              // Indent sebesar ikon + jarak di baris 1, supaya sejajar
              // tepat di bawah judul. Judul sekarang selalu nama
              // kategori (lihat record_transaction_modal.dart), jadi
              // catatan bebas pengguna ("Pak Ahmad", dsb) perlu tempat
              // lain untuk terlihat — di sini, berdampingan dengan
              // jam, bukan metode bayar, saat catatan diisi.
              Padding(
                padding: const EdgeInsets.only(left: 42),
                child: Row(
                  children: [
                    Text(
                      isMasuk ? 'Masuk' : 'Keluar',
                      style: gayaLabelArah.copyWith(color: warna),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (item.catatan != null && item.catatan!.trim().isNotEmpty)
                            ? '${item.time} · ${item.catatan!.trim()}'
                            : '${item.time} · ${item.method}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: gayaMeta,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
