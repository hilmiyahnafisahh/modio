import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../../../../core/theme/theme_extensions.dart'; // Extension untuk akses warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// AI INSIGHT WIDGET  –  Kartu ringkasan naratif
///
/// Menampilkan satu poin ringkasan keuangan.
///
/// CATATAN PENTING: isi kartu ini dirakit dari template berisi angka
/// hasil perhitungan basis data, bukan dibangkitkan model bahasa.
/// Angka pada laporan keuangan tidak boleh mengandung kemungkinan
/// kekeliruan, karena pengguna tunanetra tidak punya cara memeriksa
/// ulang secara visual.
/// ─────────────────────────────────────────────────────────────────

class AiInsightWidget extends StatelessWidget { // Widget kartu ringkasan, tanpa state internal
  final String title; // Judul singkat ringkasan
  final String description; // Penjelasan lengkap ringkasan
  final InsightType type; // Jenis nada ringkasan (positif/negatif/netral)

  const AiInsightWidget({ // Konstruktor widget
    super.key, // Key diteruskan ke superclass
    required this.title, // Wajib diisi
    required this.description, // Wajib diisi
    this.type = InsightType.neutral, // Default nada netral
  });

  @override
  Widget build(BuildContext context) { // Membangun tampilan kartu
    final Color bgColor = switch (type) { // Warna latar kartu sesuai jenis
      InsightType.positive => context.latarMasuk,
      InsightType.negative => context.latarKeluar,
      InsightType.neutral => context.latarInfo,
    };
    final Color accentColor = switch (type) { // Warna aksen (garis, ikon, judul) sesuai jenis
      InsightType.positive => context.warnaMasuk,
      InsightType.negative => context.warnaKeluar,
      InsightType.neutral => context.warnaInfo,
    };
    final IconData icon = switch (type) { // Ikon yang ditampilkan sesuai jenis
      InsightType.positive => Icons.trending_up_rounded,
      InsightType.negative => Icons.trending_down_rounded,
      InsightType.neutral => Icons.lightbulb_outline,
    };

    return Semantics( // Bungkus dengan info aksesibilitas untuk screen reader
      // Judul dan isi dibacakan sebagai satu kesatuan, bukan dua
      // elemen terpisah yang harus ditelusuri satu per satu.
      label: '$title. $description', // Kalimat lengkap yang dibacakan screen reader
      excludeSemantics: true, // Sembunyikan info semantik anak widget di bawahnya
      child: Container( // Kotak pembungkus utama kartu
        width: double.infinity, // Lebar mengikuti lebar induk
        padding: const EdgeInsets.all(16), // Jarak isi dari tepi kartu
        decoration: BoxDecoration( // Dekorasi visual kartu
          color: bgColor, // Warna latar kartu
          borderRadius: BorderRadius.circular(12), // Sudut kartu membulat
          border: Border( // Garis tepi kartu
            // Garis tepi ditebalkan agar tetap terlihat pengguna
            // low vision, dan menjadi pembeda selain warna latar.
            left: BorderSide(color: accentColor, width: 5), // Garis tebal di kiri sebagai penanda jenis
            top: BorderSide(color: accentColor.withValues(alpha: 0.25)), // Garis tipis di atas
            right: BorderSide(color: accentColor.withValues(alpha: 0.25)), // Garis tipis di kanan
            bottom: BorderSide(color: accentColor.withValues(alpha: 0.25)), // Garis tipis di bawah
          ),
        ),
        child: Row( // Susun ikon dan teks secara horizontal
          crossAxisAlignment: CrossAxisAlignment.start, // Rata atas
          children: [
            Icon(icon, size: 22, color: accentColor), // Ikon penanda jenis ringkasan
            const SizedBox(width: 12), // Jarak horizontal ikon ke teks
            Expanded( // Kolom teks mengisi sisa ruang
              child: Column( // Susun judul dan deskripsi secara vertikal
                crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                children: [
                  Text( // Judul ringkasan
                    title,
                    style: TextStyle(
                      // Dinaikkan dari 13.
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 6), // Jarak vertikal judul ke deskripsi
                  Text( // Deskripsi lengkap ringkasan
                    description,
                    style: TextStyle(
                      // Dinaikkan dari 12. Ini isi utama kartu,
                      // bukan keterangan tambahan.
                      fontSize: 15,
                      color: context.warnaTeksUtama,
                      height: 1.5, // Jarak antar baris agar mudah dibaca
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nada ringkasan
enum InsightType { // Jenis nada isi kartu ringkasan
  positive, // tren baik
  negative, // peringatan
  neutral,  // informasi netral
}
