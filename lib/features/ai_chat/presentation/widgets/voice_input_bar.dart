import 'package:flutter/material.dart';
import '../../../../core/theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// VOICE INPUT BAR  –  Bar input teks + tombol suara untuk chat AI
///
/// Cara pakai:
///   VoiceInputBar(
///     controller: _textController,
///     onSend: (text) => ...,
///     onVoice: () => ...,
///   )
/// ─────────────────────────────────────────────────────────────────

class VoiceInputBar extends StatelessWidget {
  final TextEditingController controller;

  /// Callback saat tombol kirim ditekan (menerima teks)
  final ValueChanged<String> onSend;

  /// Callback saat tombol mikrofon ditekan
  final VoidCallback onVoice;

  const VoiceInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: context.warnaKartu,
        border: Border(
          top: BorderSide(color: context.warnaGaris),
        ),
      ),
      child: Row(
        children: [
          // ── Field teks ─────────────────────────────────────────
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: context.warnaTeksUtama),
              decoration: InputDecoration(
                hintText: 'Tanya seputar keuangan Anda...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: context.warnaTeksMuted,
                ),
                filled: true,
                fillColor: context.warnaKartuMenonjol,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),

          // ── Tombol Suara ─────────────────────────────────────
          GestureDetector(
            onTap: onVoice,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.latarMasuk,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_outlined,
                size: 22,
                color: context.warnaMasuk,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // ── Tombol Kirim ─────────────────────────────────────
          GestureDetector(
            onTap: () => onSend(controller.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
