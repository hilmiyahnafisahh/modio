import 'package:flutter/foundation.dart';

/// Service untuk notifikasi saat profil pengguna diperbarui.
/// Digunakan untuk sync data profil ke seluruh app (dashboard, etc).
class ProfileUpdateService {
  static final ProfileUpdateService _instance = ProfileUpdateService._internal();

  factory ProfileUpdateService() {
    return _instance;
  }

  ProfileUpdateService._internal();

  final ValueNotifier<DateTime> _updateNotifier = ValueNotifier(DateTime.now());

  /// Notifier yang dapat didengarkan untuk mendeteksi perubahan profil
  ValueNotifier<DateTime> get updateNotifier => _updateNotifier;

  /// Panggil ini ketika profil pengguna berhasil diperbarui
  void notifyProfileUpdated() {
    _updateNotifier.value = DateTime.now();
  }
}
