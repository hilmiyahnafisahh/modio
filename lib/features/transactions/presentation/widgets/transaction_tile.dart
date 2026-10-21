import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../../../../core/theme/app_typography.dart'; // Gaya-gaya teks aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Extension untuk akses warna sesuai tema
import '../../../../core/utils/currency_formatter.dart'; // Pemformat angka menjadi teks rupiah
import '../../data/transaction_model.dart'; // Model data transaksi

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

class TransactionTile extends StatelessWidget { // Widget baris satu transaksi, tanpa state internal
  final TransactionItem item; // Data transaksi yang ditampilkan

  /// Callback saat baris ditekan — biasanya membuka halaman Detail
  /// Transaksi.
  final VoidCallback? onTap; // Fungsi dipanggil saat baris diketuk

  /// Tampilkan tanda plus atau minus di depan nominal
  final bool tampilkanTanda; // Apakah nominal diberi tanda +/-

  const TransactionTile({ // Konstruktor widget
    super.key, // Key widget diteruskan ke superclass
    required this.item, // Wajib diisi
    this.onTap, // Opsional
    this.tampilkanTanda = true, // Default tampilkan tanda
  });

  @override
  Widget build(BuildContext context) { // Membangun tampilan widget
    final bool isMasuk = item.type == TransactionType.masuk; // Cek apakah transaksi jenis pemasukan

    // tertiary700, bukan tertiary500. Yang terakhir hanya mencapai
    // rasio 3,8:1 terhadap putih — gagal bahkan standar AA, padahal
    // dipakai untuk menampilkan nominal.
    final Color warna = isMasuk ? context.warnaMasuk : context.warnaKeluar; // Warna sesuai jenis transaksi
    final Color latarIkon = isMasuk ? context.latarMasuk : context.latarKeluar; // Warna latar lingkaran ikon

    // Nominal dan label Masuk/Keluar memakai ukuran font tetap kecil
    // (bukan skala AppTypography yang lebih besar) supaya baris 1 dan
    // baris 2 selalu satu baris tanpa melipat, dan tinggi tiap item
    // jadi konsisten — bukan sekadar preferensi visual, ini yang
    // menjaga daftar tidak "melar" tidak beraturan antar baris.
    const TextStyle gayaNominal = TextStyle( // Gaya teks untuk nominal
      fontSize: 15,
      fontWeight: FontWeight.w700,
    );
    const TextStyle gayaLabelArah = TextStyle( // Gaya teks untuk label Masuk/Keluar
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );
    final TextStyle gayaMeta =
        AppTypography.captionLarge.copyWith(color: context.warnaTeksMuted); // Gaya teks untuk info waktu/metode
    final TextStyle gayaJudul =
        AppTypography.titleSmall.copyWith(color: context.warnaTeksUtama); // Gaya teks untuk judul transaksi

    // Saat ukuran font sistem diperbesar (≥ 150%), judul dan nominal
    // tidak muat berdampingan di layar HP — nominal yang tidak boleh
    // menyusut membuat baris meluber ke kanan (WCAG 1.4.4). Pada kondisi
    // itu nominal turun ke baris sendiri dan judul boleh dua baris.
    final bool teksBesar = MediaQuery.textScalerOf(context).scale(10) >= 15;
    final Widget nominal = Text( // Nominal transaksi dengan tanda +/- opsional
      '${tampilkanTanda ? (isMasuk ? '+' : '-') : ''}'
      '${CurrencyFormatter.format(item.nominal)}',
      maxLines: 1, // Batasi satu baris
      softWrap: false, // Jangan pernah membungkus ke baris baru
      overflow: TextOverflow.ellipsis, // Potong dengan "..." jika kepanjangan
      style: gayaNominal.copyWith(color: warna),
    );

    return Semantics( // Bungkus dengan info aksesibilitas untuk screen reader
      button: onTap != null, // Tandai sebagai tombol jika bisa ditekan
      // Seluruh transaksi dibacakan sebagai satu kalimat, termasuk
      // petunjuk bahwa mengetuknya membuka detail. Tanpa ini TalkBack
      // mengeja judul, nominal, dan waktu sebagai elemen terpisah.
      label: item.narasi, // Kalimat lengkap yang dibacakan screen reader
      hint: onTap != null ? 'Ketuk dua kali untuk lihat detail' : null, // Petunjuk aksi bagi screen reader
      // Aksi tap dipasang di simpul semantik itu sendiri. excludeSemantics
      // membuang aksi milik InkWell, jadi tanpa baris ini simpulnya
      // berlabel tombol tetapi tidak bisa diaktifkan lewat ketuk dua kali.
      onTap: onTap, // Aksi yang dijalankan lewat ketuk dua kali di screen reader
      excludeSemantics: true, // Sembunyikan info semantik anak widget di bawahnya
      child: InkWell( // Efek riak saat ditekan, juga menangani tap
        onTap: onTap,
        borderRadius: BorderRadius.circular(12), // Radius efek riak mengikuti sudut
        child: Padding( // Beri jarak isi dari tepi
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column( // Susun baris 1 dan baris 2 secara vertikal
            crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
            mainAxisSize: MainAxisSize.min, // Tinggi mengikuti konten, tidak memaksa penuh
            children: [
              // ── Baris 1: ikon, judul, nominal ────────────────────
              Row( // Baris pertama: ikon, judul, nominal
                crossAxisAlignment: CrossAxisAlignment.center, // Sejajarkan tengah secara vertikal
                children: [
                  Container( // Lingkaran ikon arah transaksi
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: latarIkon,
                      shape: BoxShape.circle, // Bentuk lingkaran
                      border: Border.all(color: warna, width: 1.5), // Garis tepi sesuai warna jenis
                    ),
                    child: Icon( // Ikon panah masuk/keluar
                      isMasuk ? Icons.north_east : Icons.south_west,
                      size: 16,
                      color: warna,
                    ),
                  ),
                  const SizedBox(width: 10), // Jarak horizontal ikon ke judul
                  Expanded( // Judul memenuhi sisa ruang yang tersedia
                    child: Text(
                      item.title,
                      maxLines: teksBesar ? 2 : 1, // Satu baris, dua baris saat teks diperbesar
                      overflow: TextOverflow.ellipsis, // Potong dengan "..." jika kepanjangan
                      style: gayaJudul,
                    ),
                  ),
                  // Tanpa Flexible/Expanded — nominal tidak pernah
                  // menyusut atau melipat baris (setara flexShrink: 0).
                  // Judul di atas yang Expanded, jadi tekanan ruang
                  // diserap oleh judul (lewat ellipsis), bukan nominal.
                  if (!teksBesar) ...[
                    const SizedBox(width: 8), // Jarak horizontal judul ke nominal
                    nominal,
                  ],
                ],
              ),
              if (teksBesar) // Teks diperbesar: nominal di baris sendiri, sejajar judul
                Padding(
                  padding: const EdgeInsets.only(left: 42, top: 4),
                  child: nominal,
                ),
              const SizedBox(height: 4), // Jarak vertikal antara baris 1 dan baris 2

              // ── Baris 2: label arah + waktu (+ catatan/metode) ───
              // Indent sebesar ikon + jarak di baris 1, supaya sejajar
              // tepat di bawah judul. Judul sekarang selalu nama
              // kategori (lihat record_transaction_modal.dart), jadi
              // catatan bebas pengguna ("Pak Ahmad", dsb) perlu tempat
              // lain untuk terlihat — di sini, berdampingan dengan
              // jam, bukan metode bayar, saat catatan diisi.
              Padding( // Indentasi baris 2 agar sejajar dengan judul
                padding: const EdgeInsets.only(left: 42),
                child: Row(
                  children: [
                    Text( // Label Masuk/Keluar
                      isMasuk ? 'Masuk' : 'Keluar',
                      style: gayaLabelArah.copyWith(color: warna),
                    ),
                    const SizedBox(width: 8), // Jarak horizontal label ke info waktu
                    Expanded( // Info waktu/catatan/metode memenuhi sisa ruang
                      child: Text(
                        (item.catatan != null && item.catatan!.trim().isNotEmpty)
                            ? '${item.time} · ${item.catatan!.trim()}' // Tampilkan catatan jika ada
                            : '${item.time} · ${item.method}', // Jika tidak, tampilkan metode bayar
                        maxLines: 1, // Batasi satu baris
                        overflow: TextOverflow.ellipsis, // Potong dengan "..." jika kepanjangan
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
