import 'package:flutter/foundation.dart'; // Untuk ValueNotifier (state yang bisa didengarkan)

/// Service untuk notifikasi saat profil pengguna diperbarui.
/// Digunakan untuk sync data profil ke seluruh app (dashboard, etc).
class ProfileUpdateService { // Layanan notifikasi perubahan profil ke seluruh aplikasi
  static final ProfileUpdateService _instance = ProfileUpdateService._internal(); // Satu-satunya instance layanan

  factory ProfileUpdateService() { // Factory constructor selalu mengembalikan instance yang sama
    return _instance;
  }

  ProfileUpdateService._internal(); // Konstruktor internal untuk pola singleton

  final ValueNotifier<DateTime> _updateNotifier = ValueNotifier(DateTime.now()); // Penanda waktu pembaruan terakhir

  /// Notifier yang dapat didengarkan untuk mendeteksi perubahan profil
  ValueNotifier<DateTime> get updateNotifier => _updateNotifier; // Akses notifier dari luar kelas

  /// Panggil ini ketika profil pengguna berhasil diperbarui
  void notifyProfileUpdated() { // Beri tahu seluruh pendengar bahwa profil baru saja berubah
    _updateNotifier.value = DateTime.now(); // Perbarui nilai agar pendengar ikut bereaksi
  }
}
