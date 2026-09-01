import 'package:flutter/material.dart';
import '../../../../core/theme/theme_extensions.dart';

/// ─────────────────────────────────────────────────────────────────
/// CHAT BUBBLE  –  Gelembung pesan chat (user atau AI)
///
/// Cara pakai:
///   ChatBubble(message: ChatMessage(text: '...', isUser: true))
/// ─────────────────────────────────────────────────────────────────

/// Model data satu pesan chat
class ChatMessage {
  final String text;
  final bool isUser; // true = pesan dari user, false = dari AI

  const ChatMessage({required this.text, required this.isUser});
}

/// Widget gelembung chat
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        // Pesan user → kanan, pesan AI → kiri
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar AI (hanya tampil untuk pesan AI)
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.latarMasuk,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 16,
                color: context.warnaMasuk,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Gelembung pesan
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                // User: warna aksi utama | AI: latar kartu
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : context.warnaKartu,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight:
                      isUser ? Radius.zero : const Radius.circular(16),
                ),
                border: Border.all(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : context.warnaGaris,
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : context.warnaTeksUtama,
                ),
              ),
            ),
          ),

          // Spasi di kanan untuk pesan AI
          if (!isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }
}
