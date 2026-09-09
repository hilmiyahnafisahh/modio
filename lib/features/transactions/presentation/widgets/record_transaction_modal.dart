import 'package:flutter/material.dart'; // widget dan tema dasar Flutter
import 'package:flutter/semantics.dart'; // untuk pengumuman ke pembaca layar
import 'package:flutter/services.dart'; // untuk pembatas input (FilteringTextInputFormatter)

import '../../../../core/navigation/app_route.dart'; // helper pembuat rute navigasi
import '../../../../core/theme/app_typography.dart'; // gaya teks standar aplikasi
import '../../../../core/theme/theme_extensions.dart'; // ekstensi warna kontekstual (mis. context.warnaKartu)
import '../../../../core/utils/currency_formatter.dart'; // pengubah angka jadi teks rupiah/lisan
import '../../data/transaction_model.dart'; // model data transaksi dan jenisnya
import '../../data/transaksi_repository.dart'; // sumber data transaksi (simpan/baca/perbarui)
import '../pages/category_picker_page.dart'; // halaman pemilih kategori
import 'voice_transaction_flow.dart'; // fungsi pengenalan ucapan untuk transaksi

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
  final String? prefillMetode;
  final String? prefillCatatan;

  const RecordTransactionModal({
    super.key,
    this.existingItem,
    this.prefillIsIncome,
    this.prefillNominal,
    this.prefillKategori,
    this.prefillMetode,
    this.prefillCatatan,
  });

  @override
  State<RecordTransactionModal> createState() => _RecordTransactionModalState();
}

class _RecordTransactionModalState extends State<RecordTransactionModal> {
  final _repo = TransaksiRepository(); // akses data transaksi (simpan, perbarui, baca kategori)

  // Controller diperlukan agar nilai yang diketik bisa dibaca.
  // Tanpa ini, TextField hanya tampilan — isinya tidak bisa diambil.
  final _nominalCtrl = TextEditingController(); // pengendali isi kolom nominal
  final _keteranganCtrl = TextEditingController(); // pengendali isi kolom keterangan

  bool _isIncome = true; // true jika transaksi berupa pemasukan
  String _metode = 'tunai'; // metode pembayaran yang dipilih
  String? _kategori; // kategori transaksi yang dipilih
  DateTime _tanggal = DateTime.now(); // tanggal transaksi, default hari ini
  List<String> _daftarKategori = []; // daftar kategori tersedia untuk jenis transaksi saat ini
  bool _menyimpan = false; // true selama proses penyimpanan berlangsung

  bool get _modeEdit => widget.existingItem != null; // true jika form ini untuk mengedit transaksi lama

  TransactionType get _type =>
      _isIncome ? TransactionType.masuk : TransactionType.keluar; // jenis transaksi sesuai sakelar pemasukan/pengeluaran

  /// Nominal mentah, titik dan spasi dibuang.
  int? get _nominal {
    final bersih = _nominalCtrl.text.replaceAll(RegExp(r'\D'), ''); // buang semua karakter selain digit
    return bersih.isEmpty ? null : int.tryParse(bersih); // null bila kosong, angka bila ada isi
  }

  /// Hanya dua nilai yang dikenal form ini — cegah AI "mengarang" nilai
  /// metode bayar lain yang tidak dikenal salah satu opsi di layar.
  static bool _metodeValid(String? v) => v == 'tunai' || v == 'non tunai';

  @override
  void initState() {
    super.initState();

    final TransactionItem? existing = widget.existingItem; // transaksi lama bila sedang mode edit
    if (existing != null) {
      _isIncome = existing.type == TransactionType.masuk; // isi jenis dari data lama
      _nominalCtrl.text = existing.nominal.toString(); // isi nominal dari data lama
      // catatan dan title diisi dari sumber yang sama saat menyimpan
      // (lihat _simpan): kalau keterangan kosong, title diambil dari
      // nama kategori dan catatan disimpan null. Jadi merekonstruksi
      // isian keterangan yang asli cukup dari catatan saja.
      _keteranganCtrl.text = existing.catatan ?? ''; // isi keterangan dari catatan lama
      _metode = existing.method; // isi metode bayar dari data lama
      _kategori = existing.kategori; // isi kategori dari data lama
      _tanggal = existing.occurredAt.toLocal(); // isi tanggal dari data lama, dikonversi ke waktu lokal
    } else {
      if (widget.prefillIsIncome != null) _isIncome = widget.prefillIsIncome!; // pakai hasil suara bila ada
      if (widget.prefillNominal != null) {
        _nominalCtrl.text = widget.prefillNominal.toString(); // isi nominal dari hasil suara
      }
      if (widget.prefillCatatan != null && widget.prefillCatatan!.isNotEmpty) {
        _keteranganCtrl.text = widget.prefillCatatan!; // isi keterangan dari hasil suara
      }
      _kategori = widget.prefillKategori; // isi kategori dari hasil suara bila ada
      if (_metodeValid(widget.prefillMetode)) {
        _metode = widget.prefillMetode!; // isi metode bayar dari hasil suara bila disebutkan
      }
    }

    _muatKategoriAwal(); // muat daftar kategori sesuai jenis transaksi saat ini
  }

  @override
  void dispose() {
    _nominalCtrl.dispose(); // lepas controller nominal agar tidak bocor memori
    _keteranganCtrl.dispose(); // lepas controller keterangan agar tidak bocor memori
    super.dispose();
  }

  /// Memuat daftar kategori untuk jenis transaksi saat ini TANPA
  /// mereset kategori yang sudah dipilih — dipakai sekali di awal
  /// (initState), supaya data mode edit tidak tertimpa. Kategori dari
  /// transaksi lama yang sudah tak ada di daftar baku tetap dipakai
  /// apa adanya — halaman pemilih kategori menampilkannya persis
  /// seperti tersimpan, tidak diam-diam diganti.
  Future<void> _muatKategoriAwal() async {
    final daftar = await _repo.kategoriUntuk(_type); // ambil daftar kategori dari repository
    if (!mounted) return; // batalkan bila widget sudah dilepas
    setState(() {
      _daftarKategori = daftar; // perbarui daftar kategori yang tampil
      _kategori ??= daftar.isNotEmpty ? daftar.first : null; // isi kategori hanya jika belum ada nilai
    });
  }

  /// Memuat ulang daftar kategori DAN mereset ke kategori pertama —
  /// dipakai saat pengguna mengganti jenis Pemasukan/Pengeluaran,
  /// sebab kategori lama sudah pasti tidak berlaku untuk jenis baru.
  Future<void> _muatKategori() async {
    final daftar = await _repo.kategoriUntuk(_type); // ambil daftar kategori sesuai jenis baru
    if (!mounted) return; // batalkan bila widget sudah dilepas
    setState(() {
      _daftarKategori = daftar; // perbarui daftar kategori
      _kategori = daftar.isNotEmpty ? daftar.first : null; // selalu reset ke kategori pertama
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
    ); // tunggu kategori yang dipilih pengguna dari halaman lain
    if (hasil == null || !mounted) return; // batalkan bila dibatalkan atau widget sudah dilepas
    setState(() {
      _kategori = hasil; // terapkan kategori baru yang dipilih
      if (!_daftarKategori.contains(hasil)) {
        _daftarKategori = [..._daftarKategori, hasil]; // tambahkan kategori baru ke daftar bila belum ada
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
      initialDate: _tanggal, // tanggal awal yang ditampilkan di kalender
      firstDate: DateTime(2020), // batas tanggal paling lama yang bisa dipilih
      lastDate: DateTime.now(), // batas tanggal paling baru yang bisa dipilih
      helpText: 'Pilih tanggal transaksi',
    );
    if (hasil != null && mounted) {
      setState(() => _tanggal = hasil); // terapkan tanggal yang dipilih
    }
  }

  /// Membacakan ulang seluruh isian sebelum data disimpan.
  ///
  /// Ini inti MODIO, bukan pelengkap. Pengguna tunanetra tidak bisa
  /// memindai form sekilas untuk memastikan angkanya benar. Satu kalimat
  /// utuh yang mengulang seluruh isian adalah satu-satunya cara ia bisa
  /// memverifikasi sendiri, tanpa bertanya ke orang lain.
  Future<bool> _konfirmasi() async {
    final n = _nominal!; // nominal sudah dipastikan tidak null oleh pemanggil
    final arah = _isIncome ? 'Uang masuk' : 'Uang keluar'; // kalimat arah transaksi
    final kalimat = '$arah ${CurrencyFormatter.spoken(n)}, '
        '$_kategori, $_metode, ${DateFormatter.full(_tanggal)}'; // rangkai kalimat konfirmasi lengkap

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
            onPressed: () => Navigator.pop(context, false), // tutup dialog, kembalikan hasil false (batal)
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
            onPressed: () => Navigator.pop(context, true), // tutup dialog, kembalikan hasil true (setuju)
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
    return hasil ?? false; // anggap batal bila dialog ditutup tanpa memilih
  }

  Future<void> _simpan() async {
    // Validasi sebelum konfirmasi, agar pengguna tidak mendengar
    // kalimat konfirmasi yang isinya salah.
    final n = _nominal;
    if (n == null || n <= 0) {
      _pesan('Nominal belum diisi. Masukkan angka lebih dari nol.'); // tolak nominal kosong/tidak valid
      return;
    }
    if (n > 100000000) {
      _pesan('Nominal terlalu besar. Periksa kembali jumlah nolnya.'); // tolak nominal yang tidak masuk akal
      return;
    }
    if (_kategori == null) {
      _pesan('Kategori belum dipilih.'); // tolak bila kategori belum dipilih
      return;
    }

    if (!await _konfirmasi()) return; // hentikan bila pengguna memilih "Perbaiki"

    setState(() => _menyimpan = true); // tampilkan status sedang menyimpan
    // Judul transaksi SELALU nama kategori — sebelumnya keterangan
    // yang diisi malah menggantikan judul (mengetik "Pak Ahmad" di
    // Keterangan membuat itu jadi judul, dan kategori terdesak jadi
    // info sekunder). "Keterangan" adalah catatan tambahan, bukan
    // judul pengganti.
    final String title = _kategori!;
    final String? catatanBaru =
        _keteranganCtrl.text.trim().isEmpty ? null : _keteranganCtrl.text.trim(); // null bila keterangan kosong

    try {
      String narasiHasil; // kalimat yang akan diumumkan setelah berhasil
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
        ); // simpan transaksi baru ke repository
        narasiHasil = 'Tersimpan. ${transaksi.narasi}';
      }

      if (!mounted) return; // batalkan bila widget sudah dilepas selama proses async

      // Diumumkan lewat sistem aksesibilitas, bukan hanya snackbar.
      // Snackbar hilang dalam empat detik dan sering terlewat TalkBack.
      SemanticsService.sendAnnouncement(
        View.of(context),
        narasiHasil,
        Directionality.of(context),
      );
      Navigator.pop(context, true); // tutup modal, beri tahu pemanggil bahwa berhasil
    } catch (e) {
      if (!mounted) return; // batalkan bila widget sudah dilepas
      setState(() => _menyimpan = false); // kembalikan status agar tombol simpan bisa dicoba lagi
      _pesan('Transaksi belum tersimpan. Periksa isian lalu coba lagi.');
    }
  }

  /// Dengarkan ucapan lewat AI dan isikan hasilnya ke form yang sedang
  /// terbuka ini — beda dari [mulaiCatatTransaksiSuara] yang dipakai
  /// tombol mic di halaman lain, yang membuka form BARU. Di sini
  /// pengguna sudah berada di dalam form, jadi hasilnya menimpa isian
  /// yang sudah ada alih-alih membuka form kedua di atasnya.
  Future<void> _pakaiSuara() async {
    final String? teks = await dengarkanUcapan(context); // rekam dan ubah ucapan jadi teks
    if (teks == null || teks.trim().isEmpty || !mounted) return; // batalkan bila tidak ada hasil

    final hasil = await uraikanUcapanTransaksi(context, teks); // uraikan teks jadi data transaksi lewat AI
    if (hasil == null || !mounted) return; // batalkan bila gagal diuraikan

    setState(() {
      if (hasil.jenis == 'masuk') _isIncome = true; // terapkan jenis pemasukan bila terdeteksi
      if (hasil.jenis == 'keluar') _isIncome = false; // terapkan jenis pengeluaran bila terdeteksi
      if (hasil.nominal != null) {
        _nominalCtrl.text = hasil.nominal.toString(); // isi nominal dari hasil pengenalan suara
      }
      if (hasil.catatan.isNotEmpty) {
        _keteranganCtrl.text = hasil.catatan; // isi keterangan dari hasil pengenalan suara
      }
      if (hasil.kategori != null) _kategori = hasil.kategori; // isi kategori dari hasil pengenalan suara
      if (_metodeValid(hasil.metode)) _metode = hasil.metode!; // isi metode bayar dari hasil pengenalan suara
    });
    // Memuat ulang daftar kategori untuk jenis (masuk/keluar) yang
    // mungkin baru saja berubah — _kategori sudah diisi di atas jadi
    // tidak akan tertimpa balik ke kategori pertama.
    await _muatKategoriAwal();

    if (!mounted) return; // batalkan bila widget sudah dilepas
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
        duration: const Duration(seconds: 5), // durasi tampil snackbar lebih lama dari bawaan
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
          bottom: MediaQuery.of(context).viewInsets.bottom + 20, // tambah jarak bawah saat keyboard muncul
        ),
        decoration: BoxDecoration(
          color: context.warnaKartu,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), // sudut atas membulat, seperti bottom sheet
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
                ), // gagang kecil penanda visual bahwa ini bisa digeser/ditutup
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
                    onPressed: () => Navigator.pop(context), // tutup modal tanpa menyimpan
                    tooltip: 'Tutup',
                    icon: Icon(
                      Icons.chevron_left,
                      size: 30,
                      color: context.warnaTeksUtama,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _modeEdit ? 'Edit Transaksi' : 'Input Transaksi', // judul berubah sesuai mode
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
                        setState(() => _isIncome = true); // pilih jenis pemasukan
                        _muatKategori(); // muat ulang kategori sesuai jenis baru
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
                        setState(() => _isIncome = false); // pilih jenis pengeluaran
                        _muatKategori(); // muat ulang kategori sesuai jenis baru
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
                  onTap: _pilihTanggal, // buka kalender pemilih tanggal
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
                          DateFormatter.full(_tanggal), // tampilkan tanggal terpilih dalam format lengkap
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
                keyboardType: TextInputType.number, // munculkan keyboard angka
                inputFormatters: [FilteringTextInputFormatter.digitsOnly], // hanya izinkan digit diketik
                onChanged: (_) => setState(() {}), // bangun ulang agar teks lisan di bawah ikut diperbarui
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
                  liveRegion: true, // area yang otomatis diumumkan ulang saat isinya berubah
                  child: Text(
                    CurrencyFormatter.spoken(_nominal!), // nominal dalam bentuk kata-kata terucap
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
                onTap: _pilihKategori, // buka halaman pemilih kategori
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
                      onTap: () => setState(() => _metode = 'tunai'), // pilih metode tunai
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      label: 'Non Tunai',
                      icon: Icons.credit_card_outlined,
                      isSelected: _metode == 'non tunai',
                      onTap: () => setState(() => _metode = 'non tunai'), // pilih metode non tunai
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
                  onTap: _pakaiSuara, // mulai pengenalan suara dan isi form otomatis
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
                  onPressed: _menyimpan ? null : _simpan, // nonaktifkan tombol selagi sedang menyimpan
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
                        : (_modeEdit ? 'Simpan Perubahan' : 'Simpan Transaksi'), // label tombol sesuai status/mode
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
        fontSize: besar ? 17 : 16, // ukuran hint menyesuaikan mode besar
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
        vertical: besar ? 20 : 16, // padding vertikal lebih besar pada mode besar
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
  final String label; // teks yang ditampilkan pada kartu
  final IconData icon; // ikon arah (masuk/keluar)
  final bool isSelected; // true bila kartu ini sedang aktif dipilih
  final Color bgColor; // warna latar saat terpilih
  final Color iconColor; // warna ikon dan garis tepi saat terpilih
  final VoidCallback onTap; // aksi saat kartu diketuk

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
            color: isSelected ? bgColor : context.warnaKartu, // latar berubah saat terpilih
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
  final String label; // teks metode pembayaran
  final IconData icon; // ikon metode pembayaran
  final bool isSelected; // true bila opsi ini sedang aktif dipilih
  final VoidCallback onTap; // aksi saat opsi diketuk

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
  final String nilai; // teks nilai yang sedang terpilih
  final String labelSemantik; // teks lengkap yang dibacakan pembaca layar
  final IconData ikon; // ikon di sisi kiri baris
  final VoidCallback onTap; // aksi saat baris diketuk

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
