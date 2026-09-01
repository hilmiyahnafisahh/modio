import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import '../../../../core/theme/theme_extensions.dart'; // Extension untuk akses warna sesuai tema

/// ─────────────────────────────────────────────────────────────────
/// CHAT BUBBLE  –  Gelembung pesan chat (user atau AI)
///
/// Cara pakai:
///   ChatBubble(message: ChatMessage(text: '...', isUser: true))
/// ─────────────────────────────────────────────────────────────────

/// Model data satu pesan chat
class ChatMessage { // Struktur data satu pesan chat
  final String text; // Isi teks pesan
  final bool isUser; // true = pesan dari user, false = dari AI

  const ChatMessage({required this.text, required this.isUser}); // Konstruktor, keduanya wajib diisi
}

/// Widget gelembung chat
class ChatBubble extends StatelessWidget { // Widget tampilan satu gelembung pesan, tanpa state internal
  final ChatMessage message; // Data pesan yang ditampilkan

  const ChatBubble({super.key, required this.message}); // Konstruktor, key diteruskan ke superclass

  @override
  Widget build(BuildContext context) { // Membangun tampilan gelembung pesan
    final bool isUser = message.isUser; // Cek apakah pesan berasal dari pengguna

    return Padding( // Beri jarak vertikal antar gelembung pesan
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row( // Susun avatar dan gelembung secara horizontal
        // Pesan user → kanan, pesan AI → kiri
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start, // Posisikan sesuai pengirim
        crossAxisAlignment: CrossAxisAlignment.end, // Sejajarkan ke bawah
        children: [
          // Avatar AI (hanya tampil untuk pesan AI)
          if (!isUser) ...[ // Tampilkan avatar hanya jika pesan dari AI
            Container( // Lingkaran avatar AI
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.latarMasuk, // Warna latar avatar
                shape: BoxShape.circle, // Bentuk lingkaran
              ),
              child: Icon( // Ikon robot melambangkan AI
                Icons.smart_toy_outlined,
                size: 16,
                color: context.warnaMasuk,
              ),
            ),
            const SizedBox(width: 8), // Jarak horizontal avatar ke gelembung pesan
          ],

          // Gelembung pesan
          Flexible( // Gelembung pesan bisa menyusut sesuai ruang tersedia
            child: Container( // Kotak gelembung berisi teks pesan
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                // User: warna aksi utama | AI: latar kartu
                color: isUser
                    ? Theme.of(context).colorScheme.primary
                    : context.warnaKartu,
                borderRadius: BorderRadius.only( // Sudut membulat, kecuali satu sudut "runcing" penanda arah
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      isUser ? const Radius.circular(16) : Radius.zero, // Sudut runcing di kiri bawah untuk pesan AI
                  bottomRight:
                      isUser ? Radius.zero : const Radius.circular(16), // Sudut runcing di kanan bawah untuk pesan user
                ),
                border: Border.all( // Garis tepi gelembung
                  color: isUser
                      ? Theme.of(context).colorScheme.primary
                      : context.warnaGaris,
                ),
              ),
              child: Text( // Teks isi pesan
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4, // Jarak antar baris agar mudah dibaca
                  color: isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : context.warnaTeksUtama,
                ),
              ),
            ),
          ),

          // Spasi di kanan untuk pesan AI
          if (!isUser) const SizedBox(width: 40), // Jarak kosong di kanan agar bubble AI tidak penuh selebar layar
        ],
      ),
    );
  }
}
