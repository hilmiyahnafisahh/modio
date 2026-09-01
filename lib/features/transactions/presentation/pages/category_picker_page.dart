import 'package:flutter/material.dart'; // Widget-widget dasar Flutter (Scaffold, Text, dll)

import '../../../../core/theme/app_colors.dart'; // Palet warna aplikasi
import '../../../../core/theme/app_typography.dart'; // Gaya teks terpusat
import '../../data/transaction_model.dart'; // Model TransactionType
import '../../data/transaksi_repository.dart'; // Sumber data kategori dari basis data

/// ─────────────────────────────────────────────────────────────────
/// CATEGORY PICKER PAGE  –  Pemilih kategori transaksi
///
/// Menggantikan DropdownButtonFormField + kolom teks "atau ketik
/// kategori baru" di form input transaksi. Dua alasan:
///
///   1. Pembaca layar membacakan dropdown dan kolom teks sebagai dua
///      elemen terpisah untuk satu isian yang sama, tanpa aturan
///      jelas mana yang berlaku bila keduanya terisi.
///   2. Menu dropdown bawaan Flutter muncul sebagai overlay terpisah
///      dari pohon widget utama, sehingga fokus TalkBack sering gagal
///      berpindah ke sana.
///
/// Halaman biasa ini membuat setiap kategori jadi elemen dalam alur
/// baca normal, dijangkau dengan gestur geser biasa seperti bagian
/// lain aplikasi.
/// ─────────────────────────────────────────────────────────────────

class CategoryPickerPage extends StatefulWidget { // Widget dengan state, halaman pemilih kategori
  final TransactionType type; // Jenis transaksi (masuk/keluar) untuk filter kategori
  final String? kategoriTerpilih; // Kategori yang sedang aktif dipilih, bila ada

  const CategoryPickerPage({
    super.key,
    required this.type, // Wajib diisi saat membuka halaman ini
    this.kategoriTerpilih, // Opsional, boleh null
  });

  @override
  State<CategoryPickerPage> createState() => _CategoryPickerPageState(); // Membuat objek state terkait
}

class _CategoryPickerPageState extends State<CategoryPickerPage> {
  final TransaksiRepository _repo = TransaksiRepository(); // Objek akses data transaksi/kategori
  late Future<List<String>> _daftar; // Future berisi daftar nama kategori, diisi belakangan

  @override
  void initState() {
    super.initState(); // Wajib dipanggil lebih dulu sesuai kontrak Flutter
    _muat(); // Muat daftar kategori saat halaman pertama dibuka
  }

  void _muat() {
    setState(() {
      _daftar = _repo.kategoriUntuk(widget.type); // Ambil kategori sesuai jenis transaksi
    });
  }

  Future<void> _tambahBaru() async {
    final String? nama = await showDialog<String>( // Tampilkan dialog input nama kategori baru
      context: context,
      builder: (_) => const _DialogKategoriBaru(),
    );
    if (nama == null || nama.trim().isEmpty || !mounted) return; // Batal bila kosong/dibatalkan/widget sudah lepas

    try {
      await _repo.tambahKategori(nama, widget.type); // Simpan kategori baru ke basis data
      if (!mounted) return; // Cek lagi setelah await, widget bisa sudah dilepas
      // Kategori baru langsung jadi hasil pilihan — pengguna tidak
      // perlu menambah lalu mencarinya lagi di daftar sebagai dua
      // langkah terpisah.
      Navigator.pop(context, nama.trim()); // Tutup halaman ini, kembalikan nama kategori baru
    } catch (e) {
      if (!mounted) return; // Jangan pakai context bila widget sudah tidak ada
      ScaffoldMessenger.of(context).showSnackBar( // Tampilkan pesan error singkat di bawah layar
        const SnackBar(
          content: Text('Kategori belum bisa disimpan. Coba lagi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold( // Kerangka halaman standar Flutter
      backgroundColor: AppColors.bgPage, // Warna latar halaman
      body: SafeArea( // Hindari area terhalang notch/status bar
        child: Column( // Susun elemen dari atas ke bawah
          crossAxisAlignment: CrossAxisAlignment.start, // Rata kiri
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 0), // Jarak dari tepi: kiri,atas,kanan,bawah
              child: Row( // Baris header: tombol kembali + judul
                children: [
                  IconButton(
                    // 56 dp: ukuran sentuh minimum yang berlaku di
                    // seluruh perbaikan ini.
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    onPressed: () => Navigator.pop(context), // Kembali ke halaman sebelumnya
                    tooltip: 'Kembali', // Teks bantuan aksesibilitas
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 30,
                      color: AppColors.baseDark,
                    ),
                  ),
                  const SizedBox(width: 4), // Jarak antar elemen
                  Text('Pilih Kategori', style: AppTypography.titleLarge), // Judul halaman
                ],
              ),
            ),
            Expanded( // Sisa ruang layar diisi daftar kategori
              child: FutureBuilder<List<String>>( // Bangun UI berdasarkan status Future
                future: _daftar,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) { // Masih memuat data
                    return const Center(child: CircularProgressIndicator()); // Tampilkan indikator loading
                  }

                  final List<String> daftar = snapshot.data ?? const <String>[]; // Data hasil, atau list kosong

                  return ListView.separated( // Daftar dengan garis pemisah antar item
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: daftar.length + 1, // +1 untuk baris "Tambah kategori baru"
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider), // Garis pemisah antar baris
                    itemBuilder: (context, index) {
                      // Baris pertama selalu "Tambah kategori baru",
                      // di posisi paling atas daftar.
                      if (index == 0) {
                        return _BarisKategori(
                          label: 'Tambah kategori baru',
                          icon: Icons.add_circle_outline,
                          isAksi: true, // Tandai sebagai baris aksi, bukan kategori biasa
                          onTap: _tambahBaru, // Buka dialog tambah kategori
                        );
                      }

                      final String nama = daftar[index - 1]; // Geser index karena baris 0 dipakai tombol aksi
                      final bool terpilih = nama == widget.kategoriTerpilih; // Cek apakah ini kategori aktif
                      return _BarisKategori(
                        label: nama,
                        icon: Icons.category_outlined,
                        terpilih: terpilih,
                        onTap: () => Navigator.pop(context, nama), // Kembalikan nama kategori terpilih
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarisKategori extends StatelessWidget { // Satu baris kategori dalam daftar, tanpa state internal
  final String label; // Nama kategori atau teks aksi
  final IconData icon; // Ikon di sisi kiri baris
  final bool terpilih; // Apakah kategori ini sedang dipilih
  final bool isAksi; // Apakah baris ini tombol aksi (tambah baru)
  final VoidCallback onTap; // Aksi saat baris diketuk

  const _BarisKategori({
    required this.label,
    required this.icon,
    this.terpilih = false, // Default: tidak terpilih
    this.isAksi = false, // Default: bukan baris aksi
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Status terpilih disampaikan lewat centang DAN bobot huruf tebal
    // sekaligus, bukan cuma warna — supaya tetap terbaca bagi
    // pengguna buta warna.
    return Semantics( // Bungkus dengan info aksesibilitas untuk pembaca layar
      button: true, // Beri tahu pembaca layar ini berperan sebagai tombol
      selected: terpilih, // Umumkan status terpilih
      label: isAksi ? label : 'Kategori $label${terpilih ? ', dipilih' : ''}', // Label yang dibacakan
      onTap: onTap, // Aksi saat diaktifkan lewat pembaca layar
      excludeSemantics: true, // Cegah child di bawah menambah info semantik ganda
      child: InkWell( // Efek riak saat disentuh + area ketuk
        onTap: onTap,
        child: ConstrainedBox(
          // 56 dp: ukuran sentuh minimum yang berlaku di seluruh
          // perbaikan ini, bukan tinggi tetap.
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isAksi ? AppColors.primary700 : AppColors.textMuted, // Warna beda untuk baris aksi
                ),
                const SizedBox(width: 14),
                Expanded( // Teks label mengisi sisa ruang baris
                  child: Text(
                    label,
                    style: AppTypography.bodyLarge.copyWith(
                      color: isAksi ? AppColors.primary700 : AppColors.baseDark,
                      fontWeight: isAksi || terpilih
                          ? FontWeight.w600 // Tebal untuk aksi atau kategori terpilih
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (terpilih) // Tampilkan centang hanya bila kategori ini aktif
                  const Icon(
                    Icons.check,
                    size: 20,
                    color: AppColors.primary700,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogKategoriBaru extends StatefulWidget { // Dialog input nama kategori baru
  const _DialogKategoriBaru();

  @override
  State<_DialogKategoriBaru> createState() => _DialogKategoriBaruState();
}

class _DialogKategoriBaruState extends State<_DialogKategoriBaru> {
  final TextEditingController _ctrl = TextEditingController(); // Kendali teks kolom input

  @override
  void dispose() {
    _ctrl.dispose(); // Bebaskan resource controller saat dialog ditutup
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog( // Kotak dialog standar Flutter
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Sudut membulat
      title: const Text(
        'Kategori Baru',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ),
      ),
      content: TextField( // Kolom input nama kategori
        controller: _ctrl,
        autofocus: true, // Langsung fokus & buka keyboard saat dialog muncul
        textCapitalization: TextCapitalization.sentences, // Huruf awal kalimat otomatis kapital
        style: const TextStyle(fontSize: 16, color: AppColors.baseDark),
        decoration: const InputDecoration(hintText: 'Nama kategori'), // Placeholder teks
        onSubmitted: (v) => Navigator.pop(context, v), // Tekan enter = langsung simpan
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(88, 48)), // Ukuran minimum tombol
          onPressed: () => Navigator.pop(context), // Batal, tidak kembalikan nilai
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: () => Navigator.pop(context, _ctrl.text), // Simpan, kembalikan teks yang diketik
          child: const Text(
            'Simpan',
            style: TextStyle(
              color: AppColors.primary700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
