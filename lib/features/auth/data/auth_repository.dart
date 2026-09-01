import 'dart:convert'; // Untuk encode/decode teks ke bytes (utf8, base64Url)
import 'dart:math'; // Untuk Random.secure() pembuat garam acak

import 'package:crypto/crypto.dart'; // Untuk fungsi hash sha256
import 'package:sqflite/sqflite.dart'; // Untuk akses basis data SQLite

import '../../../core/database/database_helper.dart'; // Helper koneksi database aplikasi

/// ─────────────────────────────────────────────────────────────────
/// AUTH REPOSITORY  –  Penyimpanan dan verifikasi PIN
///
/// PIN tidak pernah disimpan apa adanya. Yang tersimpan adalah hasil
/// pengacakan searah beserta garamnya, sehingga isi basis data yang
/// bocor tidak langsung membuka akun.
///
/// Seluruh verifikasi berjalan di perangkat, tanpa memanggil server.
/// Pengguna tetap dapat masuk ke aplikasinya tanpa koneksi internet.
/// ─────────────────────────────────────────────────────────────────

class AuthRepository {
  AuthRepository._(); // Konstruktor privat, mencegah pembuatan instance dari luar
  static final AuthRepository instance = AuthRepository._(); // Satu-satunya instance (pola singleton)

  Future<Database> get _db async => DatabaseHelper.instance.database; // Ambil koneksi database saat dibutuhkan

  static const String _kunciHash = 'pin_hash'; // Kunci penyimpanan hash PIN
  static const String _kunciGaram = 'pin_salt'; // Kunci penyimpanan garam (salt)
  static const String _kunciGagal = 'pin_failed_attempts'; // Kunci penghitung percobaan gagal
  static const String _kunciKunciSampai = 'pin_locked_until'; // Kunci waktu berakhirnya penguncian
  static const String _kunciBiometrik = 'biometrik_aktif'; // Kunci status aktif/tidaknya biometrik

  /// Batas percobaan sebelum aplikasi dikunci sementara.
  ///
  /// PIN enam angka hanya punya satu juta kombinasi. Tanpa pembatasan,
  /// seluruh kemungkinan dapat dicoba oleh siapa pun yang memegang
  /// perangkat dalam waktu yang tidak lama.
  static const int maksPercobaan = 5; // Maksimal percobaan PIN salah sebelum dikunci
  static const int menitPenguncian = 5; // Lama penguncian dalam menit

  // ── Status ────────────────────────────────────────────────────────

  Future<bool> sudahAdaPin() async { // Cek apakah PIN sudah pernah diatur
    return await _ambil(_kunciHash) != null; // true jika hash PIN sudah tersimpan
  }

  /// Sisa detik penguncian. Nol berarti tidak sedang terkunci.
  Future<int> sisaPenguncian() async { // Hitung berapa detik lagi aplikasi masih terkunci
    final String? sampai = await _ambil(_kunciKunciSampai); // Ambil waktu batas penguncian tersimpan
    if (sampai == null) return 0; // Tidak ada data penguncian berarti tidak terkunci

    final DateTime batas = DateTime.parse(sampai); // Ubah teks waktu menjadi objek DateTime
    final int sisa = batas.difference(DateTime.now().toUtc()).inSeconds; // Selisih waktu sekarang ke batas, dalam detik
    return sisa > 0 ? sisa : 0; // Jangan kembalikan angka negatif
  }

  Future<int> sisaPercobaan() async { // Hitung sisa percobaan PIN yang masih diperbolehkan
    final int gagal = int.tryParse(await _ambil(_kunciGagal) ?? '0') ?? 0; // Jumlah percobaan gagal saat ini
    final int sisa = maksPercobaan - gagal; // Sisa percobaan = batas dikurangi yang sudah gagal
    return sisa > 0 ? sisa : 0; // Jangan kembalikan angka negatif
  }

  // ── Verifikasi dan penyimpanan ────────────────────────────────────

  Future<bool> verifikasiPin(String pin) async { // Cek apakah PIN yang dimasukkan pengguna benar
    final String? hash = await _ambil(_kunciHash); // Ambil hash PIN yang tersimpan
    final String? garam = await _ambil(_kunciGaram); // Ambil garam yang tersimpan
    if (hash == null || garam == null) return false; // Belum ada PIN tersimpan, gagal verifikasi

    final bool cocok = _hash(pin, garam) == hash; // Bandingkan hash PIN baru dengan yang tersimpan

    if (cocok) { // Jika PIN benar
      await _simpan(_kunciGagal, '0'); // Reset penghitung percobaan gagal
      await _hapus(_kunciKunciSampai); // Hapus status penguncian jika ada
    } else { // Jika PIN salah
      final int gagal =
          (int.tryParse(await _ambil(_kunciGagal) ?? '0') ?? 0) + 1; // Tambah penghitung percobaan gagal

      if (gagal >= maksPercobaan) { // Jika sudah melewati batas percobaan
        await _simpan(_kunciGagal, '0'); // Reset penghitung agar mulai lagi setelah kunci lepas
        await _simpan(
          _kunciKunciSampai,
          DateTime.now()
              .toUtc()
              .add(const Duration(minutes: menitPenguncian)) // Tambahkan durasi penguncian ke waktu sekarang
              .toIso8601String(), // Simpan sebagai teks format ISO8601
        );
      } else { // Belum mencapai batas
        await _simpan(_kunciGagal, '$gagal'); // Simpan penghitung gagal yang baru
      }
    }

    return cocok; // Kembalikan hasil verifikasi
  }

  Future<void> simpanPin(String pin) async { // Simpan PIN baru (hash + garam)
    final String garam = _buatGaram(); // Buat garam acak baru
    await _simpan(_kunciGaram, garam); // Simpan garam
    await _simpan(_kunciHash, _hash(pin, garam)); // Simpan hash PIN dengan garam tersebut
    await _simpan(_kunciGagal, '0'); // Reset penghitung percobaan gagal
    await _hapus(_kunciKunciSampai); // Hapus status penguncian jika ada
  }

  /// PIN yang terlalu mudah ditebak ditolak.
  ///
  /// Sebagian kecil kombinasi menutup persentase besar dari PIN yang
  /// dipakai orang di dunia nyata, sehingga menebaknya tidak
  /// memerlukan pencobaan sistematis.
  static const List<String> _pinLemah = [ // Daftar PIN yang dianggap terlalu lemah/umum
    '123456', '000000', '111111', '222222', '333333', '444444',
    '555555', '666666', '777777', '888888', '999999',
    '123123', '112233', '654321', '121212', '098765', '696969',
  ];

  /// Mengembalikan pesan galat, atau null bila PIN dapat diterima.
  String? periksaKekuatan(String pin) { // Validasi kekuatan PIN sebelum disimpan
    if (pin.length != 6) return 'PIN harus enam angka.'; // PIN wajib 6 digit
    if (_pinLemah.contains(pin)) { // Cek apakah termasuk daftar lemah
      return 'PIN ini terlalu mudah ditebak. Pilih enam angka lain.';
    }

    // Urutan naik atau turun, misalnya 456789 atau 987654
    bool naik = true; // Asumsikan awalnya urutan naik
    bool turun = true; // Asumsikan awalnya urutan turun
    for (int i = 1; i < pin.length; i++) { // Periksa selisih tiap digit berurutan
      final int selisih = pin.codeUnitAt(i) - pin.codeUnitAt(i - 1); // Selisih kode karakter antar digit
      if (selisih != 1) naik = false; // Bukan urutan naik jika selisih bukan 1
      if (selisih != -1) turun = false; // Bukan urutan turun jika selisih bukan -1
    }
    if (naik || turun) { // Jika PIN berurutan naik atau turun
      return 'PIN berurutan mudah ditebak. Pilih enam angka lain.';
    }

    return null; // PIN dianggap cukup kuat
  }

  // ── Biometrik ─────────────────────────────────────────────────────

  Future<bool> biometrikAktif() async => // Cek apakah login biometrik sedang aktif
      await _ambil(_kunciBiometrik) == '1'; // '1' berarti aktif

  Future<void> setBiometrik(bool aktif) => // Ubah status aktif/nonaktif biometrik
      _simpan(_kunciBiometrik, aktif ? '1' : '0'); // Simpan sebagai '1' atau '0'

  // ── Internal ──────────────────────────────────────────────────────

  String _buatGaram() { // Hasilkan garam acak untuk hashing PIN
    final Random acak = Random.secure(); // Generator angka acak yang aman secara kriptografi
    final List<int> byte = List<int>.generate(16, (_) => acak.nextInt(256)); // 16 byte acak
    return base64Url.encode(byte); // Ubah bytes menjadi teks base64
  }

  String _hash(String pin, String garam) { // Hitung hash dari PIN + garam
    return sha256.convert(utf8.encode('$garam$pin')).toString(); // Hash sha256 dari gabungan garam dan PIN
  }

  Future<String?> _ambil(String kunci) async { // Ambil satu nilai pengaturan dari database berdasarkan kunci
    final Database db = await _db; // Ambil koneksi database
    final List<Map<String, Object?>> baris = await db.query( // Query tabel pengaturan
      'pengaturan',
      where: 'kunci = ?', // Filter berdasarkan kolom kunci
      whereArgs: [kunci], // Nilai kunci yang dicari
      limit: 1, // Ambil maksimal satu baris
    );
    return baris.isEmpty ? null : baris.first['nilai'] as String; // Kembalikan nilai atau null jika tak ditemukan
  }

  Future<void> _simpan(String kunci, String nilai) async { // Simpan atau perbarui satu pasangan kunci-nilai
    final Database db = await _db; // Ambil koneksi database
    await db.insert( // Sisipkan baris baru, ganti jika sudah ada
      'pengaturan',
      {'kunci': kunci, 'nilai': nilai}, // Data yang disimpan
      conflictAlgorithm: ConflictAlgorithm.replace, // Timpa data lama jika kunci sudah ada
    );
  }

  Future<void> _hapus(String kunci) async { // Hapus satu baris pengaturan berdasarkan kunci
    final Database db = await _db; // Ambil koneksi database
    await db.delete('pengaturan', where: 'kunci = ?', whereArgs: [kunci]); // Hapus baris yang cocok
  }
}
