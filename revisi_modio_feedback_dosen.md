# Revisi Modio — Feedback Dosen

## Tujuan
Melakukan revisi pada desain dan interaksi aplikasi **Modio** agar lebih sederhana, konsisten, dan mudah digunakan oleh pengguna tunanetra, khususnya pengguna yang menggunakan screen reader seperti TalkBack.

---

## 1. Minimum Option / Pilihan Periode Transaksi

### Feedback Dosen
Minimum option perlu difokuskan pada kebutuhan **daily use**, tetapi pengguna tetap harus dapat mengetahui dan mengakses transaksi yang sudah lama.

### Revisi
Gunakan pilihan periode yang sederhana:

- **Daily / Hari Ini**
  - Untuk melihat transaksi pada hari berjalan.
  - Menjadi pilihan utama untuk kebutuhan penggunaan sehari-hari.

- **Yearly / Tahun Ini**
  - Untuk melihat transaksi dalam periode satu tahun.
  - Dapat digunakan untuk melihat rekap atau transaksi selama tahun berjalan.

- **History / Riwayat Transaksi**
  - Untuk mengakses transaksi yang lebih lama, termasuk transaksi yang sudah lebih dari satu tahun.
  - Pengguna tidak perlu menampilkan seluruh transaksi lama secara langsung.

### Catatan Implementasi
Jangan membatasi penyimpanan transaksi hanya satu tahun. **Semua transaksi tetap disimpan**, sedangkan pilihan Daily dan Yearly digunakan sebagai filter/tampilan.

Pada menu History, sediakan mekanisme pencarian atau filter berdasarkan:
- tanggal/periode;
- transaksi tertentu;
- atau informasi relevan lainnya.

### Prinsip UX
Hindari terlalu banyak pilihan periode seperti:
- 1 minggu;
- 1 bulan;
- 3 bulan;
- 6 bulan;
- 1 tahun;
- dan sebagainya.

Terlalu banyak pilihan dapat membuat navigasi lebih panjang dan membingungkan pengguna screen reader.

Struktur yang disarankan:

**Transaksi**
→ Hari Ini  
→ Tahun Ini  
→ Riwayat Transaksi

---

## 2. Getaran / Haptic Feedback

### Feedback Dosen
Penggunaan getaran perlu diperhatikan dan diperjelas, terutama ketika pengguna melakukan interaksi tertentu seperti scrolling atau berpindah ke kotak/input yang perlu diisi.

### Revisi
Tambahkan haptic feedback pada interaksi penting.

Contoh:
- Saat pengguna melakukan **scroll/swipe** dan berpindah ke elemen atau bagian informasi baru.
- Saat fokus berpindah ke **input field/kotak yang perlu diisi**.
- Saat pengguna memilih elemen.
- Saat pengguna berpindah antar bagian penting pada halaman.
- Saat terjadi keberhasilan atau kesalahan dalam suatu tindakan.

### Catatan
Getaran tidak perlu diberikan pada setiap interaksi secara berlebihan. Gunakan hanya pada momen yang membantu pengguna memahami perubahan fokus, status, atau hasil tindakan.

---

## 3. Vibration untuk Correct dan Incorrect

### Feedback Dosen
Perlu dibedakan getaran ketika input atau tindakan pengguna **correct** dan **incorrect**.

### Revisi
Buat pola getaran yang konsisten:

- **Correct / Berhasil**
  - Gunakan pola getaran yang singkat dan mudah dikenali.
  - Contoh: 1 getaran pendek.

- **Incorrect / Salah**
  - Gunakan pola yang berbeda dari correct.
  - Contoh: 2 getaran pendek atau pola getaran yang lebih panjang.

### Catatan Implementasi
Pola getaran harus konsisten di seluruh aplikasi.

Contoh penggunaan:
- Input angka benar → vibration correct.
- Input tidak valid → vibration incorrect.
- Transaksi berhasil disimpan → vibration correct.
- Proses gagal → vibration incorrect.

Haptic feedback sebaiknya digunakan sebagai **pelengkap**, bukan satu-satunya informasi. Status tetap perlu disampaikan melalui audio/screen reader.

---

## 4. Hierarki Layout

### Feedback Dosen
Hierarki layout perlu diperjelas.

### Revisi
Tentukan hierarki visual dan hierarki navigasi pada setiap halaman.

Prioritas elemen:
1. **Judul halaman**
2. **Informasi utama**
3. **Input/data yang perlu diisi**
4. **Informasi tambahan**
5. **Tombol aksi**

Untuk pengguna TalkBack, pastikan urutan fokus/navigasi mengikuti alur informasi yang logis.

### Contoh
Pada halaman tambah transaksi:

**Judul: Tambah Transaksi**  
→ Jenis transaksi  
→ Nominal  
→ Kategori  
→ Keterangan  
→ Tombol Simpan

Jangan membuat pengguna berpindah secara acak antara elemen yang tidak berhubungan.

---

## 5. Gesture Interaction

### Feedback Dosen
Gesture interaction seperti scroll, tap satu kali, double tap, dan gesture lainnya perlu diperjelas.

### Revisi
Dokumentasikan gesture yang digunakan pada aplikasi dan fungsi masing-masing.

| Gesture | Fungsi |
|---|---|
| Tap 1× | Memindahkan fokus atau memilih elemen |
| Double Tap | Menjalankan/mengaktifkan elemen yang sedang difokuskan oleh TalkBack |
| Swipe/Scroll | Berpindah ke elemen atau informasi berikutnya |
| Long Press | Digunakan hanya jika terdapat fungsi yang memang membutuhkan tekan lama |

### Catatan Penting untuk TalkBack
Interaksi harus mengikuti pola interaksi screen reader.

Ketika TalkBack aktif:
- pengguna melakukan swipe untuk berpindah fokus;
- TalkBack membacakan elemen yang sedang difokuskan;
- pengguna melakukan double tap untuk menjalankan elemen yang sedang dipilih.

Jangan membuat gesture custom yang bertentangan dengan gesture standar TalkBack kecuali benar-benar diperlukan.

---

## 6. Prinsip Umum Revisi

Implementasi revisi harus mengikuti prinsip:

- **Simple** — jumlah pilihan tidak berlebihan.
- **Consistent** — gesture, audio, dan vibration memiliki pola yang konsisten.
- **Accessible** — seluruh fungsi dapat digunakan tanpa bergantung pada penglihatan.
- **Predictable** — pengguna dapat mengetahui apa yang terjadi setelah melakukan tindakan.
- **Efficient** — pengguna tidak perlu melakukan terlalu banyak swipe/tap untuk menyelesaikan tugas.
- **Non-visual feedback** — gunakan kombinasi screen reader/audio dan haptic feedback.

---

## 7. Acceptance Criteria

### Periode Transaksi
- [ ] Tersedia pilihan Daily/Hari Ini.
- [ ] Tersedia pilihan Yearly/Tahun Ini.
- [ ] Tersedia menu History/Riwayat untuk transaksi lama.
- [ ] Transaksi lebih dari satu tahun tetap tersimpan dan dapat diakses.
- [ ] History memiliki mekanisme pencarian/filter yang tidak mengharuskan pengguna melakukan scroll panjang.

### Haptic Feedback
- [ ] Terdapat feedback getaran pada interaksi penting.
- [ ] Terdapat feedback ketika fokus berpindah ke input penting.
- [ ] Terdapat feedback pada kondisi correct.
- [ ] Terdapat feedback berbeda pada kondisi incorrect.
- [ ] Pola vibration konsisten di seluruh aplikasi.

### Layout & Navigasi
- [ ] Hierarki layout setiap halaman jelas.
- [ ] Urutan fokus TalkBack mengikuti alur informasi.
- [ ] Tidak terdapat elemen yang sulit ditemukan saat navigasi menggunakan screen reader.

### Gesture
- [ ] Fungsi setiap gesture terdokumentasi.
- [ ] Tap, double tap, swipe/scroll, dan long press memiliki fungsi yang jelas.
- [ ] Interaksi tidak bertentangan dengan pola standar TalkBack.
- [ ] Pengguna memperoleh feedback setelah melakukan tindakan penting.

---

## Ringkasan Perubahan

**Sebelum:**
Pilihan dan interaksi berpotensi terlalu banyak sehingga pengguna perlu melakukan navigasi yang panjang.

**Sesudah:**
Modio menggunakan pendekatan sederhana:

**Daily → kebutuhan sehari-hari**  
**Yearly → melihat transaksi/rekap satu tahun**  
**History → mencari transaksi lama**

Ditambah:
**Haptic Feedback + Audio/Screen Reader + Hierarki Layout + Gesture yang jelas**

Tujuannya adalah membuat interaksi Modio lebih **sederhana, konsisten, efisien, dan aksesibel bagi pengguna tunanetra**.
