import 'package:flutter/material.dart'; // Widget dasar Flutter

import '../../../../core/theme/app_colors.dart'; // Palet warna aplikasi
import '../../../../core/utils/currency_formatter.dart'; // Format nominal ke teks rupiah/terucap
import '../../data/report_model.dart'; // Model RincianKategori

/// ─────────────────────────────────────────────────────────────────
/// CATEGORY BREAKDOWN  –  Rincian keuangan per kategori
///
/// Menggantikan grafik. Alasannya: grafik adalah hambatan utama yang
/// disebut pengguna sasaran MODIO — pembaca layar membacakannya
/// sebagai rangkaian angka tanpa konteks hubungan antarnilai.
///
/// Bentuk yang dipakai di sini adalah batang proporsi horizontal,
/// yang tetap memberi gambaran visual bagi pengguna awas, sementara
/// setiap barisnya punya label semantik utuh berisi nama kategori,
/// nominal, persentase, dan jumlah transaksi.
/// ─────────────────────────────────────────────────────────────────

class CategoryBreakdown extends StatelessWidget {
  final String judul; // Judul kartu, misal "Pendapatan" atau "Beban"
  final List<RincianKategori> rincian; // Daftar kategori beserta totalnya
  final int total; // Total keseluruhan untuk hitung persentase
  final Color warna; // Warna aksen kartu ini

  const CategoryBreakdown({
    super.key,
    required this.judul,
    required this.rincian,
    required this.total,
    required this.warna,
  });

  @override
  Widget build(BuildContext context) {
    return Container( // Kartu pembungkus seluruh rincian kategori
      width: double.infinity, // Lebar penuh mengikuti parent
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row( // Baris header: judul di kiri, total di kanan
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.baseDark,
                ),
              ),
              Semantics(
                label: 'Total $judul ${CurrencyFormatter.spoken(total)}', // Versi terucap untuk pembaca layar
                excludeSemantics: true,
                child: Text(
                  CurrencyFormatter.format(total), // Versi tampilan angka biasa
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: warna,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (rincian.isEmpty) // Belum ada data kategori pada periode ini
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada data pada periode ini.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textMuted,
                ),
              ),
            )
          else
            for (int i = 0; i < rincian.length; i++) ...[ // Render satu baris untuk tiap kategori
              _BarisKategori(
                item: rincian[i],
                total: total,
                warna: warna,
              ),
              if (i < rincian.length - 1) const SizedBox(height: 14), // Jarak antar baris, kecuali baris terakhir
            ],
        ],
      ),
    );
  }
}

class _BarisKategori extends StatelessWidget { // Satu baris rincian untuk satu kategori
  const _BarisKategori({
    required this.item,
    required this.total,
    required this.warna,
  });

  final RincianKategori item; // Data kategori (nama, total, jumlah transaksi)
  final int total; // Total keseluruhan, untuk hitung persentase
  final Color warna; // Warna batang proporsi

  @override
  Widget build(BuildContext context) {
    final int persen = item.persen(total); // Hitung persentase kategori ini terhadap total

    return Semantics(
      // Satu kalimat utuh menggantikan batang visual. Inilah padanan
      // naratif yang membuat informasi grafik tetap dapat diakses.
      label: '${item.nama}, ${CurrencyFormatter.spoken(item.total)}, '
          '$persen persen, dari ${item.jumlahTransaksi} transaksi', // Label lengkap untuk pembaca layar
      // container: true memastikan node semantik selalu dibuat.
      // Tanpa ini, TalkBack bisa melewati widget bila seluruh child
      // dianggap tidak punya peran semantik mandiri.
      container: true,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row( // Baris nama kategori di kiri, nominal di kanan
            children: [
              Expanded(
                child: Text(
                  item.nama,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.baseDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CurrencyFormatter.format(item.total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.baseDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Batang proporsi. Persentase juga ditulis sebagai angka di
          // sampingnya, karena panjang batang saja tidak terbaca oleh
          // pengguna yang tidak melihat layar.
          Row(
            children: [
              Expanded(
                child: ClipRRect( // Potong sudut batang agar membulat
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator( // Batang visual proporsi kategori
                    value: item.porsi(total), // Nilai 0.0–1.0 sesuai porsi kategori
                    minHeight: 10,
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(warna), // Warna batang statis, tanpa animasi
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 44,
                child: Text(
                  '$persen%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.jumlahTransaksi} transaksi',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
