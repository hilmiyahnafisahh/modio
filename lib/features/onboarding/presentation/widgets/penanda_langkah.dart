import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)

import '../../../../core/theme/theme_extensions.dart'; // Warna sesuai tema

/// Jumlah langkah registrasi: profil, cara masuk, tema.
const int jumlahLangkahRegistrasi = 3;

/// Penanda "Langkah n dari 3" beserta batang kemajuan, dipakai di
/// setiap langkah registrasi. Dibacakan sebagai satu kalimat supaya
/// pengguna pembaca layar tahu posisinya dalam alur.
class PenandaLangkah extends StatelessWidget {
  const PenandaLangkah({super.key, required this.langkah});

  final int langkah; // Langkah saat ini, mulai dari 1

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String teks = 'Langkah $langkah dari $jumlahLangkahRegistrasi';
    return Semantics(
      label: teks,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teks,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.warnaTeksMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 1; i <= jumlahLangkahRegistrasi; i++) ...[
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      // Langkah yang sudah/ sedang dijalani berwarna penuh,
                      // sisanya memakai garis input (≥ 3:1) agar tetap terlihat.
                      color: i <= langkah ? scheme.primary : context.warnaGarisInput,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                if (i < jumlahLangkahRegistrasi) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
