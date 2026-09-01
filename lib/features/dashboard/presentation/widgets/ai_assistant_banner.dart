import 'package:flutter/material.dart'; // Widget dasar Flutter
import '../../../../core/theme/app_typography.dart'; // Gaya teks terpusat
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi warna tema kontekstual

/// ─────────────────────────────────────────────────────────────────
/// AI ASSISTANT BANNER  –  Banner promosi fitur Asisten Keuangan AI
///
/// Menampilkan:
///   • Ikon robot AI
///   • Judul & deskripsi singkat
///   • Tombol "Analisis Keuangan"
///   • Tombol "Tanya AI"
///
/// Cara pakai:
///   AiAssistantBanner(
///     onAnalysisTap: () => Navigator.push(...),
///     onChatTap: () => Navigator.push(...),
///   )
/// ─────────────────────────────────────────────────────────────────

class AiAssistantBanner extends StatelessWidget {
  /// Callback saat tombol "Analisis Keuangan" ditekan
  final VoidCallback? onAnalysisTap;

  /// Callback saat tombol "Tanya AI" ditekan
  final VoidCallback? onChatTap;

  const AiAssistantBanner({
    super.key,
    this.onAnalysisTap,
    this.onChatTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kartu ini BUKAN satu tombol. Sebelumnya seluruh isi dibungkus
    // Semantics(excludeSemantics: true) sehingga kedua tombol di
    // dalamnya hilang dari pohon aksesibilitas: TalkBack membacakan
    // kartunya, tetapi pengguna tidak pernah sampai ke "Analisis
    // Keuangan" maupun "Tanya AI". Kini keterangan kartu dan tombol
    // berdiri sebagai simpul terpisah.
    return Container( // Kartu pembungkus seluruh banner
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.warnaGaris),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Baris Ikon + Judul + Deskripsi ─────────────────────
          // Judul dan deskripsi dibacakan sebagai satu simpul teks,
          // bukan tombol, agar tidak menyesatkan.
          Semantics(
            label: 'Asisten Keuangan. AI siap membantu menganalisis '
                'laporan keuangan dan menjawab pertanyaan seputar '
                'usaha Anda. Tersedia dua tombol berikut.', // Deskripsi lengkap untuk pembaca layar
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ikon robot AI dalam kotak hijau muda
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.latarMasuk,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.warnaMasuk, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.smart_toy_outlined, // robot = ikon AI
                      size: 24,
                      color: context.warnaMasuk,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Judul dan deskripsi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asisten Keuangan',
                        style: AppTypography.labelMedium.copyWith(
                          color: context.warnaTeksUtama,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI siap membantu menganalisis laporan keuangan dan menjawab pertanyaan seputar usaha Anda.',
                        style: AppTypography.captionSmall.copyWith(
                          height: 1.5,
                          color: context.warnaTeksMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Tombol Analisis Keuangan ─────────────────────────────
          _AiOutlineButton(
            icon: Icons.bar_chart_outlined,
            label: 'Analisis Keuangan',
            hint: 'Ketuk dua kali untuk membuka analisis keuangan',
            onTap: onAnalysisTap ?? () {}, // Fallback aksi kosong bila callback tidak diberikan
          ),
          const SizedBox(height: 10),

          // ── Tombol Tanya AI ──────────────────────────────────────
          _AiOutlineButton(
            icon: Icons.chat_bubble_outline,
            label: 'Tanya AI',
            hint: 'Ketuk dua kali untuk bertanya kepada asisten AI',
            onTap: onChatTap ?? () {},
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// PRIVATE: Tombol outline hijau (hanya dipakai di file ini)
// ─────────────────────────────────────────────────────────────────

class _AiOutlineButton extends StatelessWidget { // Tombol bergaya outline dengan info aksesibilitas
  final IconData icon; // Ikon di sisi kiri tombol
  final String label; // Teks tombol
  final String hint; // Petunjuk tambahan untuk pembaca layar
  final VoidCallback onTap; // Aksi saat tombol ditekan

  const _AiOutlineButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // onTap ditulis di Semantics, bukan hanya di widget sentuh.
    // Tanpa itu simpulnya berlabel "tombol" tetapi tidak punya aksi
    // tap, sehingga ketuk-dua-kali TalkBack tidak melakukan apa pun.
    return Semantics(
      button: true, // Umumkan sebagai tombol
      label: label,
      hint: hint, // Penjelasan tambahan yang dibacakan setelah label
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell( // Efek riak visual saat disentuh
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 48), // Tinggi sentuh minimum aksesibilitas
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.transparent, // Tombol outline: latar transparan
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
