import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter
import '../../../../core/theme/app_colors.dart'; // Palet warna khusus aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// TENTANG APLIKASI PAGE  –  Info versi, lisensi & kredit
/// ─────────────────────────────────────────────────────────────────

class TentangAplikasiPage extends StatelessWidget { // Halaman statis, tidak punya state yang berubah
  const TentangAplikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar halaman sesuai tema
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Samakan warna app bar dengan latar
        elevation: 0, // Tanpa bayangan di bawah app bar
        leading: IconButton( // Tombol kembali di kiri app bar
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.warnaTeksUtama,
          onPressed: () => Navigator.pop(context), // Kembali ke halaman sebelumnya
          tooltip: 'Kembali', // Teks bantuan aksesibilitas
        ),
        title: Text(
          'Tentang Aplikasi', // Judul halaman
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama,
          ),
        ),
        centerTitle: true, // Judul diletakkan di tengah app bar
      ),
      body: SingleChildScrollView( // Konten bisa digulir jika melebihi layar
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32), // Jarak atas sebelum logo

            // ── Logo & Identitas App ──────────────────────────────────
            Container( // Kotak logo aplikasi
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: context.gelap
                    ? null // Tanpa gradasi di mode gelap
                    : const LinearGradient( // Gradasi warna di mode terang
                        colors: [AppColors.primary900, AppColors.primary700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: context.gelap ? AppColors.darkSurfaceHi : null, // Warna solid untuk mode gelap
                borderRadius: BorderRadius.circular(20),
                border: context.gelap
                    ? Border.all(color: AppColors.darkPrimary, width: 1.5) // Garis tepi hanya di mode gelap
                    : null,
                boxShadow: context.gelap
                    ? null // Tanpa bayangan di mode gelap
                    : [
                        BoxShadow( // Bayangan lembut di mode terang
                          color: AppColors.primary900.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Icon(
                Icons.accessibility_new_rounded, // Ikon logo aplikasi
                size: 40,
                color: context.gelap ? AppColors.darkText : AppColors.white, // Warna ikon kontras sesuai tema
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modio', // Nama aplikasi
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.warnaTeksUtama,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keuangan UMKM yang Mudah & Aksesibel', // Tagline aplikasi
              style: TextStyle(
                fontSize: 13,
                color: context.warnaTeksMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container( // Badge kecil menampilkan nomor versi
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.latarMasuk, // Warna latar bernuansa aksen positif
                borderRadius: BorderRadius.circular(20), // Sudut sangat membulat (bentuk pil)
                border: Border.all(
                    color: context.warnaMasuk.withValues(alpha: 0.4)), // Garis tepi transparan sebagian
              ),
              child: Text(
                'Versi 1.0.0', // Teks nomor versi
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.warnaMasuk,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // ── Info Umum ─────────────────────────────────────────────
            _buildSectionLabel(context, 'INFORMASI'), // Label judul seksi informasi umum
            const SizedBox(height: 8),
            _buildInfoGroup(context, [ // Kartu berisi daftar info aplikasi
              _InfoRow(label: 'Nama Aplikasi',    value: 'Modio'),
              _InfoRow(label: 'Versi',            value: '1.0.0 (Build 100)'),
              _InfoRow(label: 'Platform',         value: 'Android & iOS'),
              _InfoRow(label: 'Dikembangkan oleh',value: 'Tim Modio'),
              _InfoRow(label: 'Bahasa',           value: 'Bahasa Indonesia'),
            ]),
            const SizedBox(height: 20),

            // ── Kepatuhan ─────────────────────────────────────────────
            _buildSectionLabel(context, 'AKSESIBILITAS & KEPATUHAN'), // Label judul seksi kepatuhan
            const SizedBox(height: 8),
            _buildInfoGroup(context, [ // Kartu berisi info standar aksesibilitas yang dipenuhi
              _InfoRow(label: 'Standar',     value: 'WCAG 2.1 Level AA'),
              _InfoRow(label: 'Kontras Min', value: '7.0:1 (teks, setara AAA)'),
              _InfoRow(label: 'Target Tap',  value: '≥ 44 × 44 dp'),
              _InfoRow(label: 'Dukungan',    value: 'TalkBack & VoiceOver'),
            ]),
            const SizedBox(height: 20),

            // ── Tautan ────────────────────────────────────────────────
            _buildSectionLabel(context, 'TAUTAN'), // Label judul seksi tautan
            const SizedBox(height: 8),
            _buildLinkGroup(context, [ // Kartu berisi daftar tautan yang bisa diketuk
              _LinkRow(
                icon: Icons.shield_outlined,
                label: 'Kebijakan Privasi',
                onTap: () {}, // Belum diimplementasikan, placeholder kosong
              ),
              _LinkRow(
                icon: Icons.article_outlined,
                label: 'Syarat & Ketentuan',
                onTap: () {}, // Belum diimplementasikan, placeholder kosong
              ),
              _LinkRow(
                icon: Icons.code_rounded,
                label: 'Lisensi Open Source',
                onTap: () {}, // Belum diimplementasikan, placeholder kosong
              ),
              _LinkRow(
                icon: Icons.star_border_rounded,
                label: 'Beri Penilaian',
                onTap: () {}, // Belum diimplementasikan, placeholder kosong
              ),
            ]),
            const SizedBox(height: 36),

            // ── Footer ────────────────────────────────────────────────
            Text(
              '© 2025 Modio\nDibuat dengan ♥ untuk UMKM Indonesia', // Teks hak cipta dan kredit
              style: TextStyle(
                fontSize: 12,
                color: context.warnaTeksMuted,
                height: 1.6, // Jarak antar baris teks
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32), // Jarak bawah sebelum akhir scroll
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) { // Membangun label judul seksi kecil
    return Align(
      alignment: Alignment.centerLeft, // Rata kiri meskipun induk Column rata tengah
      child: Semantics( // Tandai sebagai judul agar bisa dilompati lewat navigasi Judul TalkBack
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.warnaTeksMuted,
            letterSpacing: 0.8, // Jarak antar huruf sedikit lebar (gaya label)
          ),
        ),
      ),
    );
  }

  Widget _buildInfoGroup(BuildContext context, List<_InfoRow> rows) { // Membangun kartu daftar baris info label-nilai
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu, // Warna latar kartu
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris), // Garis tepi kartu
      ),
      child: Column(
        children: List.generate(rows.length, (index) { // Bangun tiap baris info dari daftar
          final row = rows[index]; // Data baris saat ini
          final isLast = index == rows.length - 1; // Cek apakah ini baris terakhir (untuk divider)
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // Label dan nilai rata atas
                  children: [
                    Expanded( // Kolom label mengambil proporsi lebih kecil
                      flex: 4,
                      child: Text(
                        row.label, // Teks label
                        style: TextStyle(
                          fontSize: 13,
                          color: context.warnaTeksMuted,
                        ),
                      ),
                    ),
                    Expanded( // Kolom nilai mengambil proporsi lebih besar
                      flex: 5,
                      child: Text(
                        row.value, // Teks nilai
                        textAlign: TextAlign.right, // Rata kanan
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.warnaTeksUtama,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) // Tambahkan garis pemisah kecuali untuk baris terakhir
                Divider(
                    height: 1, indent: 16, endIndent: 16,
                    color: context.warnaGaris),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLinkGroup(BuildContext context, List<_LinkRow> rows) { // Membangun kartu daftar tautan yang bisa diketuk
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu, // Warna latar kartu
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris), // Garis tepi kartu
      ),
      child: Material( // Diperlukan agar efek ripple ListTile terlihat
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: List.generate(rows.length, (index) { // Bangun tiap baris tautan dari daftar
            final row = rows[index]; // Data baris saat ini
            final isLast = index == rows.length - 1; // Cek apakah ini baris terakhir (untuk divider)
            return Column(
              children: [
                ListTile( // Baris standar dengan ikon, judul, dan panah di kanan
                  leading: Icon(row.icon, size: 20, color: context.warnaTeksUtama),
                  title: Text(
                    row.label, // Teks label tautan
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right, // Ikon panah menunjukkan bisa diketuk
                      size: 18, color: context.warnaTeksMuted),
                  onTap: row.onTap, // Aksi saat baris diketuk
                ),
                if (!isLast) // Tambahkan garis pemisah kecuali untuk baris terakhir
                  Divider(
                      height: 1, indent: 52, color: context.warnaGaris),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _InfoRow { // Model data satu baris info label-nilai
  final String label; // Teks label
  final String value; // Teks nilai
  const _InfoRow({required this.label, required this.value});
}

class _LinkRow { // Model data satu baris tautan
  final IconData icon; // Ikon di sisi kiri
  final String label; // Teks label tautan
  final VoidCallback onTap; // Aksi saat diketuk
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
