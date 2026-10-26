import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Material Design)
import 'package:flutter/semantics.dart'; // Untuk SemanticsService (pengumuman ke pembaca layar)

import '../../../../core/services/aksesibilitas_controller.dart'; // Pola getaran berhasil/gagal
import '../../../../core/theme/theme_extensions.dart'; // Warna sesuai tema
import '../../../profile/data/profile_repository.dart'; // Penyimpanan data profil
import '../../../profile/data/validasi_profil.dart'; // Aturan isian wajib & format
import '../widgets/penanda_langkah.dart'; // Penanda "Langkah n dari 3"

/// ─────────────────────────────────────────────────────────────────
/// REGISTRASI PROFIL  –  Langkah 1 dari 3: isi informasi profil
///
/// Isian sama dengan halaman Informasi Profil, dengan aturan yang sama
/// (lihat validasi_profil.dart): semua wajib kecuali Alamat. Pengguna
/// tidak bisa lanjut ke langkah 2 sebelum semuanya benar.
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
  /// Satu FocusNode per kolom, supaya fokus bisa langsung dipindah ke
  /// kolom pertama yang salah.
  final Map<TextEditingController, FocusNode> _fokus = {};
  FocusNode _fokusUntuk(TextEditingController c) => _fokus.putIfAbsent(c, FocusNode.new);

  /// Pesan galat per kolom setelah tombol Lanjut ditekan.
  final Map<TextEditingController, String> _galat = {};

  /// Kolom wajib beserta nama & aturan formatnya. Alamat boleh kosong.
  Map<TextEditingController, (String, String? Function(String))> get _aturan => {
        _nama: ('Nama Lengkap', validasiWajib),
        _email: ('Email', validasiEmail),
        _noHp: ('Nomor HP', validasiNoHp),
        _namaUsaha: ('Nama Usaha', validasiWajib),
        _jenisUsaha: ('Jenis Usaha', validasiWajib),
      };
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
    for (final FocusNode f in _fokus.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _lanjut() async {
    if (_menyimpan) return;
    // Periksa semua kolom sekaligus, lalu sebutkan SEMUA yang salah dalam
    // satu pengumuman — pengguna tunanetra tidak perlu menelusuri form
    // untuk mencari kolom bertanda merah satu per satu.
    _galat.clear();
    final List<String> pesan = [];
    TextEditingController? pertama;
    _aturan.forEach((ctrl, aturan) {
      final String? g = aturan.$2(ctrl.text.trim());
      if (g != null) {
        _galat[ctrl] = g;
        pesan.add('${aturan.$1} $g');
        pertama ??= ctrl;
      }
    });
    if (pertama != null) {
      setState(() {});
      AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Belum bisa lanjut. ${pesan.join('. ')}.',
        Directionality.of(context),
      );
      _fokusUntuk(pertama!).requestFocus(); // Arahkan langsung ke kolom pertama yang salah
      return;
    }
    setState(() => _menyimpan = true);
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
    TextInputAction aksi = TextInputAction.next,
  }) {
    final bool wajib = _aturan.containsKey(controller);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        focusNode: _fokusUntuk(controller),
        keyboardType: keyboard,
        maxLines: maxLines,
        textInputAction: maxLines > 1 ? TextInputAction.newline : aksi,
        style: TextStyle(fontSize: 16, color: context.warnaTeksUtama),
        decoration: InputDecoration(
          // labelText dibacakan TalkBack sebagai nama kolom.
          labelText: wajib ? '$label (wajib)' : '$label (boleh dikosongkan)',
          errorText: _galat[controller] == null ? null : '$label ${_galat[controller]}',
          errorMaxLines: 2,
        ),
        onChanged: (_) {
          if (_galat.remove(controller) != null) setState(() {}); // Hapus galat saat mulai diperbaiki
        },
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
                      'Semua kolom wajib diisi, kecuali Alamat.',
                      style: TextStyle(fontSize: 15, color: context.warnaTeksMuted),
                    ),
                    const SizedBox(height: 16),
                    _judulBagian('DATA PRIBADI'),
                    _kolom(label: 'Nama Lengkap', controller: _nama),
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
