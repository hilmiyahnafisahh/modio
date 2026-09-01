import 'dart:async'; // Import untuk Timer (hitung mundur penguncian)

import 'package:flutter/material.dart'; // Import komponen UI utama Flutter
import '../../../../core/services/aksesibilitas_controller.dart'; // Controller untuk memicu getaran sesuai pengaturan aksesibilitas
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi context untuk warna tema
import '../../../auth/data/auth_repository.dart'; // Sumber data & logika autentikasi (verifikasi & simpan PIN)

/// ─────────────────────────────────────────────────────────────────
/// GANTI PIN PAGE  –  Ubah PIN keamanan pengguna
/// ─────────────────────────────────────────────────────────────────

class GantiPinPage extends StatefulWidget { // Halaman ganti PIN, butuh State karena tampilannya berubah-ubah
  const GantiPinPage({super.key}); // Constructor const, key diteruskan ke induk

  @override
  State<GantiPinPage> createState() => _GantiPinPageState(); // Membuat objek State untuk halaman ini
}

class _GantiPinPageState extends State<GantiPinPage> { // Kelas State: menyimpan data & logika halaman ganti PIN
  // Step: 0 = PIN lama, 1 = PIN baru, 2 = konfirmasi PIN baru
  int _step = 0; // Langkah saat ini dalam alur ganti PIN
  final List<String> _pins = ['', '', '']; // Menyimpan digit yang diketik untuk masing-masing dari 3 langkah

  static const int _pinLength = 6; // Jumlah digit PIN yang wajib diisi

  final List<String> _stepLabels = [ // Judul yang tampil untuk setiap langkah
    'Masukkan PIN saat ini', // Judul langkah 0
    'Buat PIN baru', // Judul langkah 1
    'Konfirmasi PIN baru', // Judul langkah 2
  ];

  final List<String> _stepSubs = [ // Subjudul/penjelasan singkat untuk setiap langkah
    'Masukkan 6 digit PIN Anda yang sekarang', // Subjudul langkah 0
    'Masukkan 6 digit PIN baru Anda', // Subjudul langkah 1
    'Masukkan kembali PIN baru untuk konfirmasi', // Subjudul langkah 2
  ];

  bool _hasError    = false; // Menandai apakah sedang menampilkan pesan error
  bool _obscure     = true; // Menandai apakah digit PIN disembunyikan (titik) atau ditampilkan
  bool _isChecking  = false; // sedang verifikasi/simpan ke DB
  String _errorMessage = ''; // Teks pesan error yang ditampilkan ke pengguna

  // AuthRepository, bukan ProfileRepository. Sebelumnya halaman ini
  // menyimpan PIN lewat ProfileRepository sementara layar kunci
  // aplikasi (PinLockPage) memverifikasi lewat AuthRepository —
  // dua sistem PIN terpisah yang tidak saling tahu. Akibatnya
  // mengganti PIN di sini tidak pernah benar-benar mengubah PIN yang
  // dipakai untuk membuka aplikasi; PIN lama tetap berlaku selamanya.
  final _repo = AuthRepository.instance; // Objek singleton untuk verifikasi & penyimpanan PIN

  // AuthRepository sendiri tidak menolak percobaan baru saat sedang
  // terkunci — ia akan tetap memproses dan menghitung ulang. UI inilah
  // yang wajib menahan input selama terkunci, persis pola yang sudah
  // dipakai di PinLockPage (layar kunci utama).
  int _sisaKunci = 0; // Sisa detik penguncian akibat terlalu banyak percobaan gagal
  Timer? _timer; // Timer hitung mundur penguncian, null kalau tidak sedang berjalan

  @override
  void dispose() { // Dipanggil saat halaman ini dihancurkan
    _timer?.cancel(); // Hentikan timer supaya tidak berjalan setelah widget hilang
    super.dispose(); // Panggil pembersihan bawaan Flutter
  }

  void _jalankanHitungMundur() { // Memulai hitung mundur detik penguncian
    _timer?.cancel(); // Hentikan timer lama jika masih ada, hindari dobel timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async { // Buat timer baru yang berjalan tiap 1 detik
      final int sisa = await _repo.sisaPenguncian(); // Tanyakan ke repository berapa detik penguncian tersisa
      if (!mounted) { // Jika halaman sudah tidak ada di layar
        t.cancel(); // Hentikan timer supaya tidak error memanggil setState
        return; // Keluar dari callback
      }
      setState(() { // Perbarui tampilan dengan nilai sisa waktu terbaru
        _sisaKunci = sisa; // Simpan sisa detik penguncian
        _errorMessage = sisa > 0 // Jika masih terkunci
            ? 'Terlalu banyak percobaan. Coba lagi dalam $sisa detik.' // Tampilkan pesan hitung mundur
            : ''; // Jika sudah tidak terkunci, kosongkan pesan
      });
      if (sisa <= 0) { // Jika waktu penguncian sudah habis
        t.cancel(); // Hentikan timer karena tidak diperlukan lagi
        setState(() => _hasError = false); // Hilangkan status error dari tampilan
      }
    });
  }

  void _onKeyTap(String val) { // Dipanggil saat salah satu tombol angka numpad ditekan
    if (_isChecking || _sisaKunci > 0) return; // jangan input saat proses DB/terkunci
    AksesibilitasController.instance.getar(); // Beri getaran ringan sebagai umpan balik ketukan
    final current = _pins[_step]; // Ambil PIN yang sedang diketik untuk langkah saat ini
    if (current.length < _pinLength) { // Hanya tambah digit jika belum mencapai panjang penuh
      setState(() { // Perbarui tampilan dengan digit baru
        _pins[_step] = current + val; // Tambahkan digit yang ditekan ke akhir PIN
        _hasError = false; // Hilangkan status error saat pengguna mulai mengetik lagi
      });
      if (_pins[_step].length == _pinLength) { // Jika PIN sudah lengkap 6 digit
        _onPinComplete(); // Proses PIN yang baru selesai diketik
      }
    }
  }

  void _onDelete() { // Dipanggil saat tombol hapus (DEL) ditekan
    if (_isChecking || _sisaKunci > 0) return; // Cegah hapus saat sedang proses DB atau terkunci
    AksesibilitasController.instance.getar(); // Beri getaran ringan sebagai umpan balik
    final current = _pins[_step]; // Ambil PIN langkah saat ini
    if (current.isNotEmpty) { // Hanya hapus jika ada isinya
      setState(() => _pins[_step] = current.substring(0, current.length - 1)); // Buang karakter terakhir dari PIN
    }
  }

  Future<void> _onPinComplete() async { // Dipanggil saat PIN pada langkah tertentu sudah 6 digit
    if (_step == 0) { // Langkah 0: memverifikasi PIN lama
      // Verifikasi PIN lama dari database
      setState(() => _isChecking = true); // Tampilkan indikator loading, cegah input lain
      final bool valid = await _repo.verifikasiPin(_pins[0]); // Tanyakan ke repository apakah PIN lama benar
      if (!mounted) return; // Batalkan jika halaman sudah ditutup selama menunggu
      setState(() => _isChecking = false); // Sembunyikan indikator loading

      if (!valid) { // Jika PIN lama salah
        // AuthRepository menghitung percobaan gagal dan mengunci
        // sementara setelah terlalu banyak salah — sama seperti layar
        // kunci, sebab keduanya kini memakai penghitung yang sama.
        // Tanpa pesan ini pengguna terkunci tanpa tahu sebabnya.
        final int kunci = await _repo.sisaPenguncian(); // Tanyakan berapa detik penguncian yang berlaku sekarang
        if (!mounted) return; // Batalkan jika halaman sudah ditutup
        setState(() { // Tampilkan status error ke pengguna
          _hasError = true; // Tandai sedang error
          _pins[0] = ''; // Kosongkan input agar pengguna mengetik ulang
          _sisaKunci = kunci; // Simpan sisa detik penguncian (0 jika belum terkunci)
          _errorMessage = kunci > 0 // Jika sudah terkunci
              ? 'Terlalu banyak percobaan. Coba lagi dalam $kunci detik.' // Pesan penguncian
              : 'PIN saat ini tidak sesuai'; // Pesan PIN salah biasa
        });
        if (kunci > 0) _jalankanHitungMundur(); // Mulai hitung mundur tampilan jika sedang terkunci
        return; // Hentikan proses, jangan lanjut ke langkah berikutnya
      }
    }

    if (_step == 1) { // Langkah 1: memeriksa kekuatan PIN baru
      // PIN terlalu mudah ditebak ditolak di sini juga — sama seperti
      // saat membuat PIN pertama kali di layar kunci, bukan cuma saat
      // pendaftaran awal.
      final String? galat = _repo.periksaKekuatan(_pins[1]); // Periksa apakah PIN baru terlalu lemah/mudah ditebak
      if (galat != null) { // Jika ada pesan kesalahan (PIN lemah)
        setState(() { // Tampilkan pesan error ke pengguna
          _hasError = true; // Tandai sedang error
          _pins[1] = ''; // Kosongkan input agar diketik ulang
          _errorMessage = galat; // Tampilkan alasan penolakan dari repository
        });
        return; // Hentikan proses, jangan lanjut
      }
    }

    if (_step == 2) { // Langkah 2: konfirmasi PIN baru harus sama dengan langkah 1
      // Validasi kecocokan PIN baru
      if (_pins[1] != _pins[2]) { // Jika PIN konfirmasi tidak sama dengan PIN baru
        setState(() { // Tampilkan pesan error
          _hasError = true; // Tandai sedang error
          _pins[2] = ''; // Kosongkan input konfirmasi
          _errorMessage = 'Konfirmasi PIN tidak cocok'; // Pesan penjelas
        });
        return; // Hentikan proses
      }
      // Simpan PIN baru ke database
      setState(() => _isChecking = true); // Tampilkan indikator loading saat menyimpan
      await _repo.simpanPin(_pins[1]); // Simpan PIN baru ke database lewat repository
      if (!mounted) return; // Batalkan jika halaman sudah ditutup
      setState(() => _isChecking = false); // Sembunyikan indikator loading
      _onSuccess(); // Tampilkan dialog sukses
      return; // Selesai, tidak perlu lanjut ke kode di bawah
    }

    setState(() { // Untuk langkah 0 dan 1 yang lolos validasi, lanjut ke langkah berikutnya
      _step++; // Naikkan nomor langkah
      _hasError = false; // Pastikan status error bersih di langkah baru
    });
  }

  void _onSuccess() { // Menampilkan dialog konfirmasi bahwa PIN berhasil diubah
    final scheme = Theme.of(context).colorScheme; // Ambil skema warna tema aktif
    showDialog( // Tampilkan dialog di atas halaman
      context: context, // Context halaman saat ini
      builder: (dialogContext) => AlertDialog( // Bangun isi dialog
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Sudut dialog melengkung
        title: Row( // Judul dialog berupa ikon + teks berdampingan
          children: [
            Icon(Icons.check_circle_rounded, color: scheme.primary, size: 28), // Ikon centang sebagai tanda berhasil
            const SizedBox(width: 8), // Jarak antara ikon dan teks
            Text('PIN Berhasil Diubah', // Teks judul dialog
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.warnaTeksUtama)), // Warna teks judul sesuai tema
          ],
        ),
        content: Text( // Isi penjelasan dialog
          'PIN Anda telah berhasil diperbarui. Gunakan PIN baru saat masuk ke aplikasi.', // Pesan untuk pengguna
          style: TextStyle(fontSize: 14, color: dialogContext.warnaTeksMuted), // Gaya teks isi, warna lebih redup
        ),
        actions: [ // Tombol aksi di bagian bawah dialog
          TextButton(
            onPressed: () { // Saat tombol OK ditekan
              Navigator.pop(dialogContext); // tutup dialog
              Navigator.pop(context); // kembali ke profil
            },
            child: Text('OK', // Label tombol
                style: TextStyle(
                    color: scheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) { // Membangun tampilan halaman ganti PIN
    final currentPin = _pins[_step]; // PIN yang sedang diketik pada langkah aktif
    final scheme = Theme.of(context).colorScheme; // Skema warna tema aktif

    return Scaffold( // Kerangka dasar halaman
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar mengikuti tema
      appBar: AppBar( // Bilah judul di atas halaman
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar app bar menyatu dengan halaman
        elevation: 0, // Tanpa bayangan di bawah app bar
        leading: IconButton( // Tombol kembali di kiri app bar
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), // Ikon panah kembali
          color: context.warnaTeksUtama, // Warna ikon sesuai tema
          onPressed: () { // Saat tombol kembali ditekan
            if (_step > 0) { // Jika bukan di langkah pertama
              setState(() { // Mundur satu langkah, bukan langsung keluar halaman
                _step--; // Turunkan nomor langkah
                _pins[_step] = ''; // Kosongkan input langkah tujuan agar mulai bersih
                _hasError = false; // Hilangkan status error
              });
            } else { // Jika sudah di langkah pertama
              Navigator.pop(context); // Keluar dari halaman ganti PIN sepenuhnya
            }
          },
          tooltip: 'Kembali', // Teks bantuan aksesibilitas tombol
        ),
        title: Text( // Judul di tengah app bar
          'Ganti PIN', // Teks judul halaman
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama, // Warna judul sesuai tema
          ),
        ),
        centerTitle: true, // Judul diposisikan di tengah app bar
        actions: [ // Tombol-tombol di kanan app bar
          IconButton( // Tombol untuk menampilkan/menyembunyikan digit PIN
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20), // Ikon berubah sesuai status obscure
            color: context.warnaTeksMuted, // Warna ikon redup
            onPressed: () => setState(() => _obscure = !_obscure), // Balik status tampil/sembunyi PIN
            tooltip: _obscure ? 'Tampilkan PIN' : 'Sembunyikan PIN', // Teks bantuan berubah sesuai status
          ),
        ],
      ),
      body: Column( // Isi utama halaman disusun vertikal
        children: [
          // ── Progres ────────────────────────────────────────────────
          Padding( // Jarak di sekitar indikator progres
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), // Jarak kiri-kanan 20, atas 8
            child: Row( // Tiga kotak progres berjajar horizontal
              children: List.generate(3, (i) { // Buat 3 kotak, satu untuk tiap langkah
                return Expanded( // Setiap kotak mengisi ruang yang sama rata
                  child: Container( // Kotak batang progres
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0), // Jarak kanan antar kotak, kecuali kotak terakhir
                    height: 4, // Tinggi batang progres
                    decoration: BoxDecoration( // Tampilan visual batang
                      borderRadius: BorderRadius.circular(2), // Sudut sedikit melengkung
                      color: i <= _step ? scheme.primary : context.warnaGaris, // Terisi warna utama jika sudah dilewati/sedang di langkah ini
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 40), // Jarak kosong setelah indikator progres

          // ── Label ─────────────────────────────────────────────────
          Text( // Judul langkah saat ini
            _stepLabels[_step], // Ambil teks judul sesuai langkah aktif
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.warnaTeksUtama, // Warna teks utama
            ),
          ),
          const SizedBox(height: 8), // Jarak kecil antara judul dan subjudul
          Text( // Subjudul penjelasan langkah saat ini
            _stepSubs[_step], // Ambil teks subjudul sesuai langkah aktif
            style: TextStyle(fontSize: 14, color: context.warnaTeksMuted), // Warna teks redup
          ),

          if (_hasError) ...[ // Tampilkan kotak pesan error hanya jika sedang ada error
            const SizedBox(height: 12), // Jarak sebelum kotak error
            Container( // Kotak pesan error
              margin: const EdgeInsets.symmetric(horizontal: 32), // Jarak kiri-kanan kotak
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Jarak dalam kotak
              decoration: BoxDecoration( // Tampilan visual kotak error
                color: context.latarKeluar, // Warna latar bernuansa merah/keluar
                borderRadius: BorderRadius.circular(10), // Sudut melengkung
                border: Border.all(color: context.warnaKeluar.withValues(alpha: 0.4)), // Garis tepi tipis warna error transparan
              ),
              child: Row( // Ikon dan teks error berdampingan
                children: [
                  Icon(Icons.error_outline, size: 16, color: context.warnaKeluar), // Ikon peringatan
                  const SizedBox(width: 8), // Jarak antara ikon dan teks
                  Expanded( // Teks mengisi sisa ruang agar bisa membungkus baris
                    child: Text(
                      _errorMessage, // Isi pesan error yang sedang aktif
                      style: TextStyle(
                        fontSize: 13,
                        color: context.warnaKeluar, // Warna teks error
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32), // Jarak sebelum indikator dot PIN

          // ── Indikator dot PIN ──────────────────────────────────────
          Row( // Deretan lingkaran indikator digit PIN
            mainAxisAlignment: MainAxisAlignment.center, // Lingkaran diposisikan di tengah horizontal
            children: List.generate(_pinLength, (i) { // Buat satu lingkaran untuk tiap posisi digit
              final filled = i < currentPin.length; // Lingkaran ini terisi jika sudah ada digit di posisi tersebut
              final char = (filled && !_obscure) ? currentPin[i] : null; // Tampilkan angka asli hanya jika terisi dan tidak disembunyikan
              return Container( // Satu lingkaran indikator
                width: 44, // Lebar lingkaran
                height: 44, // Tinggi lingkaran
                margin: const EdgeInsets.symmetric(horizontal: 6), // Jarak antar lingkaran
                decoration: BoxDecoration( // Tampilan visual lingkaran
                  shape: BoxShape.circle, // Bentuk lingkaran sempurna
                  color: filled ? scheme.primary : context.warnaKartu, // Warna terisi memakai warna utama, kosong pakai warna kartu
                  border: Border.all( // Garis tepi lingkaran
                    color: _hasError // Jika sedang error
                        ? context.warnaKeluar // Garis berwarna merah/error
                        : (filled ? scheme.primary : context.warnaGaris), // Kalau tidak error, ikuti status terisi
                    width: filled ? 0 : 1.5, // Tanpa garis saat terisi (warna sudah solid), garis tipis saat kosong
                  ),
                ),
                alignment: Alignment.center, // Isi lingkaran diposisikan di tengah
                child: char != null // Jika ada karakter untuk ditampilkan (tidak disembunyikan)
                    ? Text( // Tampilkan angka digit PIN
                        char, // Karakter digit yang ditampilkan
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimary, // Warna kontras dengan latar lingkaran
                        ),
                      )
                    : (filled // Jika terisi tapi disembunyikan (obscure)
                        ? Container( // Tampilkan titik kecil sebagai pengganti angka
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.onPrimary, // Warna titik kontras dengan latar lingkaran
                            ),
                          )
                        : null), // Jika belum terisi, tidak tampilkan apa-apa
              );
            }),
          ),

          const Spacer(), // Mendorong konten berikutnya (numpad) ke bagian bawah layar

          // ── Loading indicator saat verifikasi / simpan DB ─────────
          if (_isChecking) // Hanya tampil saat sedang proses ke database
            Padding( // Jarak di sekitar indikator loading
              padding: const EdgeInsets.only(bottom: 16), // Jarak bawah sebelum numpad
              child: CircularProgressIndicator( // Lingkaran putar tanda proses berjalan
                  strokeWidth: 2, color: scheme.primary), // Ketebalan garis dan warna indikator
            ),

          // ── Numpad ─────────────────────────────────────────────────
          _buildNumpad(), // Tampilkan tombol angka & hapus
          const SizedBox(height: 32), // Jarak kosong di bagian paling bawah
        ],
      ),
    );
  }

  Widget _buildNumpad() { // Widget bantu untuk membangun papan angka (numpad) PIN
    final bool nonaktif = _isChecking || _sisaKunci > 0; // Numpad dinonaktifkan saat sedang proses DB atau terkunci
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'DEL']; // Susunan tombol numpad, string kosong = sel kosong
    return Padding( // Jarak di sekeliling numpad
      padding: const EdgeInsets.symmetric(horizontal: 32), // Jarak kiri-kanan numpad
      child: GridView.builder( // Grid tombol numpad dibangun secara efisien per item
        shrinkWrap: true, // Grid hanya setinggi kontennya, tidak memenuhi sisa layar
        physics: const NeverScrollableScrollPhysics(), // Numpad tidak bisa digulir sendiri (ikut scroll induk jika ada)
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount( // Aturan tata letak grid
          crossAxisCount: 3, // 3 kolom per baris
          childAspectRatio: 1.8, // Rasio lebar:tinggi tiap tombol
          mainAxisSpacing: 8, // Jarak vertikal antar baris tombol
          crossAxisSpacing: 8, // Jarak horizontal antar kolom tombol
        ),
        itemCount: keys.length, // Jumlah tombol yang dibangun sesuai daftar keys
        itemBuilder: (_, i) { // Fungsi pembangun tiap tombol berdasarkan indeksnya
          final key = keys[i]; // Ambil label tombol pada indeks ini
          if (key.isEmpty) return const SizedBox(); // Sel kosong hanya diisi ruang kosong tanpa tombol
          if (key == 'DEL') { // Tombol khusus hapus
            return InkWell( // Area yang bisa diketuk dengan efek riak
              onTap: nonaktif ? null : _onDelete, // Nonaktifkan ketukan jika numpad sedang dinonaktifkan
              borderRadius: BorderRadius.circular(12), // Efek riak mengikuti sudut membulat
              child: Container( // Kotak visual tombol hapus
                decoration: BoxDecoration(
                  color: context.warnaKartu, // Warna latar tombol
                  borderRadius: BorderRadius.circular(12), // Sudut membulat
                ),
                alignment: Alignment.center, // Ikon diposisikan di tengah tombol
                child: Icon( // Ikon hapus (backspace)
                  Icons.backspace_outlined,
                  size: 22,
                  color: nonaktif ? context.warnaTeksMuted : context.warnaTeksUtama, // Warna pudar saat dinonaktifkan
                ),
              ),
            );
          }
          return InkWell( // Tombol angka biasa
            onTap: nonaktif ? null : () => _onKeyTap(key), // Nonaktifkan ketukan jika numpad sedang dinonaktifkan
            borderRadius: BorderRadius.circular(12), // Efek riak mengikuti sudut membulat
            child: Container( // Kotak visual tombol angka
              decoration: BoxDecoration(
                color: context.warnaKartu, // Warna latar tombol
                borderRadius: BorderRadius.circular(12), // Sudut membulat
              ),
              alignment: Alignment.center, // Teks angka diposisikan di tengah
              child: Text( // Label angka pada tombol
                key, // Karakter angka yang ditampilkan
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: nonaktif ? context.warnaTeksMuted : context.warnaTeksUtama, // Warna pudar saat dinonaktifkan
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
