import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

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
  ProfileRepository._();
  static final ProfileRepository instance = ProfileRepository._();

  // ── Nilai default ──────────────────────────────────────────────
  //
  // Sengaja kosong, bukan data contoh seperti "ModioKu" atau
  // "Warung Sarna". Pengguna baru yang belum mengisi profilnya tidak
  // boleh melihat identitas orang lain seolah itu miliknya — layar
  // yang memakai nilai ini wajib menampilkan sapaan tanpa nama saat
  // kosong, bukan menganggap string kosong sebagai "belum siap".
  static const Map<String, String> _defaults = {
    'profil_nama':        '',
    'profil_email':       '',
    'profil_no_hp':       '',
    'profil_nama_usaha':  '',
    'profil_jenis_usaha': '',
    'profil_alamat':      '',
    'profil_jabatan':     '',
  };

  // ── Helper internal ────────────────────────────────────────────
  Future<Database> get _db async => DatabaseHelper.instance.database;

  Future<String> _baca(String kunci) async {
    final db = await _db;
    final rows = await db.query(
      'pengaturan',
      where: 'kunci = ?',
      whereArgs: [kunci],
    );
    if (rows.isEmpty) return _defaults[kunci] ?? '';
    return rows.first['nilai'] as String;
  }

  // ── API Publik: baca semua sekaligus ───────────────────────────

  /// Mengembalikan semua data profil dalam satu Map.
  Future<Map<String, String>> bacaProfil() async {
    final db = await _db;
    final kunciProfil = _defaults.keys.toList();
    final rows = await db.query(
      'pengaturan',
      where: 'kunci IN (${kunciProfil.map((_) => '?').join(',')})',
      whereArgs: kunciProfil,
    );

    // Mulai dari default, timpa dengan nilai dari DB
    final Map<String, String> hasil = Map.from(_defaults);
    for (final row in rows) {
      hasil[row['kunci'] as String] = row['nilai'] as String;
    }
    return hasil;
  }

  // ── API Publik: simpan data profil ─────────────────────────────

  Future<void> simpanInfoPribadi({
    required String nama,
    required String email,
    required String noHp,
    required String namaUsaha,
    required String jenisUsaha,
    required String alamat,
  }) async {
    final db = await _db;
    final Batch batch = db.batch();
    void set(String k, String v) =>
        batch.insert('pengaturan', {'kunci': k, 'nilai': v},
            conflictAlgorithm: ConflictAlgorithm.replace);

    set('profil_nama', nama);
    set('profil_email', email);
    set('profil_no_hp', noHp);
    set('profil_nama_usaha', namaUsaha);
    set('profil_jenis_usaha', jenisUsaha);
    set('profil_alamat', alamat);

    await batch.commit(noResult: true);
  }

  // ── Getter cepat untuk header profil ──────────────────────────

  Future<String> bacaNama()    async => _baca('profil_nama');
  Future<String> bacaJabatan() async => _baca('profil_jabatan');
}
