import 'package:flutter/material.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../widgets/voice_input_bar.dart';
import '../widgets/chat_bubble.dart';

/// ─────────────────────────────────────────────────────────────────
/// AI ASSISTANT PAGE  –  Halaman Chatbot AI Profil
///
/// Fitur:
///   • Chat berbasis teks dengan AI
///   • Input suara (voice-to-text)
///   • Riwayat percakapan
/// ─────────────────────────────────────────────────────────────────

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  // Daftar pesan percakapan (dummy untuk prototype)
  final List<ChatMessage> _messages = [
    const ChatMessage(
      text: 'Halo! Saya Asisten Keuangan AI Modio. Ada yang bisa saya bantu?',
      isUser: false,
    ),
  ];

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      // Tambah pesan user
      _messages.add(ChatMessage(text: text.trim(), isUser: true));
      _controller.clear();

      // Simulasi balasan AI (dummy)
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _messages.add(const ChatMessage(
              text: 'Terima kasih atas pertanyaannya! '
                    'Fitur AI sedang dalam pengembangan.',
              isUser: false,
            ));
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.latarMasuk,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: context.warnaMasuk,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Asisten AI'),
          ],
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: context.warnaTeksUtama,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: context.warnaGaris,
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Daftar pesan ──────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return ChatBubble(message: _messages[index]);
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────────────
          VoiceInputBar(
            controller: _controller,
            onSend: _sendMessage,
            onVoice: () {
              // TODO: implementasi voice-to-text
            },
          ),
        ],
      ),
    );
  }
}
