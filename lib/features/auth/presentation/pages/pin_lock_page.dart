import 'dart:async'; // Untuk Timer (hitung mundur penguncian)

import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter
import 'package:flutter/semantics.dart'; // Untuk mengirim pengumuman ke screen reader
import 'package:flutter/services.dart'; // Untuk HapticFeedback (getaran) dan SystemUiOverlayStyle
import 'package:local_auth/local_auth.dart'; // Autentikasi biometrik (sidik jari/wajah) bawaan perangkat

import '../../../../core/services/aksesibilitas_controller.dart'; // Pola getaran berhasil/gagal
import '../../../../core/services/keamanan_controller.dart'; // Pengaturan metode masuk tambahan (suara/biometrik)
import '../../../../core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema
import '../../../../core/utils/spoken_digits.dart'; // Pengurai ucapan angka jadi deretan digit PIN
import '../../../transactions/presentation/widgets/voice_transaction_flow.dart'; // dengarkanUcapan(): lembar dengar suara generik
import '../../data/auth_repository.dart'; // Sumber data & logika autentikasi PIN
import '../../../onboarding/presentation/widgets/penanda_langkah.dart'; // Penanda "Langkah 2 dari 3" saat registrasi
import '../widgets/pin_keypad.dart'; // Widget keypad angka dan indikator titik PIN

/// ─────────────────────────────────────────────────────────────────
/// PIN LOCK PAGE  –  Layar kunci aplikasi
///
/// Menangani dua keadaan sekaligus:
///   • Belum ada PIN  → pengguna membuat PIN, dua langkah
///   • Sudah ada PIN  → pengguna memasukkan PIN
///
/// Seluruh verifikasi berjalan di perangkat. Pengguna tetap dapat
/// membuka aplikasinya tanpa koneksi internet.
/// ─────────────────────────────────────────────────────────────────

class PinLockPage extends StatefulWidget { // Halaman kunci PIN, punya state karena input berubah-ubah
  const PinLockPage({super.key, required this.onBerhasil, this.pendaftaran = false});

  /// Dipanggil setelah PIN diterima
  final VoidCallback onBerhasil; // Callback saat PIN sukses dibuat/diverifikasi

  /// true saat dipakai sebagai langkah 2 registrasi: menampilkan penanda
  /// langkah dan tidak mengumumkan "Membuka aplikasi" karena masih ada
  /// langkah pilih tema sesudahnya.
  final bool pendaftaran;

  @override
  State<PinLockPage> createState() => _PinLockPageState(); // Buat objek state terkait
}

enum _Tahap { memuat, pilihCara, buatBaru, konfirmasiBaru, masuk } // Tahap alur: memuat, pilih cara masuk, buat PIN, konfirmasi, atau login

class _PinLockPageState extends State<PinLockPage> {
  final AuthRepository _repo = AuthRepository.instance; // Ambil instance singleton repository auth
  final LocalAuthentication _localAuth = LocalAuthentication(); // Klien plugin biometrik bawaan perangkat

  _Tahap _tahap = _Tahap.memuat; // Tahap alur saat ini, mulai dari memuat
  String _pin = ''; // Digit PIN yang sedang diketik pengguna
  String _pinPertama = ''; // Simpan PIN pertama saat proses buat PIN (untuk dicocokkan)

  /// true bila di halaman pilihan awal pengguna memilih sidik jari dan
  /// jarinya sudah terverifikasi. Biometrik baru diaktifkan sesudah PIN
  /// cadangan tersimpan, supaya tidak ada keadaan "sidik jari aktif
  /// tanpa PIN".
  bool _pakaiSidikJari = false;
  String? _galat; // Pesan galat yang sedang ditampilkan, jika ada
  bool _sibuk = false; // Menandai sedang memproses (mencegah input ganda)

  int _sisaKunci = 0; // Sisa detik penguncian akibat terlalu banyak percobaan salah
  Timer? _timer; // Timer untuk hitung mundur penguncian

  /// PIN tetap kredensial dasar yang selalu tersedia (lihat
  /// KeamananController) — dua ini cuma menambah jalan masuk lain di
  /// SAMPING keypad, tidak pernah menggantikannya.
  bool get _bisaSuara =>
      _tahap == _Tahap.masuk && KeamananController.instance.suaraAktif.value; // Opsi suara hanya relevan saat login, bukan saat membuat PIN baru
  // Tombol Sidik Jari selalu tampil di layar masuk, tidak menunggu
  // sakelar Profil dinyalakan dulu. Sakelar biometrikAktif hanya
  // mengatur apakah permintaan sidik jari muncul OTOMATIS saat layar
  // terbuka (lihat _mulai). Di HP tanpa sidik jari, menekan tombol ini
  // memberi tahu bahwa biometrik tidak tersedia.
  bool get _bisaBiometrik =>
      KeamananController.biometrikTersedia && _tahap == _Tahap.masuk;

  @override
  void initState() { // Dipanggil sekali saat halaman pertama dibuat
    super.initState();
    _mulai(); // Mulai proses pengecekan status PIN
  }

  @override
  void dispose() { // Dipanggil saat halaman dihancurkan
    _timer?.cancel(); // Hentikan timer agar tidak berjalan setelah widget mati
    super.dispose();
  }

  Future<void> _mulai() async { // Cek apakah PIN sudah pernah dibuat dan status penguncian
    final bool ada = await _repo.sudahAdaPin(); // Cek apakah PIN sudah tersimpan
    final int kunci = await _repo.sisaPenguncian(); // Ambil sisa detik penguncian saat ini
    // Halaman pilihan cara masuk hanya berguna bila HP punya sidik jari
    // terdaftar; tanpa itu pilihannya cuma PIN, jadi langsung buat PIN.
    final bool adaSidikJari = !ada && await _sidikJariTersedia();
    if (!mounted) return; // Batalkan jika widget sudah dilepas sebelum data siap

    setState(() {
      _tahap = ada // Tentukan tahap awal sesuai ada/tidaknya PIN
          ? _Tahap.masuk
          : (adaSidikJari ? _Tahap.pilihCara : _Tahap.buatBaru);
      _sisaKunci = kunci; // Simpan sisa kunci ke state
    });

    if (kunci > 0) _jalankanHitungMundur(); // Jika masih terkunci, jalankan timer hitung mundur

    // Pengguna tunanetra tidak melihat layar apa yang terbuka.
    // Pengumuman ini yang memberitahunya.
    if (mounted) {
      SemanticsService.sendAnnouncement( // Umumkan judul halaman lewat screen reader
        View.of(context),
        _judul,
        Directionality.of(context),
      );
    }

    // Tawarkan biometrik segera begitu layar masuk terbuka — pengguna
    // yang mengaktifkannya di Profil biasanya berharap ini otomatis,
    // sama seperti pola umum aplikasi perbankan. Keypad PIN tetap utuh
    // di belakangnya kalau pengguna membatalkan atau biometrik gagal.
    if (ada && kunci == 0 && _bisaBiometrik && KeamananController.instance.biometrikAktif.value) {
      // Jeda sebentar supaya halaman (dan pengumuman judul di atas)
      // sempat selesai tampil/dibacakan dulu sebelum prompt sistem
      // menimpanya — tanpa ini keduanya tumpang tindih.
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _masukDenganBiometrik(otomatis: true);
      });
    }
  }

  void _jalankanHitungMundur() { // Menjalankan timer yang mengurangi sisa waktu kunci tiap detik
    _timer?.cancel(); // Hentikan timer lama jika ada, cegah dobel
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async { // Timer berulang tiap 1 detik
      final int sisa = await _repo.sisaPenguncian(); // Ambil sisa waktu kunci terbaru
      if (!mounted) { // Jika widget sudah dilepas
        t.cancel(); // Hentikan timer
        return;
      }
      setState(() => _sisaKunci = sisa); // Perbarui tampilan sisa waktu
      if (sisa <= 0) t.cancel(); // Hentikan timer saat waktu kunci habis
    });
  }

  String get _judul => switch (_tahap) { // Judul halaman berbeda tergantung tahap
        _Tahap.memuat => 'Memuat',
        _Tahap.pilihCara => 'Pilih cara masuk',
        _Tahap.buatBaru => _pakaiSidikJari ? 'Buat PIN cadangan' : 'Buat PIN baru',
        _Tahap.konfirmasiBaru => 'Ulangi PIN baru',
        _Tahap.masuk => 'Masukkan PIN Anda',
      };

  String get _keterangan => switch (_tahap) { // Teks keterangan tambahan sesuai tahap
        _Tahap.memuat => '',
        _Tahap.pilihCara => 'Bagaimana Anda ingin membuka Modio?',
        _Tahap.buatBaru => _pakaiSidikJari
            ? 'Dipakai bila sidik jari gagal dikenali'
            : 'PIN enam angka untuk mengunci catatan keuangan Anda',
        _Tahap.konfirmasiBaru => 'Masukkan sekali lagi untuk memastikan',
        _Tahap.masuk => 'Enam angka',
      };

  void _tekanAngka(String angka) { // Dipanggil saat pengguna menekan satu digit di keypad
    if (_sibuk || _sisaKunci > 0 || _pin.length >= 6) return; // Abaikan jika sedang sibuk, terkunci, atau sudah penuh

    setState(() {
      _pin += angka; // Tambahkan digit ke PIN yang sedang diketik
      _galat = null; // Hapus pesan galat lama saat mulai mengetik lagi
    });

    if (_pin.length == 6) _proses(); // Jika sudah 6 digit, langsung proses
  }

  void _hapus() { // Menghapus digit terakhir PIN
    if (_sibuk || _pin.isEmpty) return; // Abaikan jika sedang sibuk atau PIN sudah kosong
    setState(() => _pin = _pin.substring(0, _pin.length - 1)); // Potong satu karakter terakhir
  }

  Future<void> _proses() async { // Memproses PIN yang sudah lengkap 6 digit sesuai tahap
    setState(() => _sibuk = true); // Tandai sedang memproses agar input diabaikan sementara

    switch (_tahap) {
      case _Tahap.buatBaru: // Tahap membuat PIN baru (langkah pertama)
        final String? galat = _repo.periksaKekuatan(_pin); // Validasi kekuatan PIN (mis. bukan 123456)
        if (galat != null) { // Jika PIN dianggap lemah
          _tampilkanGalat(galat); // Tampilkan pesan galatnya
          return;
        }
        _pinPertama = _pin; // Simpan PIN pertama untuk dicocokkan di langkah konfirmasi
        setState(() {
          _pin = ''; // Kosongkan input untuk konfirmasi ulang
          _tahap = _Tahap.konfirmasiBaru; // Pindah ke tahap konfirmasi
          _sibuk = false; // Selesai memproses tahap ini
        });
        _umumkan('PIN diterima. Sekarang masukkan sekali lagi.'); // Beritahu screen reader

      case _Tahap.konfirmasiBaru: // Tahap konfirmasi ulang PIN baru
        if (_pin != _pinPertama) { // Jika PIN kedua tidak sama dengan yang pertama
          _tampilkanGalat('PIN tidak sama. Ulangi dari awal.'); // Tampilkan galat
          setState(() {
            _tahap = _Tahap.buatBaru; // Kembali ke tahap awal buat PIN
            _pinPertama = ''; // Reset PIN pertama yang tersimpan
          });
          return;
        }
        await _repo.simpanPin(_pin); // Simpan PIN yang sudah dikonfirmasi ke penyimpanan
        if (!mounted) return; // Batalkan jika widget sudah dilepas selama await
        if (_pakaiSidikJari) { // Pilihan di halaman awal: aktifkan sesudah PIN cadangan tersimpan
          await KeamananController.instance.ubahBiometrik(true);
          if (!mounted) return;
        }
        final String lanjut = widget.pendaftaran ? 'Lanjut ke pilihan tema.' : 'Membuka aplikasi.';
        _umumkan(_pakaiSidikJari
            ? 'PIN cadangan dibuat. Sidik jari aktif. $lanjut'
            : 'PIN berhasil dibuat. $lanjut'); // Umumkan keberhasilan
        AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
        widget.onBerhasil(); // Panggil callback bahwa PIN berhasil diproses

      case _Tahap.masuk: // Tahap login dengan PIN yang sudah ada
        await _verifikasiPinString(_pin); // Cocokkan PIN yang diketik lewat keypad

      case _Tahap.memuat || _Tahap.pilihCara: // Keypad tidak tampil di kedua tahap ini
        setState(() => _sibuk = false); // Reset status sibuk saja
    }
  }

  /// Inti verifikasi PIN untuk tahap masuk — dipakai bersama oleh
  /// keypad (lewat [_proses]) dan "Masuk dengan Suara" ([_masukDenganSuara]),
  /// supaya keduanya melewati persis aturan yang sama: penghitung
  /// percobaan, penguncian sementara, pola getaran, dan pengumuman ke
  /// pembaca layar. Dipanggil hanya SETELAH [_pin] diisi (baik lewat
  /// ketikan maupun hasil ucapan) sehingga [_sibuk] sudah aktif.
  Future<void> _verifikasiPinString(String pin) async { // Verifikasi satu deretan digit PIN terhadap yang tersimpan
    final bool cocok = await _repo.verifikasiPin(pin); // Cek apakah PIN yang diberikan benar
    if (!mounted) return; // Batalkan jika widget sudah dilepas selama await

    if (cocok) { // Jika PIN benar
      _umumkan('PIN benar. Membuka aplikasi.'); // Umumkan keberhasilan
      AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
      widget.onBerhasil(); // Panggil callback sukses
      return;
    }

    final int kunci = await _repo.sisaPenguncian(); // Cek apakah sekarang jadi terkunci
    if (!mounted) return; // Batalkan jika widget sudah dilepas selama await

    if (kunci > 0) { // Jika akun terkunci akibat terlalu banyak percobaan
      setState(() => _sisaKunci = kunci); // Simpan sisa waktu kunci
      _jalankanHitungMundur(); // Mulai timer hitung mundur
      _tampilkanGalat('Terlalu banyak percobaan. Coba lagi nanti.'); // Tampilkan pesan galat
    } else { // Jika belum terkunci, masih ada kesempatan mencoba lagi
      final int sisa = await _repo.sisaPercobaan(); // Ambil sisa jumlah percobaan yang diizinkan
      if (!mounted) return; // Batalkan jika widget sudah dilepas selama await
      _tampilkanGalat('PIN salah. Sisa $sisa percobaan.'); // Tampilkan galat dengan sisa percobaan
    }
  }

  /// Membuka lembar dengar suara, menguraikan hasilnya jadi 6 digit PIN
  /// murni di perangkat (lihat spoken_digits.dart — TANPA lewat AI/
  /// backend), lalu memverifikasinya lewat jalur yang sama persis
  /// dengan ketikan keypad. Ucapan yang gagal diuraikan diperlakukan
  /// sebagai "tidak dikenali", bukan "PIN salah" — supaya tidak diam-
  /// diam memakan jatah percobaan pengguna karena mikrofon salah dengar.
  Future<void> _masukDenganSuara() async { // Alur masuk dengan mengeja PIN lewat ucapan
    if (_sibuk || _sisaKunci > 0) return; // Abaikan jika sedang sibuk atau terkunci

    final String? teks = await dengarkanUcapan(context); // Dengarkan ucapan, tunggu hasil teksnya
    if (!mounted || teks == null || teks.trim().isEmpty) return; // Batalkan jika dibatalkan/tidak ada suara

    final String? pinTerurai = uraikanUcapanPin(teks); // Coba ubah ucapan jadi 6 digit PIN
    if (pinTerurai == null) { // Gagal dikenali sebagai 6 digit yang valid
      _tampilkanGalat(
        'PIN tidak dikenali dari ucapan. Eja tiap digit satu per satu, '
        'misalnya "tiga tiga empat lima nol satu".',
      );
      return;
    }

    setState(() {
      _pin = pinTerurai; // Tampilkan sebagai titik terisi di indikator, sama seperti hasil ketikan
      _sibuk = true; // Tandai sedang memproses agar input lain diabaikan sementara
    });
    await _verifikasiPinString(pinTerurai); // Verifikasi lewat jalur yang sama dengan ketikan keypad
  }

  /// Meminta autentikasi biometrik bawaan perangkat (sidik jari/wajah).
  /// [otomatis] membedakan pemicu diam-diam saat halaman baru terbuka
  /// (lihat [_mulai]) dari ketukan tombol eksplisit — kegagalan/pembatalan
  /// pada pemicu otomatis tidak perlu menampilkan pesan galat yang
  /// mengagetkan, sebab pengguna tidak diam-diam meminta apa pun.
  Future<void> _masukDenganBiometrik({bool otomatis = false}) async { // Alur masuk dengan biometrik bawaan perangkat
    if (_sibuk || _sisaKunci > 0) return; // Abaikan jika sedang sibuk atau terkunci

    try {
      final bool didukung = await _localAuth.isDeviceSupported(); // Cek apakah perangkat punya sensor biometrik
      final bool bisaCek = await _localAuth.canCheckBiometrics; // Cek apakah ada biometrik yang terdaftar
      if (!didukung || !bisaCek) { // Perangkat ini tidak punya biometrik yang bisa dipakai
        if (!otomatis) { // Hanya beri tahu bila pengguna sendiri yang menekan tombolnya
          _umumkan('Biometrik tidak tersedia di perangkat ini.');
        }
        return;
      }

      final bool berhasil = await _localAuth.authenticate( // Tampilkan prompt biometrik bawaan sistem
        localizedReason: 'Verifikasi identitas Anda untuk membuka Modio',
        options: const AuthenticationOptions(
          biometricOnly: true, // Jangan turun ke PIN/pola layar kunci OS — PIN Modio sendiri sudah jadi cadangannya
          stickyAuth: true, // Tetap berjalan walau app sempat pindah ke latar (mis. notifikasi masuk)
        ),
      );
      if (!mounted) return; // Batalkan jika widget sudah dilepas selama menunggu prompt

      if (berhasil) { // Biometrik cocok
        // Dipakai pertama kali lewat tombol: aktifkan supaya pembukaan
        // berikutnya langsung meminta sidik jari secara otomatis.
        if (!KeamananController.instance.biometrikAktif.value) {
          await KeamananController.instance.ubahBiometrik(true);
          if (!mounted) return;
        }
        _umumkan('Biometrik berhasil. Membuka aplikasi.'); // Umumkan keberhasilan
        AksesibilitasController.instance.getarBerhasil(); // Pola berhasil, sama seperti PIN benar
        widget.onBerhasil(); // Panggil callback sukses
      } else if (!otomatis) { // Dibatalkan/gagal cocok, dan pengguna sendiri yang meminta
        _umumkan('Biometrik dibatalkan. Silakan masukkan PIN.');
      }
      // Gagal/batal pada pemicu otomatis: diam saja, keypad PIN di
      // baliknya sudah selalu tersedia sebagai jalan masuk.
    } catch (_) { // Mis. sensor bermasalah, atau tidak ada biometrik terdaftar di OS
      if (!otomatis) {
        _umumkan('Biometrik tidak bisa digunakan saat ini. Silakan masukkan PIN.');
      }
    }
  }

  Future<bool> _sidikJariTersedia() async { // HP punya sensor DAN sidik jari terdaftar?
    if (!KeamananController.biometrikTersedia) return false; // Fitur dimatikan dari sakelar utama
    try {
      return await _localAuth.isDeviceSupported() && await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false; // Sensor bermasalah: anggap tidak tersedia, PIN tetap bisa dipakai
    }
  }

  /// Pilihan di halaman "Pilih cara masuk". Sidik jari diverifikasi
  /// dulu supaya pengguna yakin jarinya dikenali sebelum
  /// mengandalkannya, lalu tetap diminta membuat PIN cadangan.
  Future<void> _pilihCaraMasuk({required bool sidikJari}) async {
    if (_sibuk) return;
    if (sidikJari) {
      setState(() => _sibuk = true);
      bool berhasil = false;
      try {
        berhasil = await _localAuth.authenticate(
          localizedReason: 'Tempelkan jari untuk memakai sidik jari saat membuka Modio',
          options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
        );
      } catch (_) {
        berhasil = false;
      }
      if (!mounted) return;
      setState(() => _sibuk = false);
      if (!berhasil) {
        AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
        _umumkan('Sidik jari belum dikenali. Coba lagi, atau pilih PIN saja.');
        return; // Tetap di halaman pilihan
      }
      AksesibilitasController.instance.getarBerhasil(); // Pola berhasil: 1 getaran pendek
    }
    setState(() {
      _pakaiSidikJari = sidikJari;
      _tahap = _Tahap.buatBaru;
    });
    _umumkan(sidikJari
        ? 'Sidik jari dikenali. Sekarang buat PIN cadangan enam angka.'
        : 'Buat PIN baru enam angka.');
  }

  /// Halaman pertama sekali sebelum PIN dibuat: pilih PIN saja atau
  /// sidik jari (dengan PIN cadangan).
  Widget _buildPilihCara(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.pendaftaran) ...[
                const PenandaLangkah(langkah: 2),
                const SizedBox(height: 28),
              ],
              Icon(Icons.lock_outline, size: 52, color: scheme.primary),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  _judul,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.warnaTeksUtama),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _keterangan,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: context.warnaTeksMuted),
              ),
              const SizedBox(height: 32),
              _KartuCaraMasuk(
                icon: Icons.fingerprint_rounded,
                judul: 'Sidik jari',
                keterangan: 'Tempelkan jari untuk masuk. Anda tetap membuat PIN sebagai cadangan.',
                onTap: _sibuk ? null : () => _pilihCaraMasuk(sidikJari: true),
              ),
              const SizedBox(height: 12),
              _KartuCaraMasuk(
                icon: Icons.dialpad_rounded,
                judul: 'PIN saja',
                keterangan: 'Masuk dengan enam angka. Sidik jari bisa diaktifkan nanti di Profil.',
                onTap: _sibuk ? null : () => _pilihCaraMasuk(sidikJari: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _tampilkanGalat(String pesan) { // Menampilkan pesan galat dan mereset input
    // Pola gagal (2 getaran pendek), berbeda dari 1 getaran saat
    // berhasil dan getaran ringan saat menekan tombol angka.
    AksesibilitasController.instance.getarGagal(); // Pola gagal: 2 getaran pendek
    setState(() {
      _galat = pesan; // Simpan pesan galat untuk ditampilkan
      _pin = ''; // Kosongkan input PIN
      _sibuk = false; // Selesai memproses, izinkan input lagi
    });
    _umumkan(pesan); // Umumkan pesan galat lewat screen reader
  }

  void _umumkan(String pesan) { // Helper mengirim pengumuman ke screen reader
    if (!mounted) return; // Jangan umumkan jika widget sudah dilepas
    SemanticsService.sendAnnouncement(
      View.of(context),
      pesan, // Teks yang akan dibacakan
      Directionality.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tahap == _Tahap.pilihCara) return _buildPilihCara(context); // Halaman pilihan cara masuk

    if (_tahap == _Tahap.memuat) { // Selagi masih memuat status PIN
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()), // Tampilkan indikator loading
      );
    }

    final bool terkunci = _sisaKunci > 0; // Status apakah sedang dalam masa penguncian
    final scheme = Theme.of(context).colorScheme; // Skema warna tema aktif

    return AnnotatedRegion<SystemUiOverlayStyle>( // Atur tampilan status bar sistem (warna ikon dsb.)
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Status bar transparan
        statusBarIconBrightness:
            context.gelap ? Brightness.light : Brightness.dark, // Ikon status bar kontras sesuai tema
        statusBarBrightness: context.gelap ? Brightness.dark : Brightness.light, // Untuk iOS
      ),
      child: Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea( // Hindari area sistem seperti notch/status bar
        child: Column(
          children: [
            if (widget.pendaftaran && _tahap != _Tahap.masuk)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: PenandaLangkah(langkah: 2),
              ),
            const Spacer(flex: 2), // Ruang kosong fleksibel di atas

            Icon(
              terkunci ? Icons.lock_clock : Icons.lock_outline, // Ikon berubah saat terkunci
              size: 52,
              color: scheme.primary,
            ),
            const SizedBox(height: 20),

            Text(
              _judul, // Judul sesuai tahap saat ini
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.warnaTeksUtama,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                terkunci
                    ? 'Coba lagi dalam $_sisaKunci detik' // Tampilkan hitung mundur jika terkunci
                    : _keterangan, // Kalau tidak, tampilkan keterangan biasa
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.warnaTeksMuted,
                ),
              ),
            ),

            const SizedBox(height: 28),
            PinDots(nilai: _pin, galat: _galat != null), // Indikator titik jumlah digit yang sudah diisi

            if (_galat != null) ...[ // Tampilkan kotak pesan galat jika ada
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: context.latarKeluar, // Warna latar bernuansa error/keluar
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.warnaKeluar),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline, // Ikon peringatan
                      size: 20,
                      color: context.warnaKeluar,
                    ),
                    const SizedBox(width: 10),
                    Expanded( // Teks galat mengisi sisa ruang agar bisa wrap
                      child: Text(
                        _galat!,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.warnaKeluar,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(flex: 3), // Ruang kosong fleksibel di bawah, lebih besar dari atas

            PinKeypad( // Keypad angka untuk input PIN
              onAngka: _tekanAngka, // Callback saat digit ditekan
              onHapus: _hapus, // Callback saat tombol hapus ditekan
              nonaktif: _sibuk || terkunci, // Nonaktifkan keypad saat sibuk atau terkunci
            ),

            // Jalan masuk tambahan di samping keypad — hanya muncul
            // kalau sakelarnya aktif di Profil > Mode Suara/Autentikasi
            // Biometrik. Tidak pernah menggantikan keypad, cuma
            // melengkapinya (lihat KeamananController).
            if (!terkunci && (_bisaSuara || _bisaBiometrik)) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_bisaBiometrik)
                    _TombolMasukAlternatif(
                      icon: Icons.fingerprint_rounded,
                      label: 'Sidik Jari',
                      onTap: _sibuk ? null : () => _masukDenganBiometrik(),
                    ),
                  if (_bisaBiometrik && _bisaSuara) const SizedBox(width: 20),
                  if (_bisaSuara)
                    _TombolMasukAlternatif(
                      icon: Icons.mic_rounded,
                      label: 'Ucapkan PIN',
                      onTap: _sibuk ? null : _masukDenganSuara,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 28),
          ],
        ),
      ),
      ),
    );
  }
}

/// Tombol jalan masuk alternatif (Sidik Jari/Ucapkan PIN) di layar
/// kunci. `onTap` null berarti nonaktif sementara (mis. sedang
/// memproses), ditampilkan pudar dan tidak bisa diketuk.
class _TombolMasukAlternatif extends StatelessWidget { // Tombol bulat + label untuk satu opsi masuk tambahan
  final IconData icon; // Ikon yang mewakili opsi ini
  final String label; // Nama opsi yang ditampilkan & dibacakan
  final VoidCallback? onTap; // Aksi saat diketuk, null bila nonaktif

  const _TombolMasukAlternatif({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool aktif = onTap != null; // Status aktif/nonaktif tombol ini
    final Color warna = aktif
        ? Theme.of(context).colorScheme.primary
        : context.warnaTeksMuted;

    return Semantics(
      button: true,
      enabled: aktif,
      label: label,
      hint: aktif ? 'Ketuk dua kali untuk memilih' : null,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // 56dp: ukuran sentuh minimum, bukan cuma bungkus ikon —
          // target kecil sulit dijangkau tepat tanpa melihat layar.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 28, color: warna),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: warna,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu pilihan di halaman "Pilih cara masuk": kartu besar yang seluruh
/// permukaannya bisa diketuk, dibacakan sebagai satu tombol utuh.
class _KartuCaraMasuk extends StatelessWidget {
  const _KartuCaraMasuk({
    required this.icon,
    required this.judul,
    required this.keterangan,
    required this.onTap,
  });

  final IconData icon; // Ikon cara masuk
  final String judul; // Nama pilihan
  final String keterangan; // Penjelasan singkat
  final VoidCallback? onTap; // null saat sedang memproses

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$judul. $keterangan',
      hint: 'Ketuk dua kali untuk memilih',
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: context.warnaKartu,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.warnaGarisInput, width: 1.5), // batas kontrol >= 3:1
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, size: 36, color: scheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(judul,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.warnaTeksUtama)),
                      const SizedBox(height: 4),
                      Text(keterangan, style: TextStyle(fontSize: 14, color: context.warnaTeksMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.warnaTeksMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
