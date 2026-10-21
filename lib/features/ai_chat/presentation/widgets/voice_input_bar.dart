import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import '../../../../core/theme/theme_extensions.dart'; // Extension untuk akses warna sesuai tema

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

class VoiceInputBar extends StatelessWidget { // Widget bar input, tanpa state internal
  final TextEditingController controller; // Pengendali teks kolom input

  /// Callback saat tombol kirim ditekan (menerima teks)
  final ValueChanged<String> onSend; // Fungsi dipanggil saat mengirim pesan

  /// Callback saat tombol mikrofon ditekan
  final VoidCallback onVoice; // Fungsi dipanggil saat tombol mic ditekan

  const VoiceInputBar({ // Konstruktor widget
    super.key, // Key diteruskan ke superclass
    required this.controller, // Wajib diisi
    required this.onSend, // Wajib diisi
    required this.onVoice, // Wajib diisi
  });

  @override
  Widget build(BuildContext context) { // Membangun tampilan bar input
    return Container( // Kotak pembungkus seluruh bar
      padding: EdgeInsets.only( // Jarak isi dari tepi kotak
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.of(context).viewInsets.bottom, // Tambah jarak bawah saat keyboard muncul
      ),
      decoration: BoxDecoration( // Dekorasi visual bar
        color: context.warnaKartu, // Warna latar bar
        border: Border( // Garis tepi hanya di bagian atas
          top: BorderSide(color: context.warnaGaris),
        ),
      ),
      child: Row( // Susun kolom teks dan tombol-tombol secara horizontal
        children: [
          // ── Field teks ─────────────────────────────────────────
          Expanded( // Kolom teks mengisi sisa ruang yang tersedia
            child: TextField( // Kolom input teks untuk mengetik pesan
              controller: controller, // Hubungkan ke pengendali teks
              style: TextStyle(color: context.warnaTeksUtama), // Warna teks yang diketik
              decoration: InputDecoration( // Dekorasi visual kolom input
                hintText: 'Tanya seputar keuangan Anda...', // Teks petunjuk saat kolom kosong
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: context.warnaTeksMuted,
                ),
                filled: true, // Aktifkan warna latar kolom
                fillColor: context.warnaKartuMenonjol, // Warna latar kolom input
                contentPadding: const EdgeInsets.symmetric( // Jarak isi teks dari tepi kolom
                  horizontal: 16,
                  vertical: 10,
                ),
                // Di mode terang latar kolom dan latar bar sama-sama putih,
                // jadi tanpa garis tepi kolom ketik tidak terlihat sama sekali.
                border: OutlineInputBorder( // Bentuk garis tepi kolom
                  borderRadius: BorderRadius.circular(24), // Sudut sangat membulat
                  borderSide: BorderSide(color: context.warnaGarisInput), // Garis tepi ≥ 3:1
                ),
                enabledBorder: OutlineInputBorder( // Garis tepi saat tidak difokus
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: context.warnaGarisInput),
                ),
                focusedBorder: OutlineInputBorder( // Garis tepi saat sedang mengetik
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary, width: 2),
                ),
              ),
              onSubmitted: onSend, // Kirim pesan saat menekan enter/submit
            ),
          ),
          const SizedBox(width: 8), // Jarak horizontal kolom teks ke tombol mic

          // ── Tombol Suara ─────────────────────────────────────
          Semantics( // Tombol ikon tanpa teks wajib punya label untuk pembaca layar
            label: 'Tanya dengan suara', // Teks yang dibacakan screen reader
            button: true, // Tandai sebagai tombol
            excludeSemantics: true, // Ikon di dalamnya tidak dibaca terpisah
            onTap: onVoice, // Aksi saat diaktifkan lewat screen reader
            child: GestureDetector( // Deteksi ketukan pada tombol mic
            onTap: onVoice, // Panggil callback suara saat ditekan
            child: Container( // Lingkaran tombol mic
              width: 48, // Target sentuh minimum 48 dp
              height: 48,
              decoration: BoxDecoration(
                color: context.latarMasuk, // Warna latar tombol
                shape: BoxShape.circle, // Bentuk lingkaran
              ),
              child: Icon( // Ikon mikrofon
                Icons.mic_outlined,
                size: 22,
                color: context.warnaMasuk,
              ),
            ),
          ),
          ),
          const SizedBox(width: 8), // Jarak horizontal tombol mic ke tombol kirim

          // ── Tombol Kirim ─────────────────────────────────────
          Semantics( // Tombol ikon tanpa teks wajib punya label untuk pembaca layar
            label: 'Kirim pertanyaan', // Teks yang dibacakan screen reader
            button: true, // Tandai sebagai tombol
            excludeSemantics: true, // Ikon di dalamnya tidak dibaca terpisah
            onTap: () => onSend(controller.text), // Aksi saat diaktifkan lewat screen reader
            child: GestureDetector( // Deteksi ketukan pada tombol kirim
            onTap: () => onSend(controller.text), // Kirim isi kolom teks saat ditekan
            child: Container( // Lingkaran tombol kirim
              width: 48, // Target sentuh minimum 48 dp
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary, // Warna latar tombol dari tema
                shape: BoxShape.circle, // Bentuk lingkaran
              ),
              child: Icon( // Ikon kirim
                Icons.send_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.onPrimary, // Warna ikon kontras dengan latar
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}
