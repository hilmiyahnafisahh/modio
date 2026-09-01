import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// APP CARD WIDGET  –  Kartu standar yang konsisten
///
/// Digunakan untuk semua kartu di aplikasi agar memiliki styling
/// yang konsisten dan mudah di-maintain.
/// ─────────────────────────────────────────────────────────────────

/// Card dengan gaya Modio standar
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Null berarti ikut tema aktif (kartu & garis terang/gelap) — hanya
  /// diisi eksplisit saat pemanggil sungguh butuh warna tetap, bukan
  /// sebagai nilai baku, sebab nilai baku const tidak bisa membaca
  /// `BuildContext` untuk tahu tema mana yang sedang aktif.
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final double elevation;
  final VoidCallback? onTap;
  final BoxBorder? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14,
    this.elevation = 0,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cardBorder = border ??
        Border.all(
          color: borderColor ?? context.warnaGaris,
          width: 1,
        );

    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.warnaKartu,
        borderRadius: BorderRadius.circular(borderRadius),
        border: cardBorder,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

/// Card dengan shadow (elevated card)
class AppElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final double borderRadius;
  final double elevation;
  final VoidCallback? onTap;

  const AppElevatedCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderRadius = 14,
    this.elevation = 4,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Bayangan tidak terlihat di atas latar gelap — kartu bertumpuk
    // (warnaKartuMenonjol) plus garis tepi menggantikannya di sana,
    // bayangan aslinya dipertahankan untuk mode terang.
    final bool gelap = context.gelap;
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ??
            (gelap ? context.warnaKartuMenonjol : context.warnaKartu),
        borderRadius: BorderRadius.circular(borderRadius),
        border: gelap ? Border.all(color: context.warnaGaris) : null,
        boxShadow: gelap
            ? null
            : [
                BoxShadow(
                  color: AppColors.baseDark.withValues(alpha: 0.08),
                  blurRadius: elevation,
                  offset: Offset(0, elevation / 2),
                ),
              ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

/// Card dengan highlight/tint background
class AppHighlightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  const AppHighlightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? context.latarMasuk,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (borderColor ?? context.warnaMasuk).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(
      onTap: onTap,
      child: content,
    );
  }
}

/// Header Card untuk section (biasanya di atas expandable item)
class AppCardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool isExpanded;

  const AppCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.backgroundColor,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: backgroundColor ?? context.warnaKartu,
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      color: context.warnaTeksUtama,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.bodySmall.copyWith(
                        color: context.warnaTeksMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: context.warnaTeksMuted,
              ),
          ],
        ),
      ),
    );
  }
}

/// Content Card untuk menampilkan informasi berpasangan (label-value)
class AppInfoCard extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final Color? labelColor;
  final Color? valueColor;
  final Widget? trailing;

  const AppInfoCard({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.labelColor,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: labelStyle ??
                AppTypography.bodyMedium.copyWith(
                  color: labelColor ?? context.warnaTeksMuted,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ??
                  AppTypography.labelSmall.copyWith(
                    color: valueColor ?? context.warnaTeksUtama,
                  ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
