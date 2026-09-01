/// ─────────────────────────────────────────────────────────────────
/// TRANSACTION MODEL  –  Model data transaksi keuangan
///
/// Sumber kebenaran tunggal untuk model transaksi.
///
/// PERUBAHAN DARI VERSI SEBELUMNYA:
///   • `nominal` bertipe int, bukan String berformat "Rp 200.000".
///     Format tampilan dihitung saat ditampilkan, bukan disimpan.
///   • `occurredAt` bertipe DateTime menggantikan `time` String + `date`.
///     Waktu berformat teks membuat pengurutan salah: "9.05" dianggap
///     lebih besar dari "14.45" secara alfabetis.
///   • Ditambahkan `kategori`, `mode`, dan `syncStatus`.
///   • Field lama (`amount`, `time`, `amountRaw`) tetap tersedia sebagai
///     getter turunan, sehingga layar yang sudah ada tidak perlu diubah.
/// ─────────────────────────────────────────────────────────────────
library;

import '../../../core/utils/currency_formatter.dart'; // Format angka jadi teks rupiah/terucap

/// Tipe transaksi: uang masuk atau keluar
enum TransactionType {
  masuk,   // Pemasukan (penjualan, iuran, donasi)
  keluar,  // Pengeluaran (bahan baku, biaya, gaji)
}

/// Status pengiriman ke server. Belum dipakai selama aplikasi masih
/// lokal, tapi disiapkan sejak awal: menambahkannya setelah ada data
/// pengguna berarti membongkar tabel yang sudah berisi catatan keuangan.
enum SyncStatus { pending, syncing, synced, failed } // Belum dikirim, sedang dikirim, sudah, gagal

/// Model satu item transaksi keuangan
class TransactionItem {
  final String id;                // ULID, dibuat di perangkat
  final String title;             // Judul transaksi
  final int nominal;              // Rupiah utuh. TIDAK PERNAH double.
  final String method;            // tunai, non tunai
  final String kategori;          // Nama kategori
  final TransactionType type;     // masuk / keluar
  final DateTime occurredAt;      // Waktu kejadian, disimpan UTC
  final String? catatan;          // Catatan tambahan, boleh kosong
  final String sumberInput;       // manual / suara
  final SyncStatus syncStatus;    // Status sinkronisasi ke server

  const TransactionItem({
    required this.id,
    required this.title,
    required this.nominal,
    required this.method,
    required this.type,
    required this.occurredAt,
    this.kategori = 'Lainnya', // Default bila kategori tidak diisi
    this.catatan,
    this.sumberInput = 'manual', // Default: dimasukkan manual, bukan suara
    this.syncStatus = SyncStatus.pending, // Default: belum tersinkron
  });

  // ── Getter turunan ────────────────────────────────────────────────
  // Menjaga agar layar yang sudah memakai field lama tetap berfungsi.

  /// "Rp 200.000" — untuk ditampilkan di layar
  String get amount => CurrencyFormatter.format(nominal); // Hitung format tampilan dari nominal

  /// Alias lama. Dipertahankan agar kode yang sudah ada tidak rusak.
  int get amountRaw => nominal; // Sama persis dengan nominal

  /// "14.45" — waktu setempat
  String get time => DateFormatter.time(occurredAt.toLocal()); // Ubah UTC ke waktu lokal lalu format jam

  /// Tanggal setempat
  DateTime get date => occurredAt.toLocal(); // Konversi waktu tersimpan (UTC) ke zona pengguna

  // ── Aksesibilitas ─────────────────────────────────────────────────

  /// "dua ratus ribu rupiah" — untuk dibacakan screen reader.
  ///
  /// TalkBack membaca "Rp 200.000" sebagai "Rp dua titik nol nol nol",
  /// deretan digit yang mustahil dipahami sebagai jumlah uang.
  String get spokenAmount => CurrencyFormatter.spoken(nominal); // Nominal dalam bentuk kalimat terucap

  /// Satu kalimat utuh untuk label semantik.
  ///
  String get narasi {
    final arah = type == TransactionType.masuk ? 'Uang masuk' : 'Uang keluar'; // Pilih kata sesuai jenis transaksi
    final waktu = DateFormatter.full(occurredAt.toLocal()); // Format tanggal+jam lengkap dalam waktu lokal
    final antre = syncStatus == SyncStatus.pending
        ? '. Belum tersimpan di server' // Tambahan info bila masih menunggu sinkron
        : '';
    return '$arah $spokenAmount, $kategori, $method, $waktu$antre'; // Gabungkan semua jadi satu kalimat
  }

  // ── Konversi basis data ───────────────────────────────────────────

  Map<String, dynamic> toMap() => { // Ubah objek jadi Map untuk disimpan ke SQLite
        'id': id,
        'title': title,
        'nominal': nominal,
        'method': method,
        'kategori': kategori,
        'type': type.name, // Simpan enum sebagai teks nama variannya
        'occurred_at': occurredAt.toUtc().toIso8601String(), // Simpan waktu dalam format UTC ISO 8601
        'catatan': catatan,
        'sumber_input': sumberInput,
        'sync_status': syncStatus.name,
      };

  factory TransactionItem.fromMap(Map<String, dynamic> map) { // Bangun objek dari baris hasil query SQLite
    return TransactionItem(
      id: map['id'] as String,
      title: map['title'] as String,
      nominal: map['nominal'] as int,
      method: map['method'] as String,
      kategori: (map['kategori'] as String?) ?? 'Lainnya', // Fallback bila kolom kosong/null
      type: map['type'] == 'masuk'
          ? TransactionType.masuk
          : TransactionType.keluar, // Ubah teks kembali jadi enum
      occurredAt: DateTime.parse(map['occurred_at'] as String).toUtc(), // Urai teks ISO jadi DateTime UTC
      catatan: map['catatan'] as String?,
      sumberInput: (map['sumber_input'] as String?) ?? 'manual',
      syncStatus: SyncStatus.values.firstWhere( // Cari enum yang namanya cocok dengan teks tersimpan
        (s) => s.name == map['sync_status'],
        orElse: () => SyncStatus.pending, // Fallback bila nilai tidak dikenali
      ),
    );
  }

  TransactionItem copyWith({ // Buat salinan objek dengan sebagian field diganti
    String? title,
    int? nominal,
    String? method,
    String? kategori,
    TransactionType? type,
    DateTime? occurredAt,
    String? catatan,
    SyncStatus? syncStatus,
  }) {
    return TransactionItem(
      id: id, // id tidak pernah diganti lewat copyWith
      title: title ?? this.title, // Pakai nilai baru bila diberikan, jika tidak pakai nilai lama
      nominal: nominal ?? this.nominal,
      method: method ?? this.method,
      kategori: kategori ?? this.kategori,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      catatan: catatan ?? this.catatan,
      sumberInput: sumberInput, // Field ini tidak bisa diganti lewat copyWith
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// Ringkasan keuangan untuk ditampilkan di dashboard
class FinancialSummary {
  final int saldo; // Saldo saat ini
  final int pemasukanHariIni; // Total uang masuk hari ini
  final int pengeluaranHariIni; // Total uang keluar hari ini
  final int jumlahTransaksi; // Banyak transaksi hari ini

  const FinancialSummary({
    required this.saldo,
    required this.pemasukanHariIni,
    required this.pengeluaranHariIni,
    required this.jumlahTransaksi,
  });

  int get labaHariIni => pemasukanHariIni - pengeluaranHariIni; // Selisih masuk dan keluar

  /// Dirakit dari template berisi angka hasil perhitungan, bukan
  /// dibangkitkan model bahasa. Angka pada laporan keuangan tidak
  /// boleh mengandung kemungkinan kekeliruan.
  String get narasi {
    final b = StringBuffer(); // Kumpulkan potongan kalimat secara efisien

    if (jumlahTransaksi == 0) { // Kasus khusus: belum ada transaksi sama sekali
      b.write('Hari ini belum ada transaksi. '
          'Saldo Anda ${CurrencyFormatter.spoken(saldo)}.');
      return b.toString();
    }

    b
      ..write('Hari ini masuk ${CurrencyFormatter.spoken(pemasukanHariIni)}, ')
      ..write('keluar ${CurrencyFormatter.spoken(pengeluaranHariIni)}. '); // Rangkai dua kalimat berurutan

    if (labaHariIni > 0) {
      b.write('Untung ${CurrencyFormatter.spoken(labaHariIni)}. '); // Kasus untung
    } else if (labaHariIni < 0) {
      b.write('Rugi ${CurrencyFormatter.spoken(-labaHariIni)}. '); // Kasus rugi, nilai dibalik jadi positif
    } else {
      b.write('Uang masuk dan keluar sama besar. '); // Kasus impas
    }

    b.write('Saldo Anda sekarang ${CurrencyFormatter.spoken(saldo)}.');
    return b.toString(); // Gabungkan semua potongan jadi satu String
  }
}

/// Data contoh untuk pengembangan tampilan.
///
/// Setelah repository tersambung, kelas ini tidak dipakai lagi.
/// Pertahankan sementara agar layar tetap bisa dibuka saat basis data
/// belum siap.
class TransactionDummy {
  TransactionDummy._(); // Constructor privat: kelas ini tidak boleh diinstansiasi

  static final List<TransactionItem> todayTransactions = [ // Daftar transaksi contoh statis
    TransactionItem(
      id: 'TRX-003',
      title: 'Penjualan #3',
      nominal: 900000,
      method: 'non tunai',
      kategori: 'Penjualan',
      type: TransactionType.masuk,
      occurredAt: DateTime.now().subtract(const Duration(hours: 2)), // 2 jam lalu dari sekarang
    ),
    TransactionItem(
      id: 'TRX-002',
      title: 'Penjualan #2',
      nominal: 790000,
      method: 'non tunai',
      kategori: 'Penjualan',
      type: TransactionType.masuk,
      occurredAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    TransactionItem(
      id: 'TRX-001',
      title: 'Penjualan #1',
      nominal: 500000,
      method: 'non tunai',
      kategori: 'Penjualan',
      type: TransactionType.masuk,
      occurredAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    TransactionItem(
      id: 'TRX-000',
      title: 'Iuran sampah',
      nominal: 230000,
      method: 'tunai',
      kategori: 'Pengeluaran Lain',
      type: TransactionType.keluar,
      occurredAt: DateTime.now().subtract(const Duration(hours: 7)),
    ),
  ];
}
