import 'package:flutter/material.dart';

import '../services/aksesibilitas_controller.dart';

/// Pengganti `MaterialPageRoute` di seluruh aplikasi. Flutter tidak
/// otomatis mempercepat transisi halaman berdasarkan pengaturan
/// aksesibilitas sistem (`MediaQuery.disableAnimations` hanya dibaca
/// segelintir widget bawaan, bukan oleh `MaterialPageRoute`) — jadi
/// sakelar "Kurangi Animasi" hanya berarti sesuatu kalau setiap
/// pemanggilan rute memang memeriksa nilainya sendiri, seperti di sini.
Route<T> buatRute<T>(WidgetBuilder builder) {
  if (AksesibilitasController.instance.kurangiAnimasi.value) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, _, _) => builder(context),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
  return MaterialPageRoute<T>(builder: builder);
}
