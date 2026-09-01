import 'dart:async'; // Untuk Timer (hitung mundur penguncian)

import 'package:flutter/material.dart'; // Widget dan tema dasar Flutter
import 'package:flutter/semantics.dart'; // Untuk mengirim pengumuman ke screen reader
import 'package:flutter/services.dart'; // Untuk HapticFeedback (getaran) dan SystemUiOverlayStyle

import '../../../../core/theme/theme_extensions.dart'; // Extension context.warnaXxx untuk warna sesuai tema
import '../../data/auth_repository.dart'; // Sumber data & logika autentikasi PIN
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
  const PinLockPage({super.key, required this.onBerhasil});

  /// Dipanggil setelah PIN diterima
  final VoidCallback onBerhasil; // Callback saat PIN sukses dibuat/diverifikasi

  @override
  State<PinLockPage> createState() => _PinLockPageState(); // Buat objek state terkait
}

enum _Tahap { memuat, buatBaru, konfirmasiBaru, masuk } // Tahap alur: memuat data, buat PIN, konfirmasi, atau login

class _PinLockPageState extends State<PinLockPage> {
  final AuthRepository _repo = AuthRepository.instance; // Ambil instance singleton repository auth

  _Tahap _tahap = _Tahap.memuat; // Tahap alur saat ini, mulai dari memuat
  String _pin = ''; // Digit PIN yang sedang diketik pengguna
  String _pinPertama = ''; // Simpan PIN pertama saat proses buat PIN (untuk dicocokkan)
  String? _galat; // Pesan galat yang sedang ditampilkan, jika ada
  bool _sibuk = false; // Menandai sedang memproses (mencegah input ganda)

  int _sisaKunci = 0; // Sisa detik penguncian akibat terlalu banyak percobaan salah
  Timer? _timer; // Timer untuk hitung mundur penguncian

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
    if (!mounted) return; // Batalkan jika widget sudah dilepas sebelum data siap

    setState(() {
      _tahap = ada ? _Tahap.masuk : _Tahap.buatBaru; // Tentukan tahap awal sesuai ada/tidaknya PIN
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
        _Tahap.buatBaru => 'Buat PIN baru',
        _Tahap.konfirmasiBaru => 'Ulangi PIN baru',
        _Tahap.masuk => 'Masukkan PIN Anda',
      };

  String get _keterangan => switch (_tahap) { // Teks keterangan tambahan sesuai tahap
        _Tahap.memuat => '',
        _Tahap.buatBaru =>
          'PIN enam angka untuk mengunci catatan keuangan Anda',
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
        _umumkan('PIN berhasil dibuat. Membuka aplikasi.'); // Umumkan keberhasilan
        HapticFeedback.mediumImpact(); // Getaran sedang sebagai konfirmasi sukses
        widget.onBerhasil(); // Panggil callback bahwa PIN berhasil diproses

      case _Tahap.masuk: // Tahap login dengan PIN yang sudah ada
        final bool cocok = await _repo.verifikasiPin(_pin); // Cek apakah PIN yang diketik benar
        if (!mounted) return; // Batalkan jika widget sudah dilepas selama await

        if (cocok) { // Jika PIN benar
          _umumkan('PIN benar. Membuka aplikasi.'); // Umumkan keberhasilan
          HapticFeedback.mediumImpact(); // Getaran sedang sebagai konfirmasi
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

      case _Tahap.memuat: // Kasus tahap masih memuat (seharusnya tidak terjadi saat proses dipanggil)
        setState(() => _sibuk = false); // Reset status sibuk saja
    }
  }

  void _tampilkanGalat(String pesan) { // Menampilkan pesan galat dan mereset input
    // Getaran kuat sebagai penanda kegagalan. Berbeda dari getaran
    // ringan saat menekan tombol, sehingga terbedakan tanpa melihat.
    HapticFeedback.heavyImpact(); // Getaran kuat menandakan kegagalan
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
            const SizedBox(height: 28),
          ],
        ),
      ),
      ),
    );
  }
}
