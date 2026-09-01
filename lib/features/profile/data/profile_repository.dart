import 'package:sqflite/sqflite.dart'; // Untuk akses basis data SQLite
import '../../../core/database/database_helper.dart'; // Helper koneksi database aplikasi

/// ─────────────────────────────────────────────────────────────────
/// PROFILE REPOSITORY
///
/// Menyimpan & membaca data profil pengguna menggunakan tabel
/// `pengaturan` (key-value) yang sudah ada di database lokal.
///
/// Kunci yang digunakan:
///   profil_nama         → nama lengkap
///   profil_email        → email
///   profil_no_hp        → nomor HP
///   profil_nama_usaha   → nama usaha
///   profil_jenis_usaha  → jenis/bidang usaha
///   profil_alamat       → alamat usaha
///   profil_jabatan      → jabatan (Pemilik Usaha, dsb)
///
/// PIN BUKAN tanggung jawab kelas ini. PIN dikunci lewat AuthRepository
/// (lib/features/auth/data/auth_repository.dart), yang juga dipakai
/// PinLockPage untuk membuka aplikasi — satu-satunya sumber kebenaran.
/// Kelas ini sebelumnya punya verifikasiPin()/simpanPin() sendiri yang
/// menyimpan ke kunci 'profil_pin' terpisah; itu sebabnya mengganti
/// PIN lewat halaman Ganti PIN tidak pernah benar-benar mengubah PIN
/// yang dipakai membuka aplikasi. Method itu sudah dihapus — jangan
/// ditambahkan kembali di sini.
/// ─────────────────────────────────────────────────────────────────

class ProfileRepository {
  ProfileRepository._(); // Konstruktor privat untuk pola singleton
  static final ProfileRepository instance = ProfileRepository._(); // Satu-satunya instance repository

  // ── Nilai default ──────────────────────────────────────────────
  //
  // Sengaja kosong, bukan data contoh seperti "ModioKu" atau
  // "Warung Sarna". Pengguna baru yang belum mengisi profilnya tidak
  // boleh melihat identitas orang lain seolah itu miliknya — layar
  // yang memakai nilai ini wajib menampilkan sapaan tanpa nama saat
  // kosong, bukan menganggap string kosong sebagai "belum siap".
  static const Map<String, String> _defaults = { // Nilai bawaan tiap kunci profil jika belum diisi
    'profil_nama':        '',
    'profil_email':       '',
    'profil_no_hp':       '',
    'profil_nama_usaha':  '',
    'profil_jenis_usaha': '',
    'profil_alamat':      '',
    'profil_jabatan':     '',
  };

  // ── Helper internal ────────────────────────────────────────────
  Future<Database> get _db async => DatabaseHelper.instance.database; // Ambil koneksi database saat dibutuhkan

  Future<String> _baca(String kunci) async { // Baca satu nilai profil berdasarkan kunci
    final db = await _db; // Ambil koneksi database
    final rows = await db.query( // Query tabel pengaturan
      'pengaturan',
      where: 'kunci = ?', // Filter berdasarkan kolom kunci
      whereArgs: [kunci], // Nilai kunci yang dicari
    );
    if (rows.isEmpty) return _defaults[kunci] ?? ''; // Kembalikan default jika belum ada data
    return rows.first['nilai'] as String; // Kembalikan nilai tersimpan
  }

  // ── API Publik: baca semua sekaligus ───────────────────────────

  /// Mengembalikan semua data profil dalam satu Map.
  Future<Map<String, String>> bacaProfil() async { // Ambil seluruh data profil sekaligus
    final db = await _db; // Ambil koneksi database
    final kunciProfil = _defaults.keys.toList(); // Daftar semua kunci profil yang dikenal
    final rows = await db.query( // Query semua baris dengan kunci-kunci profil
      'pengaturan',
      where: 'kunci IN (${kunciProfil.map((_) => '?').join(',')})', // Filter kunci ada di dalam daftar
      whereArgs: kunciProfil, // Nilai-nilai kunci yang dicari
    );

    // Mulai dari default, timpa dengan nilai dari DB
    final Map<String, String> hasil = Map.from(_defaults); // Salin nilai default sebagai awal
    for (final row in rows) { // Timpa nilai default dengan data tersimpan di DB
      hasil[row['kunci'] as String] = row['nilai'] as String;
    }
    return hasil; // Kembalikan gabungan default dan data tersimpan
  }

  // ── API Publik: simpan data profil ─────────────────────────────

  Future<void> simpanInfoPribadi({ // Simpan data profil pengguna sekaligus
    required String nama,
    required String email,
    required String noHp,
    required String namaUsaha,
    required String jenisUsaha,
    required String alamat,
  }) async {
    final db = await _db; // Ambil koneksi database
    final Batch batch = db.batch(); // Kumpulkan beberapa operasi jadi satu batch
    void set(String k, String v) => // Fungsi kecil untuk menambah satu operasi simpan ke batch
        batch.insert('pengaturan', {'kunci': k, 'nilai': v},
            conflictAlgorithm: ConflictAlgorithm.replace); // Timpa data lama jika kunci sudah ada

    set('profil_nama', nama); // Antrikan penyimpanan nama
    set('profil_email', email); // Antrikan penyimpanan email
    set('profil_no_hp', noHp); // Antrikan penyimpanan nomor HP
    set('profil_nama_usaha', namaUsaha); // Antrikan penyimpanan nama usaha
    set('profil_jenis_usaha', jenisUsaha); // Antrikan penyimpanan jenis usaha
    set('profil_alamat', alamat); // Antrikan penyimpanan alamat

    await batch.commit(noResult: true); // Jalankan semua operasi batch sekaligus
  }

  // ── Getter cepat untuk header profil ──────────────────────────

  Future<String> bacaNama()    async => _baca('profil_nama'); // Baca nama saja secara cepat
  Future<String> bacaJabatan() async => _baca('profil_jabatan'); // Baca jabatan saja secara cepat
}
