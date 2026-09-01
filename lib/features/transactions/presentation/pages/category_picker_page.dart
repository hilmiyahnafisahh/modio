import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/transaction_model.dart';
import '../../data/transaksi_repository.dart';

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

class CategoryPickerPage extends StatefulWidget {
  final TransactionType type;
  final String? kategoriTerpilih;

  const CategoryPickerPage({
    super.key,
    required this.type,
    this.kategoriTerpilih,
  });

  @override
  State<CategoryPickerPage> createState() => _CategoryPickerPageState();
}

class _CategoryPickerPageState extends State<CategoryPickerPage> {
  final TransaksiRepository _repo = TransaksiRepository();
  late Future<List<String>> _daftar;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  void _muat() {
    setState(() {
      _daftar = _repo.kategoriUntuk(widget.type);
    });
  }

  Future<void> _tambahBaru() async {
    final String? nama = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogKategoriBaru(),
    );
    if (nama == null || nama.trim().isEmpty || !mounted) return;

    try {
      await _repo.tambahKategori(nama, widget.type);
      if (!mounted) return;
      // Kategori baru langsung jadi hasil pilihan — pengguna tidak
      // perlu menambah lalu mencarinya lagi di daftar sebagai dua
      // langkah terpisah.
      Navigator.pop(context, nama.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kategori belum bisa disimpan. Coba lagi.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    // 56 dp: ukuran sentuh minimum yang berlaku di
                    // seluruh perbaikan ini.
                    constraints: const BoxConstraints(
                      minWidth: 56,
                      minHeight: 56,
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Kembali',
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 30,
                      color: AppColors.baseDark,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Pilih Kategori', style: AppTypography.titleLarge),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _daftar,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<String> daftar = snapshot.data ?? const <String>[];

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    itemCount: daftar.length + 1,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      // Baris pertama selalu "Tambah kategori baru",
                      // di posisi paling atas daftar.
                      if (index == 0) {
                        return _BarisKategori(
                          label: 'Tambah kategori baru',
                          icon: Icons.add_circle_outline,
                          isAksi: true,
                          onTap: _tambahBaru,
                        );
                      }

                      final String nama = daftar[index - 1];
                      final bool terpilih = nama == widget.kategoriTerpilih;
                      return _BarisKategori(
                        label: nama,
                        icon: Icons.category_outlined,
                        terpilih: terpilih,
                        onTap: () => Navigator.pop(context, nama),
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

class _BarisKategori extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool terpilih;
  final bool isAksi;
  final VoidCallback onTap;

  const _BarisKategori({
    required this.label,
    required this.icon,
    this.terpilih = false,
    this.isAksi = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Status terpilih disampaikan lewat centang DAN bobot huruf tebal
    // sekaligus, bukan cuma warna — supaya tetap terbaca bagi
    // pengguna buta warna.
    return Semantics(
      button: true,
      selected: terpilih,
      label: isAksi ? label : 'Kategori $label${terpilih ? ', dipilih' : ''}',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
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
                  color: isAksi ? AppColors.primary700 : AppColors.textMuted,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.bodyLarge.copyWith(
                      color: isAksi ? AppColors.primary700 : AppColors.baseDark,
                      fontWeight: isAksi || terpilih
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (terpilih)
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

class _DialogKategoriBaru extends StatefulWidget {
  const _DialogKategoriBaru();

  @override
  State<_DialogKategoriBaru> createState() => _DialogKategoriBaruState();
}

class _DialogKategoriBaruState extends State<_DialogKategoriBaru> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Kategori Baru',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.baseDark,
        ),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 16, color: AppColors.baseDark),
        decoration: const InputDecoration(hintText: 'Nama kategori'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(88, 48)),
          onPressed: () => Navigator.pop(context, _ctrl.text),
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
