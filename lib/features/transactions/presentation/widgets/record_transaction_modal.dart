import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../../../core/navigation/app_route.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/transaction_model.dart';
import '../../data/transaksi_repository.dart';
import '../pages/category_picker_page.dart';
import 'voice_transaction_flow.dart';

class RecordTransactionModal extends StatefulWidget {
  /// Transaksi yang sedang diedit. Null berarti form ini untuk
  /// mencatat transaksi baru.
  final TransactionItem? existingItem;

  /// Isian awal dari hasil pengenalan suara (lihat voice_transaction_flow.dart).
  /// Diabaikan bila [existingItem] terisi. Pengguna tetap meninjau dan bisa
  /// mengubah semuanya sebelum menyimpan — ini cuma titik awal, bukan hasil final.
  final bool? prefillIsIncome;
  final int? prefillNominal;
  final String? prefillKategori;
  final String? prefillCatatan;

  const RecordTransactionModal({
    super.key,
    this.existingItem,
    this.prefillIsIncome,
    this.prefillNominal,
    this.prefillKategori,
    this.prefillCatatan,
  });

  @override
  State<RecordTransactionModal> createState() => _RecordTransactionModalState();
}

class _RecordTransactionModalState extends State<RecordTransactionModal> {
  final _repo = TransaksiRepository();

  // Controller diperlukan agar nilai yang diketik bisa dibaca.
  // Tanpa ini, TextField hanya tampilan — isinya tidak bisa diambil.
  final _nominalCtrl = TextEditingController();
  final _keteranganCtrl = TextEditingController();

  bool _isIncome = true;
  String _metode = 'tunai';
  String? _kategori;
  DateTime _tanggal = DateTime.now();
  List<String> _daftarKategori = [];
  bool _menyimpan = false;

  bool get _modeEdit => widget.existingItem != null;

  TransactionType get _type =>
      _isIncome ? TransactionType.masuk : TransactionType.keluar;

  /// Nominal mentah, titik dan spasi dibuang.
  int? get _nominal {
    final bersih = _nominalCtrl.text.replaceAll(RegExp(r'\D'), '');
    return bersih.isEmpty ? null : int.tryParse(bersih);
  }

  @override
  void initState() {
    super.initState();

    final TransactionItem? existing = widget.existingItem;
    if (existing != null) {
      _isIncome = existing.type == TransactionType.masuk;
      _nominalCtrl.text = existing.nominal.toString();
      // catatan dan title diisi dari sumber yang sama saat menyimpan
      // (lihat _simpan): kalau keterangan kosong, title diambil dari
      // nama kategori dan catatan disimpan null. Jadi merekonstruksi
      // isian keterangan yang asli cukup dari catatan saja.
      _keteranganCtrl.text = existing.catatan ?? '';
      _metode = existing.method;
      _kategori = existing.kategori;
      _tanggal = existing.occurredAt.toLocal();
    } else {
      if (widget.prefillIsIncome != null) _isIncome = widget.prefillIsIncome!;
      if (widget.prefillNominal != null) {
        _nominalCtrl.text = widget.prefillNominal.toString();
      }
      if (widget.prefillCatatan != null && widget.prefillCatatan!.isNotEmpty) {
        _keteranganCtrl.text = widget.prefillCatatan!;
      }
      _kategori = widget.prefillKategori;
    }

    _muatKategoriAwal();
  }

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  /// Memuat daftar kategori untuk jenis transaksi saat ini TANPA
  /// mereset kategori yang sudah dipilih — dipakai sekali di awal
  /// (initState), supaya data mode edit tidak tertimpa. Kategori dari
  /// transaksi lama yang sudah tak ada di daftar baku tetap dipakai
  /// apa adanya — halaman pemilih kategori menampilkannya persis
  /// seperti tersimpan, tidak diam-diam diganti.
  Future<void> _muatKategoriAwal() async {
    final daftar = await _repo.kategoriUntuk(_type);
    if (!mounted) return;
    setState(() {
      _daftarKategori = daftar;
      _kategori ??= daftar.isNotEmpty ? daftar.first : null;
    });
  }

  /// Memuat ulang daftar kategori DAN mereset ke kategori pertama —
  /// dipakai saat pengguna mengganti jenis Pemasukan/Pengeluaran,
  /// sebab kategori lama sudah pasti tidak berlaku untuk jenis baru.
  Future<void> _muatKategori() async {
    final daftar = await _repo.kategoriUntuk(_type);
    if (!mounted) return;
    setState(() {
      _daftarKategori = daftar;
      _kategori = daftar.isNotEmpty ? daftar.first : null;
    });
  }

  /// Membuka halaman pemilih kategori dan menerapkan hasilnya.
  Future<void> _pilihKategori() async {
    final String? hasil = await Navigator.push<String>(
      context,
      buatRute((_) => CategoryPickerPage(
            type: _type,
            kategoriTerpilih: _kategori,
          )),
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _kategori = hasil;
      if (!_daftarKategori.contains(hasil)) {
        _daftarKategori = [..._daftarKategori, hasil];
      }
    });
    // Perubahan status diumumkan — pengguna tunanetra tidak melihat
    // baris pemilih berganti nilai setelah kembali dari halaman lain.
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Kategori dipilih: $hasil',
      Directionality.of(context),
    );
  }

  Future<void> _pilihTanggal() async {
    final hasil = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal transaksi',
    );
    if (hasil != null && mounted) {
      setState(() => _tanggal = hasil);
    }
  }

  /// Membacakan ulang seluruh isian sebelum data disimpan.
  ///
  /// Ini inti MODIO, bukan pelengkap. Pengguna tunanetra tidak bisa
  /// memindai form sekilas untuk memastikan angkanya benar. Satu kalimat
  /// utuh yang mengulang seluruh isian adalah satu-satunya cara ia bisa
  /// memverifikasi sendiri, tanpa bertanya ke orang lain.
  Future<bool> _konfirmasi() async {
    final n = _nominal!;
    final arah = _isIncome ? 'Uang masuk' : 'Uang keluar';
    final kalimat = '$arah ${CurrencyFormatter.spoken(n)}, '
        '$_kategori, $_metode, ${DateFormatter.full(_tanggal)}';

    final hasil = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sudah benar?',
          style: AppTypography.titleMedium.copyWith(
            color: context.warnaTeksUtama,
          ),
        ),
        content: Text(
          kalimat,
          style: AppTypography.bodyMedium.copyWith(
            color: context.warnaTeksUtama,
            height: 1.5,
          ),
        ),
        actionsOverflowButtonSpacing: 12,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              minimumSize: const Size(120, 56),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Perbaiki'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              minimumSize: const Size(120, 56),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Ya, simpan'),
          ),
        ],
      ),
    );
    return hasil ?? false;
  }

  Future<void> _simpan() async {
    // Validasi sebelum konfirmasi, agar pengguna tidak mendengar
    // kalimat konfirmasi yang isinya salah.
    final n = _nominal;
    if (n == null || n <= 0) {
      _pesan('Nominal belum diisi. Masukkan angka lebih dari nol.');
      return;
    }
    if (n > 100000000) {
      _pesan('Nominal terlalu besar. Periksa kembali jumlah nolnya.');
      return;
    }
    if (_kategori == null) {
      _pesan('Kategori belum dipilih.');
      return;
    }

    if (!await _konfirmasi()) return;

    setState(() => _menyimpan = true);
    // Judul transaksi SELALU nama kategori — sebelumnya keterangan
    // yang diisi malah menggantikan judul (mengetik "Pak Ahmad" di
    // Keterangan membuat itu jadi judul, dan kategori terdesak jadi
    // info sekunder). "Keterangan" adalah catatan tambahan, bukan
    // judul pengganti.
    final String title = _kategori!;
    final String? catatanBaru =
        _keteranganCtrl.text.trim().isEmpty ? null : _keteranganCtrl.text.trim();

    try {
      String narasiHasil;
      if (_modeEdit) {
        await _repo.perbarui(
          id: widget.existingItem!.id,
          title: title,
          nominal: n,
          type: _type,
          method: _metode,
          kategori: _kategori!,
          // Dikirim apa adanya (boleh string kosong), bukan diubah
          // jadi null saat kosong. perbarui() hanya menimpa field yang
          // nilainya bukan null — kalau di sini dipaksa null saat
          // keterangan dikosongkan, catatan lama tidak akan pernah
          // benar-benar terhapus lewat form edit ini.
          catatan: _keteranganCtrl.text.trim(),
          waktu: _tanggal,
        );
        narasiHasil = 'Perubahan tersimpan. $title.';
      } else {
        final transaksi = await _repo.simpan(
          title: title,
          nominal: n,
          type: _type,
          method: _metode,
          kategori: _kategori!,
          catatan: catatanBaru,
          waktu: _tanggal,
        );
        narasiHasil = 'Tersimpan. ${transaksi.narasi}';
      }

      if (!mounted) return;

      // Diumumkan lewat sistem aksesibilitas, bukan hanya snackbar.
      // Snackbar hilang dalam empat detik dan sering terlewat TalkBack.
      SemanticsService.sendAnnouncement(
        View.of(context),
        narasiHasil,
        Directionality.of(context),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _menyimpan = false);
      _pesan('Transaksi belum tersimpan. Periksa isian lalu coba lagi.');
    }
  }

  /// Dengarkan ucapan lewat AI dan isikan hasilnya ke form yang sedang
  /// terbuka ini — beda dari [mulaiCatatTransaksiSuara] yang dipakai
  /// tombol mic di halaman lain, yang membuka form BARU. Di sini
  /// pengguna sudah berada di dalam form, jadi hasilnya menimpa isian
  /// yang sudah ada alih-alih membuka form kedua di atasnya.
  Future<void> _pakaiSuara() async {
    final String? teks = await dengarkanUcapan(context);
    if (teks == null || teks.trim().isEmpty || !mounted) return;

    final hasil = await uraikanUcapanTransaksi(context, teks);
    if (hasil == null || !mounted) return;

    setState(() {
      if (hasil.jenis == 'masuk') _isIncome = true;
      if (hasil.jenis == 'keluar') _isIncome = false;
      if (hasil.nominal != null) {
        _nominalCtrl.text = hasil.nominal.toString();
      }
      if (hasil.catatan.isNotEmpty) {
        _keteranganCtrl.text = hasil.catatan;
      }
      if (hasil.kategori != null) _kategori = hasil.kategori;
    });
    // Memuat ulang daftar kategori untuk jenis (masuk/keluar) yang
    // mungkin baru saja berubah — _kategori sudah diisi di atas jadi
    // tidak akan tertimpa balik ke kategori pertama.
    await _muatKategoriAwal();

    if (!mounted) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Isian terisi dari suara. Periksa sebelum menyimpan.',
      Directionality.of(context),
    );
  }

  void _pesan(String teks) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks, style: const TextStyle(fontSize: 16)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: context.warnaKartu,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.warnaGaris,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  IconButton(
                    // Ukuran sentuh minimum. constraints kosong pada versi
                    // sebelumnya membuat area tekan hanya sebesar ikonnya.
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Tutup',
                    icon: Icon(
                      Icons.chevron_left,
                      size: 30,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _modeEdit ? 'Edit Transaksi' : 'Input Transaksi',
                    style: AppTypography.titleLarge.copyWith(
                      color: context.warnaTeksUtama,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _TypeCard(
                      label: 'Pemasukan',
                      // north_east/south_west, sama dengan ikon arah di
                      // seluruh app (baris transaksi, ringkasan
                      // dashboard) — satu bentuk penanda arah, bukan
                      // dua yang berbeda untuk hal yang sama.
                      icon: Icons.north_east,
                      isSelected: _isIncome,
                      bgColor: context.latarMasuk,
                      iconColor: context.warnaMasuk,
                      onTap: () {
                        setState(() => _isIncome = true);
                        _muatKategori();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TypeCard(
                      label: 'Pengeluaran',
                      icon: Icons.south_west,
                      isSelected: !_isIncome,
                      bgColor: context.latarKeluar,
                      iconColor: context.warnaKeluar,
                      onTap: () {
                        setState(() => _isIncome = false);
                        _muatKategori();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _buildLabel('Tanggal'),
              const SizedBox(height: 8),
              Semantics(
                button: true,
                label: 'Tanggal transaksi, ${DateFormatter.full(_tanggal)}. '
                    'Ketuk untuk mengubah',
                onTap: _pilihTanggal,
                excludeSemantics: true,
                child: InkWell(
                  onTap: _pilihTanggal,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.warnaGaris),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          color: context.warnaTeksMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormatter.full(_tanggal),
                          style: TextStyle(
                            fontSize: 16,
                            color: context.warnaTeksUtama,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _buildLabel('Jumlah'),
              const SizedBox(height: 8),
              TextField(
                controller: _nominalCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: context.warnaTeksUtama,
                ),
                decoration: _dekorasi(
                  hintText: '0',
                  prefixText: 'Rp ',
                ),
              ),

              // Umpan balik langsung: angka yang diketik dibacakan kembali
              // dalam kata, sehingga kelebihan nol ketahuan saat itu juga.
              if (_nominal != null && _nominal! > 0) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    CurrencyFormatter.spoken(_nominal!),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _buildLabel('Kategori'),
              const SizedBox(height: 8),
              // Satu baris yang membuka halaman pemilih, menggantikan
              // dropdown + kolom teks kategori kustom. Dropdown bawaan
              // Flutter membuka menu sebagai overlay terpisah dari
              // pohon widget utama — fokus TalkBack sering gagal
              // berpindah ke sana. Halaman biasa membuat setiap
              // kategori jadi elemen dalam alur baca normal.
              _BarisPilihan(
                nilai: _kategori ?? 'Belum dipilih',
                labelSemantik: 'Kategori, ${_kategori ?? "belum dipilih"}. '
                    'Ketuk untuk mengubah',
                ikon: Icons.category_outlined,
                onTap: _pilihKategori,
              ),

              const SizedBox(height: 16),
              _buildLabel('Keterangan'),
              const SizedBox(height: 8),
              TextField(
                controller: _keteranganCtrl,
                style: TextStyle(
                  fontSize: 17,
                  color: context.warnaTeksUtama,
                ),
                decoration: _dekorasi(
                  hintText: 'Boleh dikosongkan',
                  besar: true,
                ),
              ),

              const SizedBox(height: 16),
              _buildLabel('Metode bayar'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      label: 'Tunai',
                      icon: Icons.account_balance_wallet_outlined,
                      isSelected: _metode == 'tunai',
                      onTap: () => setState(() => _metode = 'tunai'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      label: 'Non Tunai',
                      icon: Icons.credit_card_outlined,
                      isSelected: _metode == 'non tunai',
                      onTap: () => setState(() => _metode = 'non tunai'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              Semantics(
                button: true,
                label: 'Catat transaksi dengan suara',
                onTap: _pakaiSuara,
                excludeSemantics: true,
                child: InkWell(
                  onTap: _pakaiSuara,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.latarMasuk,
                      borderRadius: BorderRadius.circular(14),
                      // Tanpa garis tepi, kartu berlatar gelap ini nyaris
                      // tak terlihat sebagai kartu di atas halaman yang
                      // juga gelap — beda dari mode terang, di sana
                      // warna mint mudanya sudah cukup menonjol sendiri.
                      border: Border.all(color: context.warnaMasuk, width: 1.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: context.warnaKartu,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: context.warnaMasuk, width: 1.5),
                          ),
                          child: Icon(
                            Icons.mic_none,
                            color: context.warnaMasuk,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Catat transaksi dengan Suara\n'
                            'Ucapkan transaksi Anda, AI akan membantu '
                            'mengisi data secara otomatis.',
                            style: TextStyle(
                              fontSize: 15,
                              color: context.warnaTeksUtama,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _menyimpan ? null : _simpan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    // Tinggi minimum, bukan tinggi tetap. Saat pengguna
                    // memperbesar teks sistem hingga 200 persen, tombol
                    // ikut tumbuh dan labelnya tidak terpotong.
                    minimumSize: const Size.fromHeight(56),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _menyimpan
                        ? 'Menyimpan...'
                        : (_modeEdit ? 'Simpan Perubahan' : 'Simpan Transaksi'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        // Dinaikkan dari 13. Ukuran di bawah 14 sulit dibaca pengguna
        // low vision, dan label form adalah petunjuk utama isian.
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: context.warnaTeksUtama,
      ),
    );
  }

  InputDecoration _dekorasi({
    required String hintText,
    String? prefixText,
    // Kategori dan Keterangan memakai besar: true — padding vertikal
    // lebih lega, sehingga tinggi isian bertambah dan lebih mudah
    // disentuh tepat oleh jari tanpa melihat batas kotaknya.
    bool besar = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: context.warnaTeksMuted,
        fontSize: besar ? 17 : 16,
      ),
      prefixText: prefixText,
      prefixStyle: TextStyle(
        color: context.warnaTeksUtama,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: context.warnaKartu,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: besar ? 20 : 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.warnaGaris),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.warnaGaris),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        // Dinaikkan dari 1.5. Indikator fokus yang tipis sulit terlihat
        // pengguna low vision saat berpindah antar isian.
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 3,
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? bgColor : context.warnaKartu,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? iconColor : context.warnaGaris,
              // Pembeda tambahan selain warna: ketebalan garis.
              width: isSelected ? 3 : 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? context.warnaTeksUtama
                        : context.warnaTeksMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Metode bayar $label',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.latarMasuk : context.warnaKartu,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : context.warnaGaris,
              width: isSelected ? 2.5 : 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : context.warnaTeksMuted,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : context.warnaTeksMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris yang membuka halaman pemilih (mis. kategori) — pengganti pola
/// dropdown/kolom teks yang bermasalah dengan pembaca layar.
class _BarisPilihan extends StatelessWidget {
  final String nilai;
  final String labelSemantik;
  final IconData ikon;
  final VoidCallback onTap;

  const _BarisPilihan({
    required this.nilai,
    required this.labelSemantik,
    required this.ikon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: labelSemantik,
      // onTap wajib di simpul semantik ini sendiri — excludeSemantics
      // di bawah membuang aksi milik InkWell, jadi tanpa baris ini
      // TalkBack mengumumkan "tombol" tapi ketuk dua kali tidak
      // melakukan apa pun.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 56 dp: ukuran sentuh minimum, bukan tinggi tetap — tetap
          // muat saat ukuran teks sistem dimaksimalkan.
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.warnaGaris),
          ),
          child: Row(
            children: [
              Icon(ikon, color: context.warnaTeksMuted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  nilai,
                  style: TextStyle(
                    fontSize: 16,
                    color: context.warnaTeksUtama,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: context.warnaTeksMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}