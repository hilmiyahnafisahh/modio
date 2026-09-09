package com.example.modio

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, bukan FlutterActivity — plugin local_auth
// menampilkan BiometricPrompt lewat FragmentManager, yang cuma
// tersedia di keturunan FragmentActivity. Tanpa ini "Autentikasi
// Biometrik" di layar kunci akan gagal/crash saat dipanggil.
class MainActivity : FlutterFragmentActivity()
