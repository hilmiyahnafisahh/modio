import 'package:sqflite/sqflite.dart'; // Import driver database SQLite

import '../../../core/akuntansi/coa.dart'; // Kelompok akun COA untuk kategori baru
import '../../../core/database/database_helper.dart'; // Helper untuk membuka koneksi database aplikasi
import '../../../core/utils/ulid.dart'; // Fungsi bantu membuat id unik (ULID) untuk transaksi baru
import 'transaction_model.dart'; // Model data transaksi & ringkasan keuangan

/// Rentang waktu untuk menyaring riwayat
enum PeriodeFilter { semua, hariIni, mingguIni, bulanIni, tahunIni } // Pilihan rentang waktu: semua, hari ini, minggu ini, bulan ini, tahun ini

extension PeriodeFilterX on PeriodeFilter { // Tambahan fungsi/getter untuk enum PeriodeFilter
  String get label => switch (this) { // Teks label yang bisa ditampilkan ke pengguna untuk tiap pilihan
        PeriodeFilter.semua => 'Semua waktu', // Label untuk filter semua waktu
        PeriodeFilter.hariIni => 'Hari ini', // Label untuk filter hari ini
        PeriodeFilter.mingguIni => 'Minggu ini', // Label untuk filter minggu ini
        PeriodeFilter.bulanIni => 'Bulan ini', // Label untuk filter bulan ini
        PeriodeFilter.tahunIni => 'Tahun ini', // Label untuk filter tahun ini
      };

  /// Batas awal periode dalam waktu setempat. null berarti tanpa batas.
  DateTime? get mulai { // Menghitung tanggal/waktu awal periode berdasarkan pilihan filter
    final DateTime now = DateTime.now(); // Waktu sekarang di perangkat
    return switch (this) {
      PeriodeFilter.semua => null, // Tanpa batas awal untuk filter semua waktu
      PeriodeFilter.hariIni => DateTime(now.year, now.month, now.day), // Awal hari ini pukul 00:00
      PeriodeFilter.mingguIni => DateTime(now.year, now.month, now.day) // Mulai dari awal hari ini
          .subtract(Duration(days: now.weekday - 1)), // Mundur ke hari Senin minggu ini
      PeriodeFilter.bulanIni => DateTime(now.year, now.month, 1), // Tanggal 1 bulan berjalan
      PeriodeFilter.tahunIni => DateTime(now.year), // 1 Januari tahun berjalan
    };
  }
}

/// Satu-satunya pintu ke basis data.
///
/// Layar TIDAK BOLEH memanggil SQLite langsung. Kalau nanti sinkronisasi
/// server ditambahkan, hanya berkas ini yang berubah — bukan setiap layar.
///
/// ATURAN PENTING: setiap query yang menyentuh transaksi wajib menyaring
/// berdasarkan mode. Melewatkannya membuat saldo usaha dan organisasi
/// tercampur — persis masalah yang fitur ini seharusnya selesaikan, dan
/// pengguna tunanetra tidak punya cara melihat bahwa angkanya salah.
class TransaksiRepository { // Kelas satu-satunya jalur akses ke tabel transaksi & pengaturan terkait
  Future<Database> get _db async => DatabaseHelper.instance.database; // Getter singkat untuk mengambil koneksi database

  // ── Mode pembukuan ────────────────────────────────────────────────

  /// Mengganti mode aktif dan mengembalikan ringkasan mode yang baru.
  ///
  /// Ringkasan ikut dikembalikan supaya pemanggil bisa langsung
  /// mengumumkan saldo mode tujuan. Tanpa itu, pengguna hanya mendengar
  /// "sekarang mode Organisasi" tanpa cara memastikan ia benar berpindah.
  // ── Transaksi ─────────────────────────────────────────────────────

  /// Menyimpan transaksi baru pada mode yang sedang aktif.
  Future<TransactionItem> simpan({ // Fungsi menyimpan satu transaksi baru ke database
    required String title, // Judul/nama transaksi, wajib diisi
    required int nominal, // Jumlah uang transaksi, wajib diisi
    required TransactionType type, // Jenis transaksi (masuk/keluar), wajib diisi
    required String method, // Metode pembayaran, wajib diisi
    String kategori = 'Lainnya', // Kategori transaksi, default "Lainnya" jika tidak diisi
    String? catatan, // Catatan tambahan opsional
    String sumberInput = 'manual', // Sumber input data, default diketik manual
    DateTime? waktu, // Waktu kejadian opsional, default waktu sekarang
  }) async {
    if (nominal <= 0) { // Validasi: nominal harus lebih dari nol
      throw ArgumentError('Nominal harus lebih besar dari nol.'); // Lempar error jika nominal tidak valid
    }

    final DateTime sekarang = DateTime.now().toUtc(); // Waktu saat ini dalam UTC, dipakai untuk created_at/updated_at
    final TransactionItem transaksi = TransactionItem( // Buat objek transaksi baru dari data yang diberikan
      id: Ulid.generate(), // Buat id unik baru untuk transaksi ini
      title: title, // Judul transaksi
      nominal: nominal, // Nominal transaksi
      method: method, // Metode pembayaran
      kategori: kategori, // Kategori transaksi
      type: type, // Jenis transaksi (masuk/keluar)
      catatan: catatan, // Catatan tambahan
      sumberInput: sumberInput, // Sumber input data
      occurredAt: waktu?.toUtc() ?? sekarang, // Waktu kejadian: pakai yang diberikan, atau waktu sekarang jika kosong
    );

    final Database db = await _db; // Buka/tunggu koneksi database
    await db.insert('transaksi', { // Sisipkan baris transaksi baru ke tabel 'transaksi'
      ...transaksi.toMap(), // Sebar seluruh field transaksi menjadi map kolom database
      'created_at': sekarang.toIso8601String(), // Catat waktu pembuatan baris
      'updated_at': sekarang.toIso8601String(), // Catat waktu pembaruan terakhir (sama dengan waktu buat)
    });

    return transaksi; // Kembalikan objek transaksi yang baru disimpan
  }

  /// Riwayat transaksi, terbaru dulu.
  ///
  /// [batas] null berarti tanpa batas — dipakai halaman riwayat penuh.
  /// [periode] menyaring berdasarkan waktu kejadian.
  /// [tanggalKhusus] bila diisi, menyaring ke satu hari kalender itu
  /// saja (misalnya tanggal yang dipilih lewat kalender), dan
  /// mengabaikan [periode] sepenuhnya — beda dari preset yang selalu
  /// relatif terhadap sekarang, tanggal ini bisa hari mana pun di masa
  /// lalu.
  /// [type] null berarti pemasukan dan pengeluaran keduanya.
  /// [cari] menyaring berdasarkan judul atau kategori.
  Future<List<TransactionItem>> riwayat({ // Mengambil daftar riwayat transaksi sesuai berbagai filter opsional
    int? batas = 30, // Jumlah maksimum transaksi diambil, default 30, null berarti tanpa batas
    String? sebelumId, // Untuk paginasi: hanya ambil transaksi dengan id lebih kecil dari ini
    PeriodeFilter periode = PeriodeFilter.semua, // Filter rentang waktu, default semua waktu
    DateTime? tanggalKhusus, // Filter ke satu tanggal spesifik, mengabaikan periode jika diisi
    DateTime? bulanKhusus, // Filter ke satu bulan kalender (tahun & bulan dari nilai ini), mengabaikan periode jika diisi
    TransactionType? type, // Filter jenis transaksi, null berarti semua jenis
    String? cari, // Kata kunci pencarian pada judul/kategori
  }) async {
    final Database db = await _db; // Buka/tunggu koneksi database

    final List<String> syarat = ['deleted_at IS NULL']; // Daftar kondisi SQL, mulai dengan: belum dihapus (soft delete)
    final List<Object?> nilai = <Object?>[]; // Daftar nilai pengganti tanda tanya pada kondisi SQL

    if (sebelumId != null) { // Jika sedang memuat halaman berikutnya (paginasi)
      syarat.add('id < ?'); // Tambahkan syarat id lebih kecil dari batas sebelumnya
      nilai.add(sebelumId); // Nilai id batas untuk syarat di atas
    }

    // Batas periode dihitung dari waktu setempat lalu diubah ke UTC
    // agar cocok dengan format penyimpanan.
    if (tanggalKhusus != null) { // Jika ada filter tanggal spesifik
      final DateTime awal = DateTime( // Awal hari (00:00) dari tanggal yang dipilih
        tanggalKhusus.year,
        tanggalKhusus.month,
        tanggalKhusus.day,
      );
      final DateTime akhir = awal.add(const Duration(days: 1)); // Awal hari berikutnya, jadi batas akhir rentang
      syarat.add('occurred_at >= ? AND occurred_at < ?'); // Syarat: waktu kejadian di antara awal dan akhir hari itu
      nilai.add(awal.toUtc().toIso8601String()); // Batas awal dalam format UTC
      nilai.add(akhir.toUtc().toIso8601String()); // Batas akhir dalam format UTC
    } else if (bulanKhusus != null) { // Jika ada filter satu bulan kalender
      final DateTime awal = DateTime(bulanKhusus.year, bulanKhusus.month); // Tanggal 1 bulan itu pukul 00:00
      final DateTime akhir = DateTime(bulanKhusus.year, bulanKhusus.month + 1); // Tanggal 1 bulan berikutnya
      syarat.add('occurred_at >= ? AND occurred_at < ?'); // Syarat: waktu kejadian di dalam bulan itu
      nilai.add(awal.toUtc().toIso8601String()); // Batas awal dalam format UTC
      nilai.add(akhir.toUtc().toIso8601String()); // Batas akhir dalam format UTC
    } else { // Jika tidak ada tanggal/bulan khusus, pakai filter periode biasa
      final DateTime? mulai = periode.mulai; // Ambil tanggal awal periode dari enum filter
      if (mulai != null) { // Jika periode punya batas awal (bukan "semua waktu")
        syarat.add('occurred_at >= ?'); // Syarat: waktu kejadian setelah atau sama dengan batas awal
        nilai.add(mulai.toUtc().toIso8601String()); // Nilai batas awal dalam format UTC
      }
    }

    if (type != null) { // Jika filter jenis transaksi diaktifkan
      syarat.add('type = ?'); // Syarat: jenis transaksi harus sama persis
      nilai.add(type.name); // Nilai jenis transaksi (nama enum sebagai teks)
    }

    if (cari != null && cari.trim().isNotEmpty) { // Jika ada kata kunci pencarian yang tidak kosong
      syarat.add('(title LIKE ? OR kategori LIKE ?)'); // Syarat: judul atau kategori mengandung kata kunci
      final String pola = '%${cari.trim()}%'; // Bungkus kata kunci dengan wildcard SQL LIKE
      nilai.add(pola); // Nilai untuk pencarian pada judul
      nilai.add(pola); // Nilai untuk pencarian pada kategori
    }

    final List<Map<String, Object?>> baris = await db.query( // Jalankan query dengan semua syarat yang terkumpul
      'transaksi', // Nama tabel yang dibaca
      where: syarat.join(' AND '), // Gabungkan semua syarat dengan AND
      whereArgs: nilai, // Nilai pengganti tanda tanya sesuai urutan syarat
      orderBy: 'id DESC', // Urutkan dari id terbesar (terbaru) ke terkecil
      limit: batas, // Batasi jumlah baris hasil sesuai parameter batas
    );

    return baris
        .map((b) => TransactionItem.fromMap(b.cast<String, dynamic>())) // Ubah tiap baris database jadi objek TransactionItem
        .toList(); // Kumpulkan hasilnya jadi List
  }

  /// Total pemasukan dan pengeluaran untuk sekumpulan transaksi yang
  /// sudah disaring.
  ///
  /// Dihitung di Dart, bukan lewat query terpisah, agar angkanya selalu
  /// cocok dengan daftar yang sedang ditampilkan.
  ({int masuk, int keluar, int selisih}) hitungTotal( // Menjumlahkan total masuk, keluar, dan selisihnya dari daftar transaksi
    List<TransactionItem> daftar, // Daftar transaksi yang akan dijumlahkan
  ) {
    int masuk = 0; // Akumulator total pemasukan, mulai dari nol
    int keluar = 0; // Akumulator total pengeluaran, mulai dari nol
    for (final TransactionItem t in daftar) { // Ulangi setiap transaksi dalam daftar
      if (t.type == TransactionType.masuk) { // Jika transaksi ini jenis pemasukan
        masuk += t.nominal; // Tambahkan nominalnya ke total pemasukan
      } else { // Jika bukan pemasukan (berarti pengeluaran)
        keluar += t.nominal; // Tambahkan nominalnya ke total pengeluaran
      }
    }
    return (masuk: masuk, keluar: keluar, selisih: masuk - keluar); // Kembalikan record berisi total masuk, keluar, dan selisih (laba)
  }

  /// Ringkasan saldo dan aktivitas hari ini.
  Future<FinancialSummary> ringkasanHariIni() async { // Mengambil ringkasan saldo total & aktivitas transaksi hari ini
    final Database db = await _db; // Buka/tunggu koneksi database

    final DateTime sekarang = DateTime.now(); // Waktu sekarang di perangkat (lokal)
    final DateTime mulai = // Awal hari ini pukul 00:00
        DateTime(sekarang.year, sekarang.month, sekarang.day);
    final DateTime selesai = mulai.add(const Duration(days: 1)); // Awal hari besok, jadi batas akhir rentang hari ini

    // Query SQL mentah: total masuk & keluar sepanjang masa (untuk saldo)
    final List<Map<String, Object?>> total = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'masuk'  THEN nominal END), 0) AS masuk,
        COALESCE(SUM(CASE WHEN type = 'keluar' THEN nominal END), 0) AS keluar
      FROM transaksi
      WHERE deleted_at IS NULL
    ''');

    // Query SQL mentah: total masuk, keluar, dan jumlah transaksi khusus hari ini
    final List<Map<String, Object?>> hariIni = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN type = 'masuk'  THEN nominal END), 0) AS masuk,
        COALESCE(SUM(CASE WHEN type = 'keluar' THEN nominal END), 0) AS keluar,
        COUNT(*) AS jumlah
      FROM transaksi
      WHERE deleted_at IS NULL
        AND occurred_at >= ? AND occurred_at < ?
    ''', [
      mulai.toUtc().toIso8601String(), // Batas awal hari ini dalam UTC
      selesai.toUtc().toIso8601String(), // Batas akhir hari ini dalam UTC
    ]);

    final int saldoAwal = int.tryParse( // Baca saldo awal dari pengaturan, ubah jadi angka
          await ambilPengaturan('saldo_awal') ?? '0', // Ambil nilai tersimpan, default '0' jika belum ada
        ) ??
        0; // Jika gagal diubah jadi angka, anggap saldo awal nol

    return FinancialSummary( // Bungkus semua hasil perhitungan jadi satu objek ringkasan
      saldo: saldoAwal + // Saldo akhir = saldo awal ditambah semua pemasukan dikurangi semua pengeluaran
          (total.first['masuk'] as num).toInt() -
          (total.first['keluar'] as num).toInt(),
      pemasukanHariIni: (hariIni.first['masuk'] as num).toInt(), // Total pemasukan khusus hari ini
      pengeluaranHariIni: (hariIni.first['keluar'] as num).toInt(), // Total pengeluaran khusus hari ini
      jumlahTransaksi: (hariIni.first['jumlah'] as num).toInt(), // Jumlah transaksi yang tercatat hari ini
    );
  }

  /// Daftar nama kategori untuk jenis transaksi tertentu.
  Future<List<String>> kategoriUntuk(TransactionType type) async { // Mengambil daftar nama kategori sesuai jenis transaksi
    final Database db = await _db; // Buka/tunggu koneksi database
    final List<Map<String, Object?>> baris = await db.query( // Query kategori yang cocok dengan jenis transaksi
      'kategori', // Nama tabel kategori
      columns: ['nama'], // Hanya ambil kolom nama, tidak perlu kolom lain
      where: 'type = ?', // Syarat: jenis kategori harus cocok
      whereArgs: [type.name], // Nilai jenis transaksi sebagai teks
      orderBy: 'id', // Urutkan berdasarkan id (urutan pembuatan)
    );
    return baris.map((b) => b['nama']! as String).toList(); // Ubah tiap baris jadi String nama kategori
  }

  /// Menambah kategori baru untuk jenis transaksi tertentu.
  ///
  /// Nama kategori yang sudah ada (sama persis, jenis sama) tidak
  /// dianggap galat — [ConflictAlgorithm.ignore] membuat baris duplikat
  /// diam-diam tidak disisipkan, sehingga pemanggil selalu bisa
  /// langsung memakai [nama] sebagai kategori terpilih tanpa perlu
  /// membedakan "baru dibuat" dari "sudah ada sebelumnya".
  Future<void> tambahKategori(String nama, TransactionType type) async { // Menambahkan kategori baru ke database
    final String bersih = nama.trim(); // Hilangkan spasi berlebih di awal/akhir nama
    if (bersih.isEmpty) { // Validasi: nama tidak boleh kosong
      throw ArgumentError('Nama kategori tidak boleh kosong.'); // Lempar error jika nama kosong
    }
    final Database db = await _db; // Buka/tunggu koneksi database
    await db.insert( // Sisipkan kategori baru ke tabel
      'kategori', // Nama tabel kategori
      {
        'nama': bersih,
        'type': type.name,
        // Kategori buatan pengguna (atau tebakan AI) belum punya kode
        // akun; kelompoknya ditebak dari jenis supaya tetap masuk ke
        // bagian laporan laba rugi yang wajar.
        'kelompok': KelompokAkun.bawaanUntuk(
          masuk: type == TransactionType.masuk,
        ).kode,
      }, // Data yang disisipkan: nama bersih, jenis, dan kelompok akun
      conflictAlgorithm: ConflictAlgorithm.ignore, // Abaikan diam-diam jika kategori dengan nama+jenis sama sudah ada
    );
  }

  /// Memperbarui transaksi yang sudah disimpan.
  ///
  /// Hanya field yang disediakan yang akan diperbarui; field lainnya
  /// tetap sama. Field updated_at selalu diperbarui.
  Future<void> perbarui({ // Memperbarui sebagian atau seluruh field transaksi yang sudah ada
    required String id, // Id transaksi yang akan diperbarui, wajib diisi
    String? title, // Judul baru, opsional
    int? nominal, // Nominal baru, opsional
    TransactionType? type, // Jenis baru, opsional
    String? method, // Metode bayar baru, opsional
    String? kategori, // Kategori baru, opsional
    String? catatan, // Catatan baru, opsional
    DateTime? waktu, // Waktu kejadian baru, opsional
  }) async {
    if (nominal != null && nominal <= 0) { // Validasi: jika nominal diisi, harus lebih dari nol
      throw ArgumentError('Nominal harus lebih besar dari nol.'); // Lempar error jika nominal tidak valid
    }

    final Database db = await _db; // Buka/tunggu koneksi database
    final Map<String, Object?> data = { // Data awal yang selalu diperbarui pada setiap panggilan
      'updated_at': DateTime.now().toUtc().toIso8601String(), // Catat waktu pembaruan terbaru
      'sync_status': 'pending', // Tandai perlu disinkronkan ulang ke server nanti
    };

    if (title != null) data['title'] = title; // Perbarui judul hanya jika diberikan
    if (nominal != null) data['nominal'] = nominal; // Perbarui nominal hanya jika diberikan
    if (type != null) data['type'] = type.name; // Perbarui jenis hanya jika diberikan
    if (method != null) data['method'] = method; // Perbarui metode bayar hanya jika diberikan
    if (kategori != null) data['kategori'] = kategori; // Perbarui kategori hanya jika diberikan
    if (catatan != null) data['catatan'] = catatan; // Perbarui catatan hanya jika diberikan
    if (waktu != null) data['occurred_at'] = waktu.toUtc().toIso8601String(); // Perbarui waktu kejadian hanya jika diberikan

    await db.update( // Jalankan pembaruan pada baris transaksi yang sesuai
      'transaksi', // Nama tabel yang diperbarui
      data, // Kumpulan kolom & nilai baru
      where: 'id = ?', // Syarat: hanya baris dengan id yang cocok
      whereArgs: [id], // Nilai id transaksi yang dituju
    );
  }

  /// Penghapusan lunak. Data keuangan tidak pernah dibuang permanen —
  /// pengguna harus bisa menelusuri kembali apa yang pernah tercatat.
  Future<void> hapus(String id) async { // Menghapus transaksi secara lunak (soft delete)
    final Database db = await _db; // Buka/tunggu koneksi database
    await db.update( // Perbarui baris transaksi, bukan benar-benar menghapusnya
      'transaksi', // Nama tabel yang diperbarui
      {
        'deleted_at': DateTime.now().toUtc().toIso8601String(), // Tandai waktu penghapusan agar dianggap terhapus
        'sync_status': 'pending', // Tandai perlu disinkronkan ulang ke server nanti
      },
      where: 'id = ?', // Syarat: hanya baris dengan id yang cocok
      whereArgs: [id], // Nilai id transaksi yang dituju
    );
  }

  // ── Pengaturan ────────────────────────────────────────────────────

  Future<String?> ambilPengaturan(String kunci) async { // Mengambil satu nilai pengaturan berdasarkan kuncinya
    final Database db = await _db; // Buka/tunggu koneksi database
    final List<Map<String, Object?>> baris = await db.query( // Query baris pengaturan dengan kunci yang dicari
      'pengaturan', // Nama tabel pengaturan
      where: 'kunci = ?', // Syarat: kunci harus cocok persis
      whereArgs: [kunci], // Nilai kunci yang dicari
      limit: 1, // Cukup ambil satu baris saja
    );
    return baris.isEmpty ? null : baris.first['nilai'] as String; // Kembalikan null jika tidak ditemukan, atau nilainya jika ada
  }

  Future<void> simpanPengaturan(String kunci, String nilai) async { // Menyimpan atau memperbarui satu pasangan kunci-nilai pengaturan
    final Database db = await _db; // Buka/tunggu koneksi database
    await db.insert( // Sisipkan (atau timpa) baris pengaturan
      'pengaturan', // Nama tabel pengaturan
      {'kunci': kunci, 'nilai': nilai}, // Data kunci dan nilai yang disimpan
      conflictAlgorithm: ConflictAlgorithm.replace, // Jika kunci sudah ada, timpa dengan nilai baru
    );
  }

  Future<void> simpanSaldoAwal(int nominal) => // Fungsi pintasan untuk menyimpan saldo awal
      simpanPengaturan('saldo_awal', nominal.toString()); // Simpan nominal sebagai teks dengan kunci 'saldo_awal'
}
