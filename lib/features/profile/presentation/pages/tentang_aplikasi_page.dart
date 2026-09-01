import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// TENTANG APLIKASI PAGE  –  Info versi, lisensi & kredit
/// ─────────────────────────────────────────────────────────────────

class TentangAplikasiPage extends StatelessWidget {
  const TentangAplikasiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: context.warnaTeksUtama,
          onPressed: () => Navigator.pop(context),
          tooltip: 'Kembali',
        ),
        title: Text(
          'Tentang Aplikasi',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),

            // ── Logo & Identitas App ──────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: context.gelap
                    ? null
                    : const LinearGradient(
                        colors: [AppColors.primary900, AppColors.primary700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: context.gelap ? AppColors.darkSurfaceHi : null,
                borderRadius: BorderRadius.circular(20),
                border: context.gelap
                    ? Border.all(color: AppColors.darkPrimary, width: 1.5)
                    : null,
                boxShadow: context.gelap
                    ? null
                    : [
                        BoxShadow(
                          color: AppColors.primary900.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Icon(
                Icons.accessibility_new_rounded,
                size: 40,
                color: context.gelap ? AppColors.darkText : AppColors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modio',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.warnaTeksUtama,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keuangan UMKM yang Mudah & Aksesibel',
              style: TextStyle(
                fontSize: 13,
                color: context.warnaTeksMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: context.latarMasuk,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: context.warnaMasuk.withValues(alpha: 0.4)),
              ),
              child: Text(
                'Versi 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.warnaMasuk,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // ── Info Umum ─────────────────────────────────────────────
            _buildSectionLabel(context, 'INFORMASI'),
            const SizedBox(height: 8),
            _buildInfoGroup(context, [
              _InfoRow(label: 'Nama Aplikasi',    value: 'Modio'),
              _InfoRow(label: 'Versi',            value: '1.0.0 (Build 100)'),
              _InfoRow(label: 'Platform',         value: 'Android & iOS'),
              _InfoRow(label: 'Dikembangkan oleh',value: 'Tim Modio'),
              _InfoRow(label: 'Bahasa',           value: 'Bahasa Indonesia'),
            ]),
            const SizedBox(height: 20),

            // ── Kepatuhan ─────────────────────────────────────────────
            _buildSectionLabel(context, 'AKSESIBILITAS & KEPATUHAN'),
            const SizedBox(height: 8),
            _buildInfoGroup(context, [
              _InfoRow(label: 'Standar',     value: 'WCAG 2.1 Level AAA'),
              _InfoRow(label: 'Kontras Min', value: '7.0:1 (semua elemen teks)'),
              _InfoRow(label: 'Target Tap',  value: '≥ 44 × 44 dp'),
              _InfoRow(label: 'Dukungan',    value: 'TalkBack & VoiceOver'),
            ]),
            const SizedBox(height: 20),

            // ── Tautan ────────────────────────────────────────────────
            _buildSectionLabel(context, 'TAUTAN'),
            const SizedBox(height: 8),
            _buildLinkGroup(context, [
              _LinkRow(
                icon: Icons.shield_outlined,
                label: 'Kebijakan Privasi',
                onTap: () {},
              ),
              _LinkRow(
                icon: Icons.article_outlined,
                label: 'Syarat & Ketentuan',
                onTap: () {},
              ),
              _LinkRow(
                icon: Icons.code_rounded,
                label: 'Lisensi Open Source',
                onTap: () {},
              ),
              _LinkRow(
                icon: Icons.star_border_rounded,
                label: 'Beri Penilaian',
                onTap: () {},
              ),
            ]),
            const SizedBox(height: 36),

            // ── Footer ────────────────────────────────────────────────
            Text(
              '© 2025 Modio\nDibuat dengan ♥ untuk UMKM Indonesia',
              style: TextStyle(
                fontSize: 12,
                color: context.warnaTeksMuted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.warnaTeksMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoGroup(BuildContext context, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris),
      ),
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          final isLast = index == rows.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        row.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.warnaTeksMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 5,
                      child: Text(
                        row.value,
                        textAlign: TextAlign.right,
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
              if (!isLast)
                Divider(
                    height: 1, indent: 16, endIndent: 16,
                    color: context.warnaGaris),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLinkGroup(BuildContext context, List<_LinkRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: context.warnaKartu,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.warnaGaris),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: List.generate(rows.length, (index) {
            final row = rows[index];
            final isLast = index == rows.length - 1;
            return Column(
              children: [
                ListTile(
                  leading: Icon(row.icon, size: 20, color: context.warnaTeksUtama),
                  title: Text(
                    row.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right,
                      size: 18, color: context.warnaTeksMuted),
                  onTap: row.onTap,
                ),
                if (!isLast)
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

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
}

class _LinkRow {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
