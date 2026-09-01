import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import '../../../../core/theme/theme_extensions.dart'; // Extension untuk akses warna sesuai tema
import '../widgets/voice_input_bar.dart'; // Widget bar input teks + suara
import '../widgets/chat_bubble.dart'; // Widget gelembung pesan chat

/// ─────────────────────────────────────────────────────────────────
/// AI ASSISTANT PAGE  –  Halaman Chatbot AI Profil
///
/// Fitur:
///   • Chat berbasis teks dengan AI
///   • Input suara (voice-to-text)
///   • Riwayat percakapan
/// ─────────────────────────────────────────────────────────────────

class AiAssistantPage extends StatefulWidget { // Widget halaman ini punya state yang berubah (daftar pesan)
  const AiAssistantPage({super.key}); // Konstruktor, key diteruskan ke superclass

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState(); // Buat objek state untuk widget ini
}

class _AiAssistantPageState extends State<AiAssistantPage> { // Kelas state yang menyimpan data berubah-ubah
  // Daftar pesan percakapan (dummy untuk prototype)
  final List<ChatMessage> _messages = [ // Daftar pesan chat yang ditampilkan
    const ChatMessage(
      text: 'Halo! Saya Asisten Keuangan AI Modio. Ada yang bisa saya bantu?',
      isUser: false, // Pesan ini dari AI, bukan dari pengguna
    ),
  ];

  final TextEditingController _controller = TextEditingController(); // Pengendali teks pada kolom input

  @override
  void dispose() { // Dipanggil saat widget dihapus dari layar
    _controller.dispose(); // Bebaskan resource controller teks
    super.dispose(); // Panggil dispose bawaan superclass
  }

  void _sendMessage(String text) { // Kirim pesan baru dari pengguna
    if (text.trim().isEmpty) return; // Jangan kirim jika teks kosong

    setState(() { // Perbarui state agar UI ikut diperbarui
      // Tambah pesan user
      _messages.add(ChatMessage(text: text.trim(), isUser: true)); // Tambahkan pesan pengguna ke daftar
      _controller.clear(); // Kosongkan kolom input setelah dikirim

      // Simulasi balasan AI (dummy)
      Future.delayed(const Duration(milliseconds: 800), () { // Tunda balasan AI seolah sedang berpikir
        if (mounted) { // Pastikan widget masih ada di layar sebelum setState
          setState(() { // Perbarui state dengan balasan AI
            _messages.add(const ChatMessage(
              text: 'Terima kasih atas pertanyaannya! '
                    'Fitur AI sedang dalam pengembangan.',
              isUser: false, // Pesan ini dari AI
            ));
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) { // Membangun tampilan halaman
    return Scaffold( // Kerangka halaman standar (appbar + body)
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar mengikuti tema
      appBar: AppBar( // Bilah judul di atas halaman
        title: Row( // Judul berisi ikon dan teks berdampingan
          children: [
            Container( // Kotak latar untuk ikon
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.latarMasuk, // Warna latar ikon
                borderRadius: BorderRadius.circular(8), // Sudut membulat
              ),
              child: Icon( // Ikon robot melambangkan AI
                Icons.smart_toy_outlined,
                size: 18,
                color: context.warnaMasuk,
              ),
            ),
            const SizedBox(width: 10), // Jarak horizontal ikon ke teks
            const Text('Asisten AI'), // Judul halaman
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar appbar mengikuti tema
        elevation: 0, // Tidak ada bayangan di appbar
        scrolledUnderElevation: 0, // Tidak ada bayangan saat konten discroll
        foregroundColor: context.warnaTeksUtama, // Warna teks/ikon di appbar
        bottom: PreferredSize( // Garis tipis di bawah appbar
          preferredSize: const Size.fromHeight(1), // Tinggi garis 1 piksel
          child: Container(
            color: context.warnaGaris, // Warna garis pemisah
            height: 1,
          ),
        ),
      ),
      body: Column( // Isi halaman disusun vertikal: daftar pesan lalu input bar
        children: [
          // ── Daftar pesan ──────────────────────────────────────
          Expanded( // Daftar pesan mengisi sisa ruang yang tersedia
            child: ListView.builder( // Daftar bergulir, item dibuat sesuai kebutuhan
              padding: const EdgeInsets.all(16), // Jarak isi dari tepi daftar
              itemCount: _messages.length, // Jumlah item sesuai jumlah pesan
              itemBuilder: (context, index) { // Fungsi pembuat tiap item pesan
                return ChatBubble(message: _messages[index]); // Tampilkan satu gelembung pesan
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────
          VoiceInputBar( // Bar input teks dan tombol suara di bawah
            controller: _controller, // Pengendali teks yang sama dipakai di sini
            onSend: _sendMessage, // Fungsi dipanggil saat pesan dikirim
            onVoice: () {
              // TODO: implementasi voice-to-text
            },
          ),
        ],
      ),
    );
  }
}
