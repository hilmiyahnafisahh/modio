# Backend Modio — Panduan Onboarding & Rencana Tugas

Dokumen ini untuk developer yang akan fokus di backend Modio. Isinya: kondisi backend sekarang, alur datanya, teknologi yang dipakai, masalah yang sudah diketahui, lalu daftar tugas bertahap yang bisa dikerjakan sambil belajar.

> Kondisi per 16 Oktober 2026, branch `nafisa`.

---

## 1. Gambaran singkat

**Modio** adalah aplikasi Flutter untuk pencatatan keuangan UMKM/organisasi kecil, dirancang supaya bisa dipakai pengguna tunanetra (TalkBack, input suara, getaran).

Prinsip arsitekturnya **offline-first**:

- **Semua data pengguna (transaksi, kategori, profil, PIN) disimpan di HP**, di SQLite lokal. Aplikasi tetap jalan penuh tanpa internet.
- **Backend saat ini hanya sebuah proxy AI** yang tipis: menerima teks ucapan pengguna, meneruskannya ke Google Gemini, lalu mengembalikan hasil berupa data transaksi terstruktur.
- Backend **belum** menyimpan data apa pun. Belum ada database, akun, atau sinkronisasi di server.

Kenapa proxy ini dibuat: API key Gemini tidak boleh ditanam di APK, karena siapa pun bisa membongkar APK dan mencurinya. Jadi key disimpan di server, dan aplikasi hanya bicara ke server.

---

## 2. Teknologi yang dipakai

| Bagian | Teknologi | Lokasi |
|---|---|---|
| Bahasa | Python 3.12 | — |
| Framework web | FastAPI 0.115 | [backend/main.py](../../backend/main.py) |
| Server ASGI | Uvicorn 0.34 | — |
| HTTP client ke Gemini | httpx 0.28 (async) | — |
| Konfigurasi | python-dotenv, file `.env` | [backend/.env.example](../../backend/.env.example) |
| Validasi request/response | Pydantic (bawaan FastAPI) | — |
| Model AI | Google Gemini `gemini-3.5-flash-lite` lewat REST `generateContent` | `GEMINI_MODEL` di main.py |
| Container | Docker (`python:3.12-slim`) + docker-compose | [backend/Dockerfile](../../backend/Dockerfile), [backend/docker-compose.yml](../../backend/docker-compose.yml) |
| Hosting | `https://modio-api.stas-rg.com` (di belakang Cloudflare + nginx) | [lib/core/constants/api_constants.dart](../../lib/core/constants/api_constants.dart) |

Sisi aplikasi (perlu dipahami karena ini klien backend):

| Bagian | Teknologi | Lokasi |
|---|---|---|
| Klien HTTP | package `http` | [lib/core/services/api_service.dart](../../lib/core/services/api_service.dart) |
| Daftar endpoint | konstanta | [lib/core/constants/api_constants.dart](../../lib/core/constants/api_constants.dart) |
| Pemanggil AI parsing | `AiParserService` | [lib/core/services/ai_parser_service.dart](../../lib/core/services/ai_parser_service.dart) |
| Database lokal | `sqflite` (SQLite) | [lib/core/database/database_helper.dart](../../lib/core/database/database_helper.dart) |
| Akses data transaksi | `TransaksiRepository` | [lib/features/transactions/data/transaksi_repository.dart](../../lib/features/transactions/data/transaksi_repository.dart) |

---

## 3. Alur kerja saat ini

### 3.1 Alur pencatatan transaksi lewat suara (satu-satunya fitur yang memakai backend)

```
Pengguna bicara: "tadi jual kerupuk lima belas ribu, bayar pakai QRIS"
        │
        ▼
[HP] speech_to_text  ──►  teks ucapan
        │
        ▼
[HP] AiParserService.uraikanTransaksi()
     POST {baseUrl}/v1/ai/parse-transaction
     body: { teks, kategori_masuk[], kategori_keluar[] }
        │
        ▼
[Server] FastAPI main.py
     1. cek GEMINI_API_KEY ada
     2. susun prompt = SYSTEM_PROMPT + daftar kategori + ucapan
     3. panggil Gemini dengan responseSchema (JSON terstruktur)
     4. ambil candidates[0].content.parts[0].text → json.loads
     5. kembalikan ParseTransaksiResponse
        │
        ▼
[HP] hasil: { nominal: 15000, jenis: "masuk", kategori: "Penjualan",
             metode: "non tunai", catatan: "Jual kerupuk" }
        │
        ├─ kategori belum ada di daftar → otomatis ditambahkan ke SQLite
        ├─ ada isian kosong → app bertanya balik lewat suara + snackbar
        ▼
[HP] form peninjauan → pengguna konfirmasi → disimpan ke SQLite lokal
```

Poin penting:

- **AI hanya menebak, pengguna yang memutuskan.** Hasil AI selalu masuk ke form peninjauan dulu, tidak langsung disimpan.
- **Kalau backend gagal** (timeout, error 5xx, dsb.), aplikasi tidak berhenti. Ucapan dimasukkan sebagai `catatan` saja dan pengguna mengisi sisanya manual. Lihat [voice_transaction_flow.dart](../../lib/features/transactions/presentation/widgets/voice_transaction_flow.dart).
- Daftar kategori dikirim dari HP di setiap request, karena kategori milik pengguna hanya ada di HP.

### 3.2 Kontrak API yang sudah ada

#### `POST /v1/ai/parse-transaction`

Request:

```json
{
  "teks": "beli gula sepuluh ribu tunai",
  "kategori_masuk": ["Penjualan", "Jasa", "Donasi"],
  "kategori_keluar": ["Bahan Baku", "Transportasi", "Gaji"]
}
```

Response `200`:

```json
{
  "nominal": 10000,
  "jenis": "keluar",
  "kategori": "Bahan Baku",
  "metode": "tunai",
  "catatan": "Beli gula"
}
```

| Field | Tipe | Nilai |
|---|---|---|
| `nominal` | int / null | Rupiah utuh, tanpa desimal |
| `jenis` | string / null | `"masuk"` atau `"keluar"` |
| `kategori` | string / null | Nama persis dari daftar, **atau nama kategori baru** (1–3 kata) bila tidak ada yang cocok |
| `metode` | string / null | `"tunai"` atau `"non tunai"` |
| `catatan` | string | Ringkasan singkat, selalu ada |

Error:

| Kode | Arti |
|---|---|
| `422` | Body tidak sesuai skema (otomatis dari FastAPI) |
| `500` | `GEMINI_API_KEY` belum diisi |
| `502` | Gemini tidak bisa dihubungi, membalas error, atau formatnya tak terduga |

#### `GET /health`

```json
{ "ok": true, "key_configured": true }
```

Dipakai untuk mengecek server hidup dan key sudah terpasang.

Dokumentasi interaktif otomatis dari FastAPI tersedia di `http://localhost:8000/docs` saat server jalan.

### 3.3 Data di sisi HP (perlu dipahami untuk fitur sinkronisasi nanti)

Skema SQLite versi 2, di [database_helper.dart](../../lib/core/database/database_helper.dart):

**Tabel `transaksi`**

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | TEXT PK | **ULID** dibuat di HP ([ulid.dart](../../lib/core/utils/ulid.dart)), jadi aman dipakai sebagai id global di server |
| `title` | TEXT | |
| `nominal` | INTEGER > 0 | **Rupiah utuh. Jangan pernah pakai float untuk uang.** |
| `method` | TEXT | tunai / non tunai |
| `kategori` | TEXT | default `'Lainnya'` |
| `type` | TEXT | `'masuk'` / `'keluar'` |
| `catatan` | TEXT | opsional |
| `sumber_input` | TEXT | `'manual'` / suara |
| `occurred_at`, `created_at`, `updated_at` | TEXT | **ISO 8601 UTC** |
| `deleted_at` | TEXT | soft delete, data tidak benar-benar dihapus |
| `sync_status` | TEXT | `pending` / `syncing` / `synced` / `failed`, **sudah disiapkan untuk sinkronisasi** tapi belum dipakai |

**Tabel `kategori`**: `id`, `nama`, `type`, unik per (`nama`, `type`). 14 kategori bawaan.

**Tabel `pengaturan`**: key-value untuk saldo awal, profil, hash PIN (SHA-256 + salt), status biometrik.

Aturan yang sudah dipegang di HP dan **wajib dipegang juga di server**: uang integer, waktu UTC, soft delete, id dari HP (ULID).

---

## 4. Rencana yang sudah tersirat di kode

[api_constants.dart](../../lib/core/constants/api_constants.dart) sudah mendaftarkan endpoint yang **belum ada di backend**:

| Endpoint di app | Status di backend | Kebutuhan fitur |
|---|---|---|
| `/v1/ai/parse-transaction` | ✅ ada | Input suara |
| `/ai/chat` | ❌ belum | Halaman Asisten AI, **saat ini balasannya dummy** ([ai_assistant_page.dart](../../lib/features/ai_chat/presentation/pages/ai_assistant_page.dart)) |
| `/v1/ai/analysis` | ✅ ada (19 Okt 2026) | Saran AI untuk laporan bulanan, tanpa angka. Badge anomali transaksi belum |
| `/transactions`, `/transactions/:id` | ❌ belum | Backup/sinkronisasi transaksi |
| `/reports`, `/reports/summary` | ❌ belum | Laporan dari server (opsional, laporan sudah dihitung di HP) |
| `/auth/login`, `/auth/logout` | ❌ belum | Akun pengguna, prasyarat sinkronisasi |

Catatan: path-nya belum konsisten. Hanya parse-transaction yang memakai awalan `/v1`. Sebaiknya semua endpoint baru memakai `/v1/...`, dan konstanta di app ikut disesuaikan.

---

## 5. Masalah yang sudah diketahui

Urut dari yang paling mendesak:

1. **Server produksi sedang tidak bisa dipakai: redirect loop.**
   `https://modio-api.stas-rg.com/health` membalas `301` dengan `Location` ke URL yang sama persis (dicek 16 Okt 2026). Pola ini biasanya terjadi karena Cloudflare SSL mode **Flexible** (Cloudflare ke origin lewat HTTP) sementara nginx di origin memaksa redirect HTTP→HTTPS. Selain itu, package `http` di Flutter tidak mengikuti redirect untuk POST, jadi input suara di HP pasti gagal dan jatuh ke mode manual.
   Perbaikan yang umum: ubah SSL mode Cloudflare ke **Full / Full (strict)**, atau hapus redirect paksa di nginx.
2. **Endpoint terbuka tanpa proteksi.** Siapa pun yang tahu URL-nya bisa memakai kuota Gemini kita. Belum ada API key aplikasi, rate limit, atau batas panjang `teks`.
3. **Pesan error membocorkan detail internal.** Respons `502` menyertakan isi mentah error dari Gemini ke klien.
4. **Belum ada test, logging, atau CI** untuk backend.
5. **Konfigurasi hardcode.** Nama model dan timeout Gemini ditulis langsung di kode, bukan dari env.
6. **Validasi output AI masih longgar.** `jenis`/`metode` dipercaya apa adanya dari Gemini. Kalau Gemini membalas nilai di luar `masuk/keluar` atau `tunai/non tunai`, nilai itu diteruskan ke app.
7. Komentar di `TransaksiRepository` masih menyebut "mode usaha/organisasi", padahal kolom mode sudah dihapus di skema v2. Ini urusan Flutter, cukup diketahui saja.

---

## 6. Cara menjalankan di lokal

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate   |   Linux/Mac: source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env        # lalu isi GEMINI_API_KEY (minta ke tim / buat di Google AI Studio)
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Atau dengan Docker:

```bash
cd backend
docker compose up --build
```

Uji cepat:

```bash
curl http://localhost:8000/health

curl -X POST http://localhost:8000/v1/ai/parse-transaction \
  -H "Content-Type: application/json" \
  -d '{"teks":"beli gula sepuluh ribu tunai","kategori_masuk":["Penjualan"],"kategori_keluar":["Bahan Baku"]}'
```

Supaya HP bisa memakai backend lokal: ganti `baseUrl` di [api_constants.dart](../../lib/core/constants/api_constants.dart) ke IP LAN laptop (mis. `http://192.168.x.x:8000`), dan HP harus satu WiFi dengan laptop. **Jangan commit perubahan ini.**

**Jangan pernah commit file `.env`** (sudah ada di `.gitignore`).

---

## 7. Daftar tugas bertahap

Setiap tugas punya tujuan belajar dan kriteria selesai. Kerjakan berurutan per fase. Di dalam satu fase urutannya boleh fleksibel.

### Fase 0: Kenalan (± 2–3 hari)

| # | Tugas | Kriteria selesai |
|---|---|---|
| 0.1 | Baca dokumen ini, [main.py](../../backend/main.py), [api_service.dart](../../lib/core/services/api_service.dart), [ai_parser_service.dart](../../lib/core/services/ai_parser_service.dart), dan [voice_transaction_flow.dart](../../lib/features/transactions/presentation/widgets/voice_transaction_flow.dart) | Bisa menjelaskan ulang alur 3.1 dengan kata-kata sendiri |
| 0.2 | Jalankan backend di lokal (venv **dan** Docker) | `/health` dan parse-transaction berhasil dari curl dan dari `/docs` |
| 0.3 | Sambungkan app di HP ke backend lokal, catat 1 transaksi lewat suara | Form terisi otomatis dari hasil AI |
| 0.4 | Coba 15–20 variasi ucapan (angka dieja, "rb", "jt", tanpa nominal, kategori baru, metode tidak disebut) dan catat hasilnya | Ada tabel ucapan → hasil → benar/salah, dipakai sebagai bahan test di Fase 1 |

Materi belajar yang relevan: tutorial resmi FastAPI (bagian *First Steps*, *Request Body*, *Handling Errors*, *Testing*), dasar async/await Python, dokumentasi Gemini API bagian *structured output / responseSchema*.

### Fase 1: Stabilkan yang sudah ada (± 1–2 minggu)

| # | Tugas | Kriteria selesai |
|---|---|---|
| 1.1 | **Perbaiki redirect loop server produksi** (lihat masalah #1) | `curl https://modio-api.stas-rg.com/health` membalas `200` JSON, input suara di HP jalan dengan URL produksi |
| 1.2 | Rapikan struktur folder: pisahkan `main.py` jadi `app/main.py`, `app/routers/ai.py`, `app/schemas.py`, `app/services/gemini.py`, `app/config.py` | Perilaku dan kontrak API tidak berubah, Dockerfile ikut disesuaikan |
| 1.3 | Pindahkan konfigurasi ke env (`GEMINI_MODEL`, timeout, dll.) memakai `pydantic-settings` | Tidak ada nilai konfigurasi hardcode, `.env.example` diperbarui |
| 1.4 | Tambah test dengan `pytest` + `TestClient`, panggilan Gemini di-mock (mis. `respx`) | Test mencakup sukses, key kosong, Gemini timeout, Gemini balas JSON rusak, body tidak valid |
| 1.5 | Perketat validasi: `jenis` dan `metode` jadi `Literal[...]`, nilai di luar itu diubah ke `null`; batasi panjang `teks` (mis. maks 500 karakter) dan jumlah kategori | Ada test untuk nilai aneh dari Gemini |
| 1.6 | Sembunyikan detail error internal dari klien: tulis detailnya ke log, klien cukup menerima pesan umum | Respons 502 tidak lagi memuat isi mentah Gemini |
| 1.7 | Logging terstruktur (waktu proses, status, tanpa mencatat isi ucapan secara utuh karena ini data keuangan pribadi) | Log terbaca di `docker compose logs` |
| 1.8 | Tulis `backend/README.md` singkat (cara jalan, env, test, deploy) | Orang baru bisa menjalankan backend tanpa bertanya |

### Fase 2: Keamanan & operasional (± 1 minggu)

| # | Tugas | Kriteria selesai |
|---|---|---|
| 2.1 | Proteksi endpoint dengan header `X-App-Key` sederhana (key app di env server, dikirim dari app) | Request tanpa key ditolak `401`. Ini bukan keamanan sempurna (key ada di APK), tapi menahan penyalahgunaan iseng |
| 2.2 | Rate limit per IP (mis. `slowapi`) | Melebihi batas → `429`, app menampilkan pesan yang ramah dan dibacakan |
| 2.3 | CI GitHub Actions: lint (`ruff`) + `pytest` setiap push ke folder `backend/` | Badge/centang hijau di PR |
| 2.4 | Dokumentasikan cara deploy ke server `stas-rg.com` (siapa yang punya akses, cara update container, cara ganti key) | Ada bagian *Deploy* di `backend/README.md` |
| 2.5 | Cek kesehatan otomatis (uptime monitor ke `/health`) | Tim dapat notifikasi kalau server mati |

### Fase 3: Fitur AI baru (± 2–3 minggu)

Fitur ini menggantikan bagian yang masih dummy di app. Datanya tetap dari HP: app mengirim ringkasan atau daftar transaksi yang relevan dalam body request, dan server tidak menyimpan apa pun. Dengan begitu fitur ini tidak bergantung pada sinkronisasi.

| # | Tugas | Kriteria selesai |
|---|---|---|
| 3.1 | Rancang kontrak `POST /v1/ai/chat`: input berisi pertanyaan + konteks ringkas (saldo, total masuk/keluar, beberapa transaksi terakhir), output berupa teks jawaban pendek | Kontrak disepakati dengan dev Flutter **sebelum** ngoding, ditulis di dokumen ini |
| 3.2 | Implementasi `/v1/ai/chat` + system prompt khusus: Bahasa Indonesia sederhana, jawaban pendek karena akan dibacakan TalkBack, tidak mengarang angka di luar konteks yang diberikan | Test + contoh percakapan nyata |
| 3.3 | `POST /v1/ai/analysis`: insight laporan periode (mis. "pengeluaran bahan baku naik 30% dari bulan lalu") | Output terstruktur (judul + deskripsi) sesuai `AiInsightWidget` |
| 3.4 | Deteksi anomali transaksi (nominal jauh di atas kebiasaan kategori). Pertimbangkan dulu: aturan statistik sederhana bisa jalan di HP tanpa AI. Diskusikan dulu dengan tim | Keputusan tertulis: di HP atau di server, beserta alasannya |
| 3.5 | Bantu dev Flutter menyambungkan halaman Asisten AI ke endpoint baru | Balasan dummy di `ai_assistant_page.dart` hilang |

### Fase 4: Akun & sinkronisasi (jangka panjang, perlu keputusan tim dulu)

Ini perubahan besar: backend berubah dari proxy tanpa data menjadi server yang **menyimpan data keuangan pengguna**. Sebelum mulai, putuskan bersama tim apakah fitur ini memang dibutuhkan (backup, pindah HP, multi-perangkat) dan bagaimana privasi datanya.

| # | Tugas | Kriteria selesai |
|---|---|---|
| 4.1 | Dokumen desain: pilihan DB (saran: PostgreSQL + SQLAlchemy/SQLModel + Alembic untuk migrasi), model auth, strategi sinkronisasi | Desain disetujui tim |
| 4.2 | Auth: registrasi/login (nomor HP + OTP atau email), token JWT. PIN tetap lokal di HP dan **tidak** dikirim ke server | Endpoint `/v1/auth/*` + test |
| 4.3 | Skema server meniru aturan di HP: id ULID dari HP, nominal BIGINT, waktu `timestamptz` UTC, soft delete, `updated_at` | Migrasi Alembic pertama |
| 4.4 | Endpoint sinkronisasi: `POST /v1/sync/push` (kirim transaksi `sync_status = pending`) dan `GET /v1/sync/pull?since=...` (ambil perubahan sejak waktu tertentu). Konflik diselesaikan dengan aturan *last-write-wins* berdasarkan `updated_at` | Push/pull idempoten (kirim ulang data yang sama tidak membuat duplikat) |
| 4.5 | Sisi app: worker sinkronisasi di `TransaksiRepository` (satu-satunya pintu ke DB, sesuai komentar di file itu) | Transaksi offline tersinkron saat online kembali |

---

## 8. Kebiasaan kerja yang disarankan

- **Kontrak API dulu, kode belakangan.** Setiap endpoint baru ditulis contoh request/response-nya di dokumen ini dan disepakati dengan dev Flutter.
- **Jangan ubah kontrak yang sudah dipakai app** tanpa versi baru. App yang sudah terpasang di HP pengguna tidak ikut ter-update otomatis.
- **Ingat penggunanya.** Pesan error dan jawaban AI akan dibacakan screen reader, jadi harus singkat, jelas, dan berbahasa Indonesia.
- **Data keuangan adalah data sensitif.** Jangan log isi transaksi atau ucapan secara utuh, dan jangan commit `.env` atau key.
- Kerjakan di branch sendiri, buat PR ke `main`, dan pastikan test lulus.
