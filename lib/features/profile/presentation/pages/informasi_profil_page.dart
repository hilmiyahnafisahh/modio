import 'package:flutter/material.dart'; // Import komponen UI utama Flutter
import '../../../../core/theme/app_colors.dart'; // Palet warna dasar aplikasi
import '../../../../core/theme/theme_extensions.dart'; // Ekstensi context untuk warna tema
import '../../../../core/services/profile_update_service.dart'; // Service notifikasi perubahan profil ke halaman lain
import '../../data/profile_repository.dart'; // Sumber data profil pengguna (baca/simpan)

/// ─────────────────────────────────────────────────────────────────
/// INFORMASI PROFIL PAGE  –  Tampil & edit data pengguna (persisten)
/// ─────────────────────────────────────────────────────────────────

class InformasiProfilPage extends StatefulWidget { // Halaman info profil, butuh State karena bisa berpindah mode lihat/edit
  const InformasiProfilPage({super.key}); // Constructor const, meneruskan key ke induk

  @override
  State<InformasiProfilPage> createState() => _InformasiProfilPageState(); // Membuat objek State halaman ini
}

class _InformasiProfilPageState extends State<InformasiProfilPage> { // Kelas State: data & logika halaman info profil
  bool _isEditing  = false; // Menandai apakah form sedang dalam mode bisa diedit
  bool _isLoading  = true; // Menandai apakah data profil masih dimuat dari database
  bool _isSaving   = false; // Menandai apakah sedang proses menyimpan perubahan

  final _namaCtrl       = TextEditingController(); // Controller input untuk field nama lengkap
  final _emailCtrl      = TextEditingController(); // Controller input untuk field email
  final _noHpCtrl       = TextEditingController(); // Controller input untuk field nomor HP
  final _namaUsahaCtrl  = TextEditingController(); // Controller input untuk field nama usaha
  final _jenisUsahaCtrl = TextEditingController(); // Controller input untuk field jenis usaha
  final _alamatCtrl     = TextEditingController(); // Controller input untuk field alamat

  final _repo = ProfileRepository.instance; // Objek singleton untuk membaca/menyimpan data profil

  @override
  void initState() { // Dipanggil sekali saat halaman pertama kali dibuat
    super.initState(); // Panggil inisialisasi bawaan Flutter
    _muatData(); // Mulai memuat data profil dari database
  }

  @override
  void dispose() { // Dipanggil saat halaman dihancurkan
    _namaCtrl.dispose(); // Bersihkan controller nama agar tidak bocor memori
    _emailCtrl.dispose(); // Bersihkan controller email
    _noHpCtrl.dispose(); // Bersihkan controller nomor HP
    _namaUsahaCtrl.dispose(); // Bersihkan controller nama usaha
    _jenisUsahaCtrl.dispose(); // Bersihkan controller jenis usaha
    _alamatCtrl.dispose(); // Bersihkan controller alamat
    super.dispose(); // Panggil pembersihan bawaan Flutter
  }

  // ── Load dari DB ─────────────────────────────────────────────────
  Future<void> _muatData() async { // Mengambil data profil tersimpan dan mengisi form
    final data = await _repo.bacaProfil(); // Baca data profil dari repository (database)
    if (!mounted) return; // Batalkan jika halaman sudah ditutup selama menunggu
    setState(() { // Perbarui tampilan dengan data yang dimuat
      _namaCtrl.text       = data['profil_nama']        ?? ''; // Isi field nama, kosong jika belum ada data
      _emailCtrl.text      = data['profil_email']       ?? ''; // Isi field email
      _noHpCtrl.text       = data['profil_no_hp']       ?? ''; // Isi field nomor HP
      _namaUsahaCtrl.text  = data['profil_nama_usaha']  ?? ''; // Isi field nama usaha
      _jenisUsahaCtrl.text = data['profil_jenis_usaha'] ?? ''; // Isi field jenis usaha
      _alamatCtrl.text     = data['profil_alamat']      ?? ''; // Isi field alamat
      _isLoading = false; // Tandai proses pemuatan selesai
    });
  }

  // ── Simpan ke DB ─────────────────────────────────────────────────
  Future<void> _simpan() async { // Menyimpan perubahan form ke database
    setState(() => _isSaving = true); // Tampilkan status sedang menyimpan
    try { // Coba proses penyimpanan, tangkap jika gagal
      await _repo.simpanInfoPribadi( // Kirim seluruh data form ke repository untuk disimpan
        nama:        _namaCtrl.text.trim(), // Nama tanpa spasi berlebih di awal/akhir
        email:       _emailCtrl.text.trim(), // Email tanpa spasi berlebih
        noHp:        _noHpCtrl.text.trim(), // Nomor HP tanpa spasi berlebih
        namaUsaha:   _namaUsahaCtrl.text.trim(), // Nama usaha tanpa spasi berlebih
        jenisUsaha:  _jenisUsahaCtrl.text.trim(), // Jenis usaha tanpa spasi berlebih
        alamat:      _alamatCtrl.text.trim(), // Alamat tanpa spasi berlebih
      );
      if (!mounted) return; // Batalkan lanjutan jika halaman sudah ditutup
      setState(() { // Perbarui status setelah berhasil simpan
        _isEditing = false; // Keluar dari mode edit, kembali ke mode lihat
        _isSaving  = false; // Matikan status sedang menyimpan
      });
      // Notifikasi ke dashboard dan halaman lain bahwa profil telah diperbarui
      ProfileUpdateService().notifyProfileUpdated(); // Beri tahu bagian lain aplikasi agar ikut memuat ulang data
      if (!mounted) return; // Batalkan jika halaman sudah ditutup sebelum menampilkan snackbar
      ScaffoldMessenger.of(context).showSnackBar( // Tampilkan notifikasi kecil di bawah layar
        SnackBar( // Isi notifikasi sukses
          content: Text(
            'Profil berhasil diperbarui', // Pesan sukses
            style: TextStyle(
              color: context.gelap ? AppColors.darkBg : AppColors.white, // Warna teks kontras sesuai mode gelap/terang
            ),
          ),
          backgroundColor: context.warnaMasuk, // Warna latar hijau/masuk sebagai tanda sukses
          behavior: SnackBarBehavior.floating, // Notifikasi mengambang, tidak menempel di tepi bawah
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Sudut notifikasi membulat
        ),
      );
    } catch (_) { // Jika terjadi error saat menyimpan
      if (!mounted) return; // Batalkan jika halaman sudah ditutup
      setState(() => _isSaving = false); // Matikan status sedang menyimpan meski gagal
      ScaffoldMessenger.of(context).showSnackBar( // Tampilkan notifikasi kegagalan
        SnackBar( // Isi notifikasi gagal
          content: Text(
            'Gagal menyimpan. Coba lagi.', // Pesan kegagalan untuk pengguna
            style: TextStyle(
              color: context.gelap ? AppColors.darkBg : AppColors.white, // Warna teks kontras sesuai mode
            ),
          ),
          backgroundColor: context.warnaKeluar, // Warna latar merah/keluar sebagai tanda gagal
          behavior: SnackBarBehavior.floating, // Notifikasi mengambang
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Sudut membulat
        ),
      );
    }
  }

  void _toggleEdit() { // Beralih antara mode lihat dan mode edit, atau memicu simpan
    if (_isEditing) { // Jika sedang dalam mode edit
      _simpan(); // Tombol berfungsi sebagai "Simpan", proses penyimpanan data
    } else { // Jika sedang dalam mode lihat
      setState(() => _isEditing = true); // Masuk ke mode edit agar field bisa diubah
    }
  }

  @override
  Widget build(BuildContext context) { // Membangun tampilan halaman info profil
    final scheme = Theme.of(context).colorScheme; // Skema warna tema aktif
    return Scaffold( // Kerangka dasar halaman
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar mengikuti tema
      appBar: AppBar( // Bilah judul di atas halaman
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Warna latar app bar menyatu dengan halaman
        elevation: 0, // Tanpa bayangan di bawah app bar
        leading: IconButton( // Tombol kembali di kiri app bar
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), // Ikon panah kembali
          color: context.warnaTeksUtama, // Warna ikon sesuai tema
          onPressed: () => Navigator.pop(context), // Tutup halaman ini saat ditekan
          tooltip: 'Kembali', // Teks bantuan aksesibilitas
        ),
        title: Text( // Judul di tengah app bar
          'Informasi Profil', // Teks judul halaman
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.warnaTeksUtama, // Warna judul sesuai tema
          ),
        ),
        centerTitle: true, // Judul diposisikan di tengah
        actions: [ // Tombol-tombol di kanan app bar
          if (_isLoading) // Jika data masih dimuat
            Padding( // Jarak di sekitar indikator loading kecil
              padding: const EdgeInsets.only(right: 16), // Jarak dari tepi kanan
              child: SizedBox( // Batasi ukuran indikator loading
                width: 18, height: 18,
                child: CircularProgressIndicator( // Lingkaran putar kecil tanda memuat
                  strokeWidth: 2, color: scheme.primary),
              ),
            )
          else // Jika data sudah selesai dimuat
            TextButton( // Tombol teks untuk ubah/simpan
              onPressed: _isSaving ? null : _toggleEdit, // Nonaktifkan tombol saat sedang menyimpan
              child: _isSaving // Jika sedang menyimpan
                  ? SizedBox( // Tampilkan indikator loading kecil menggantikan teks
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: scheme.primary))
                  : Text( // Jika tidak sedang menyimpan, tampilkan label tombol
                      _isEditing ? 'Simpan' : 'Ubah', // Label berubah sesuai mode saat ini
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.primary, // Warna teks tombol
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading // Pilih tampilan body berdasarkan status pemuatan
          ? Center( // Jika masih memuat, tampilkan indikator di tengah layar
              child: CircularProgressIndicator(color: scheme.primary))
          : SingleChildScrollView( // Jika sudah selesai, tampilkan form yang bisa digulir
              padding: const EdgeInsets.symmetric(horizontal: 20), // Jarak kiri-kanan konten
              child: Column( // Susun semua bagian form secara vertikal
                crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                children: [
                  const SizedBox(height: 24), // Jarak kosong di paling atas

                  // ── Avatar ────────────────────────────────────────
                  Center( // Avatar diposisikan di tengah horizontal
                    child: Stack( // Tumpukan lapisan: lingkaran avatar + ikon kamera kecil
                      children: [
                        Container( // Lingkaran avatar utama
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: scheme.primary, // Warna latar lingkaran avatar
                            shape: BoxShape.circle, // Bentuk lingkaran
                          ),
                          child: Icon( // Ikon orang sebagai avatar default
                            Icons.person_outline,
                            size: 46,
                            color: scheme.onPrimary, // Warna ikon kontras dengan latar
                          ),
                        ),
                        if (_isEditing) // Hanya tampil saat mode edit aktif
                          Positioned( // Ikon kamera kecil diposisikan di sudut kanan bawah avatar
                            bottom: 0,
                            right: 0,
                            child: Container( // Lingkaran kecil pembungkus ikon kamera
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: scheme.primary, // Warna latar lingkaran kecil
                                shape: BoxShape.circle, // Bentuk lingkaran
                                border: Border.all( // Garis tepi agar terpisah jelas dari avatar
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    width: 2),
                              ),
                              child: Icon( // Ikon kamera sebagai tanda bisa ganti foto
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: scheme.onPrimary, // Warna ikon kontras
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32), // Jarak setelah avatar

                  // ── Data Pribadi ──────────────────────────────────
                  _buildSectionLabel('DATA PRIBADI'), // Label judul bagian data pribadi
                  const SizedBox(height: 8), // Jarak kecil sebelum daftar field
                  _buildFieldGroup([ // Kartu berisi kumpulan field data pribadi
                    _FieldItem(label: 'Nama Lengkap', controller: _namaCtrl, // Field nama lengkap
                        icon: Icons.person_outline),
                    _FieldItem(label: 'Email', controller: _emailCtrl, // Field email
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress), // Keyboard khusus format email
                    _FieldItem(label: 'Nomor HP', controller: _noHpCtrl, // Field nomor HP
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone), // Keyboard khusus angka telepon
                  ]),
                  const SizedBox(height: 20), // Jarak antar kelompok field

                  // ── Data Usaha ────────────────────────────────────
                  _buildSectionLabel('DATA USAHA'), // Label judul bagian data usaha
                  const SizedBox(height: 8), // Jarak kecil sebelum daftar field
                  _buildFieldGroup([ // Kartu berisi kumpulan field data usaha
                    _FieldItem(label: 'Nama Usaha', // Field nama usaha
                        controller: _namaUsahaCtrl,
                        icon: Icons.store_outlined),
                    _FieldItem(label: 'Jenis Usaha', // Field jenis usaha
                        controller: _jenisUsahaCtrl,
                        icon: Icons.category_outlined),
                    _FieldItem(label: 'Alamat', controller: _alamatCtrl, // Field alamat, boleh lebih dari satu baris
                        icon: Icons.location_on_outlined, maxLines: 3),
                  ]),
                  const SizedBox(height: 32), // Jarak kosong di bagian paling bawah
                ],
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label) { // Widget bantu untuk judul kecil tiap bagian form
    return Text(
      label, // Teks judul bagian, misal "DATA PRIBADI"
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: context.warnaTeksMuted, // Warna redup karena hanya label kecil
        letterSpacing: 0.8, // Jarak antar huruf sedikit lebar, gaya label kapital
      ),
    );
  }

  Widget _buildFieldGroup(List<_FieldItem> fields) { // Widget bantu untuk membangun kartu berisi beberapa field input
    return Container( // Kartu pembungkus seluruh field dalam grup ini
      decoration: BoxDecoration(
        color: context.warnaKartu, // Warna latar kartu sesuai tema
        borderRadius: BorderRadius.circular(14), // Sudut kartu melengkung
        border: Border.all(color: context.warnaGaris), // Garis tepi tipis sesuai tema
      ),
      child: Column( // Susun setiap field secara vertikal di dalam kartu
        children: List.generate(fields.length, (index) { // Buat satu baris untuk tiap field dalam daftar
          final field  = fields[index]; // Data field pada indeks ini
          final isLast = index == fields.length - 1; // Menandai apakah ini field terakhir (untuk garis pemisah)
          return Column( // Bungkus satu field beserta garis pemisahnya
            children: [
              Padding( // Jarak di sekeliling isi satu baris field
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Row( // Ikon di kiri, label+nilai di kanan
                  crossAxisAlignment: CrossAxisAlignment.start, // Rata atas, penting untuk field multi-baris (alamat)
                  children: [
                    Icon(field.icon, size: 18, color: context.warnaTeksMuted), // Ikon kecil mewakili jenis field
                    const SizedBox(width: 12), // Jarak antara ikon dan teks
                    Expanded( // Kolom label+nilai mengisi sisa ruang baris
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
                        children: [
                          Text( // Label kecil di atas nilai field
                            field.label, // Nama field, misal "Nama Lengkap"
                            style: TextStyle(
                              fontSize: 11,
                              color: context.warnaTeksMuted, // Warna redup untuk label
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2), // Jarak kecil antara label dan nilai/input
                          _isEditing // Pilih tampilan berdasarkan mode saat ini
                              ? TextField( // Mode edit: tampilkan kotak input yang bisa diketik
                                  controller: field.controller, // Controller pengelola teks field ini
                                  maxLines: field.maxLines, // Jumlah baris maksimum (1 untuk kebanyakan, 3 untuk alamat)
                                  keyboardType: field.keyboardType, // Jenis keyboard sesuai tipe data field
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.warnaTeksUtama, // Warna teks yang diketik
                                  ),
                                  decoration: InputDecoration( // Pengaturan tampilan kotak input
                                    isDense: true, // Kotak input lebih ringkas/rapat
                                    contentPadding: EdgeInsets.zero, // Tanpa jarak dalam tambahan
                                    border: UnderlineInputBorder( // Garis bawah saat tidak fokus
                                      borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary),
                                    ),
                                    focusedBorder: UnderlineInputBorder( // Garis bawah saat field sedang difokus/aktif diketik
                                      borderSide: BorderSide(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 1.5),
                                    ),
                                    enabledBorder: UnderlineInputBorder( // Garis bawah saat field aktif tapi tidak difokus
                                      borderSide: BorderSide(
                                          color: context.warnaGaris),
                                    ),
                                  ),
                                )
                              : Text( // Mode lihat: tampilkan teks nilai saja, tidak bisa diedit
                                  field.controller.text, // Nilai tersimpan saat ini pada controller
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: context.warnaTeksUtama, // Warna teks nilai
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) // Hanya tampilkan garis pemisah jika bukan field terakhir
                Divider( // Garis pemisah horizontal antar field
                    height: 1, indent: 46, color: context.warnaGaris), // Menjorok ke kanan agar sejajar dengan teks, bukan ikon
            ],
          );
        }),
      ),
    );
  }

}

class _FieldItem { // Kelas data sederhana untuk menampung konfigurasi satu field form
  final String label; // Nama/label field yang ditampilkan
  final TextEditingController controller; // Controller pengelola teks field ini
  final IconData icon; // Ikon yang mewakili field ini
  final int maxLines; // Jumlah baris maksimum input (default 1)
  final TextInputType keyboardType; // Jenis keyboard yang muncul (default teks biasa)

  const _FieldItem({ // Constructor const untuk membuat konfigurasi field
    required this.label, // Label wajib diisi
    required this.controller, // Controller wajib diisi
    required this.icon, // Ikon wajib diisi
    this.maxLines = 1, // Default satu baris jika tidak ditentukan
    this.keyboardType = TextInputType.text, // Default keyboard teks biasa jika tidak ditentukan
  });
}

