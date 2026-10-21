import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import 'package:flutter/semantics.dart'; // Untuk SemanticsService (pengumuman ke pembaca layar)

import '../../../../core/services/aksesibilitas_controller.dart'; // Pola getaran berhasil/gagal
import '../../../../core/theme/theme_extensions.dart'; // Warna sesuai tema
import '../../../profile/data/profile_repository.dart'; // Penyimpanan data profil
import '../widgets/penanda_langkah.dart'; // Penanda "Langkah n dari 3"

/// ─────────────────────────────────────────────────────────────────
/// REGISTRASI PROFIL  –  Langkah 1 dari 3: isi informasi profil
///
/// Isian sama dengan halaman Informasi Profil. Hanya Nama Lengkap yang
/// wajib (dipakai untuk sapaan di Dashboard); sisanya boleh dikosongkan
/// dan dilengkapi nanti lewat ikon edit di halaman Profil.
/// ─────────────────────────────────────────────────────────────────
class RegistrasiProfilPage extends StatefulWidget {
  const RegistrasiProfilPage({super.key, required this.onLanjut});

  final VoidCallback onLanjut; // Dipanggil setelah profil tersimpan

  @override
  State<RegistrasiProfilPage> createState() => _RegistrasiProfilPageState();
}

class _RegistrasiProfilPageState extends State<RegistrasiProfilPage> {
  final _nama = TextEditingController();
  final _email = TextEditingController();
  final _noHp = TextEditingController();
  final _namaUsaha = TextEditingController();
  final _jenisUsaha = TextEditingController();
  final _alamat = TextEditingController();
  final FocusNode _fokusNama = FocusNode();

  String? _galatNama; // Pesan galat di bawah kolom Nama Lengkap
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _isiUlang();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SemanticsService.sendAnnouncement(View.of(context),
          'Langkah 1 dari 3. Isi informasi profil.', Directionality.of(context));
    });
  }

  /// Bila registrasi sempat terhenti sebelum PIN dibuat, isian yang
  /// sudah tersimpan ditampilkan lagi alih-alih diminta mengetik ulang.
  Future<void> _isiUlang() async {
    try {
      final Map<String, String> p = await ProfileRepository.instance.bacaProfil();
      if (!mounted) return;
      setState(() {
        _nama.text = p['profil_nama'] ?? '';
        _email.text = p['profil_email'] ?? '';
        _noHp.text = p['profil_no_hp'] ?? '';
        _namaUsaha.text = p['profil_nama_usaha'] ?? '';
        _jenisUsaha.text = p['profil_jenis_usaha'] ?? '';
        _alamat.text = p['profil_alamat'] ?? '';
      });
    } catch (_) {
      // Belum ada data: biarkan kosong
    }
  }

  @override
  void dispose() {
    for (final c in [_nama, _email, _noHp, _namaUsaha, _jenisUsaha, _alamat]) {
      c.dispose();
    }
    _fokusNama.dispose();
    super.dispose();
  }

  Future<void> _lanjut() async {
    if (_menyimpan) return;
    if (_nama.text.trim().isEmpty) {
      const String pesan = 'Nama lengkap belum diisi.';
      setState(() => _galatNama = pesan);
      AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
      SemanticsService.sendAnnouncement(View.of(context), pesan, Directionality.of(context));
      _fokusNama.requestFocus(); // Arahkan langsung ke kolom yang perlu diperbaiki
      return;
    }
    setState(() {
      _galatNama = null;
      _menyimpan = true;
    });
    try {
      await ProfileRepository.instance.simpanInfoPribadi(
        nama: _nama.text.trim(),
        email: _email.text.trim(),
        noHp: _noHp.text.trim(),
        namaUsaha: _namaUsaha.text.trim(),
        jenisUsaha: _jenisUsaha.text.trim(),
        alamat: _alamat.text.trim(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      AksesibilitasController.instance.getarGagal();
      SemanticsService.sendAnnouncement(
          View.of(context), 'Profil belum tersimpan. Coba lagi.', Directionality.of(context));
      return;
    }
    if (!mounted) return;
    AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
    widget.onLanjut();
  }

  Widget _kolom({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboard,
    int maxLines = 1,
    bool wajib = false,
    String? galat,
    FocusNode? focusNode,
    TextInputAction aksi = TextInputAction.next,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboard,
        maxLines: maxLines,
        textInputAction: maxLines > 1 ? TextInputAction.newline : aksi,
        style: TextStyle(fontSize: 16, color: context.warnaTeksUtama),
        decoration: InputDecoration(
          // labelText dibacakan TalkBack sebagai nama kolom.
          labelText: wajib ? '$label (wajib)' : '$label (boleh dikosongkan)',
          errorText: galat,
        ),
      ),
    );
  }

  Widget _judulBagian(String teks) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Semantics(
          header: true,
          child: Text(
            teks,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: context.warnaTeksMuted),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PenandaLangkah(langkah: 1),
                    const SizedBox(height: 24),
                    Semantics(
                      header: true,
                      child: Text(
                        'Isi informasi profil',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.warnaTeksUtama),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nama Anda dipakai untuk sapaan di Dashboard. Isian lain boleh dilengkapi nanti di Profil.',
                      style: TextStyle(fontSize: 15, color: context.warnaTeksMuted),
                    ),
                    const SizedBox(height: 16),
                    _judulBagian('DATA PRIBADI'),
                    _kolom(
                        label: 'Nama Lengkap',
                        controller: _nama,
                        wajib: true,
                        galat: _galatNama,
                        focusNode: _fokusNama),
                    _kolom(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress),
                    _kolom(label: 'Nomor HP', controller: _noHp, keyboard: TextInputType.phone),
                    _judulBagian('DATA USAHA'),
                    _kolom(label: 'Nama Usaha', controller: _namaUsaha),
                    _kolom(label: 'Jenis Usaha', controller: _jenisUsaha),
                    _kolom(label: 'Alamat', controller: _alamat, maxLines: 3),
                  ],
                ),
              ),
            ),
            // Tombol tetap di bawah, tidak ikut tergulir, supaya selalu
            // mudah ditemukan dan menjadi elemen terakhir dalam urutan fokus.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _menyimpan ? null : _lanjut,
                  child: Text(_menyimpan ? 'Menyimpan...' : 'Lanjut', style: const TextStyle(fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
