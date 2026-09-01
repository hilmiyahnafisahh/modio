import 'package:flutter/material.dart'; // Untuk Route, PageRouteBuilder, MaterialPageRoute, WidgetBuilder

import '../services/aksesibilitas_controller.dart'; // Pengelola pengaturan aksesibilitas

/// Pengganti `MaterialPageRoute` di seluruh aplikasi. Flutter tidak
/// otomatis mempercepat transisi halaman berdasarkan pengaturan
/// aksesibilitas sistem (`MediaQuery.disableAnimations` hanya dibaca
/// segelintir widget bawaan, bukan oleh `MaterialPageRoute`) — jadi
/// sakelar "Kurangi Animasi" hanya berarti sesuatu kalau setiap
/// pemanggilan rute memang memeriksa nilainya sendiri, seperti di sini.
Route<T> buatRute<T>(WidgetBuilder builder) { // Buat rute halaman, sadar pengaturan kurangi animasi
  if (AksesibilitasController.instance.kurangiAnimasi.value) { // Jika pengguna mengaktifkan kurangi animasi
    return PageRouteBuilder<T>( // Rute tanpa animasi transisi
      pageBuilder: (context, _, _) => builder(context), // Bangun halaman tanpa efek transisi
      transitionDuration: Duration.zero, // Tidak ada durasi transisi maju
      reverseTransitionDuration: Duration.zero, // Tidak ada durasi transisi mundur
    );
  }
  return MaterialPageRoute<T>(builder: builder); // Rute standar dengan animasi transisi biasa
}
