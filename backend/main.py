"""
Proxy lokal antara app Modio dan Gemini API.

Kenapa proxy ini ada: API key Gemini tidak boleh ditaruh di dalam app
Flutter (siapa pun bisa membongkar APK dan mencurinya). Proxy ini yang
memegang key, app hanya bicara ke server ini.

Cara jalankan:
    pip install -r requirements.txt
    isi GEMINI_API_KEY di file .env (lihat .env.example)
    uvicorn main:app --host 0.0.0.0 --port 8000
"""

import json
import os
import re
from typing import Literal

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = "gemini-3.5-flash-lite"
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent"
)

app = FastAPI(title="Modio AI Proxy")


class ParseTransaksiRequest(BaseModel):
    teks: str
    kategori_masuk: list[str]
    kategori_keluar: list[str]


class ParseTransaksiResponse(BaseModel):
    nominal: int | None
    jenis: str | None  # "masuk" atau "keluar"
    kategori: str | None
    metode: str | None  # "tunai" atau "non tunai"
    catatan: str


SYSTEM_PROMPT = """Kamu mengurai ucapan pemilik usaha kecil (UMKM) Indonesia
tentang satu transaksi keuangan menjadi data terstruktur.

Dari teks yang diberikan, tentukan:
- nominal: jumlah uang dalam rupiah, sebagai angka utuh tanpa titik/koma
  (contoh: "lima belas ribu" -> 15000, "dua ratus lima puluh rb" -> 250000).
  null jika benar-benar tidak disebutkan.
- jenis: "masuk" (pemasukan) atau "keluar" (beban/pengeluaran), menurut
  KRITERIA JENIS di bawah. null hanya jika arahnya benar-benar tidak
  bisa ditentukan.
- kategori: cari kategori yang paling cocok dari daftar kategori untuk
  jenis yang kamu tentukan di atas (kategori_masuk jika jenis masuk,
  kategori_keluar jika jenis keluar), dengan bantuan PANDUAN KATEGORI di
  bawah. Jika salah satu kategori di daftar cocok, walaupun hanya secara
  umum, PILIH PERSIS nama itu apa adanya (jangan ubah ejaan/
  kapitalisasinya). Buat kategori baru HANYA jika tidak ada satu pun
  kategori di daftar yang cocok, tapi ucapan cukup jelas menyebutkan
  jenis barang/aktivitasnya (mis. "bayar pajak", "jual kerajinan
  tangan"): beri nama singkat (satu sampai tiga kata, format judul, mis.
  "Pajak", "Kerajinan Tangan") — kategori baru ini akan otomatis
  ditambahkan ke daftar kategori pengguna. null hanya jika jenis
  transaksinya sendiri tidak jelas, atau ucapan sama sekali tidak
  memberi info soal kategori apa pun.
- metode: "tunai" jika ucapan menyebut uang tunai/cash/kontan, atau
  "non tunai" jika menyebut transfer, QRIS, kartu debit/kredit, e-wallet
  (mis. OVO, GoPay, Dana), atau metode nontunai lain. null jika metode
  pembayaran sama sekali tidak disebutkan dalam ucapan.
- catatan: ringkasan singkat barang/aktivitasnya (bukan nominal, bukan
  kategori), dalam Bahasa Indonesia natural, maksimal satu kalimat pendek.

KRITERIA JENIS
Tentukan dari arah uangnya, dilihat dari sisi pengguna (usaha/organisasi):
- "keluar" (beban) jika uang PERGI dari pengguna ke pihak lain, misalnya:
  beli, belanja, kulakan, bayar, lunasi, cicil, setor ke, transfer ke,
  kirim uang ke, kasih/beri (upah, THR, sumbangan), traktir, isi (bensin,
  token, pulsa, saldo), servis, perbaiki, langganan, ongkir, biaya,
  "keluar uang", "habis", "kepakai buat".
- "masuk" jika uang DATANG ke pengguna, misalnya: jual, laku, terjual,
  laris, dapat, terima, dibayar, pelanggan/pembeli bayar, transferan
  masuk, dikasih, dapat sumbangan, iuran dari anggota, tambah modal.
- Kata yang bisa dua arah, lihat SIAPA yang membayar:
  - "bayar": pengguna yang bayar -> keluar; pembeli/pelanggan/anggota
    yang bayar ke pengguna -> masuk.
  - "transfer": "transfer ke ..." -> keluar; "transfer dari ...",
    "dapat transferan" -> masuk.
  - "sewa": pengguna menyewa barang/tempat -> keluar; orang lain menyewa
    barang milik pengguna ("ada yang sewa ...", "menyewakan") -> masuk.
  - "iuran"/"sumbangan"/"donasi": diterima dari orang lain -> masuk;
    diberikan pengguna ke pihak lain -> keluar.
- Jika tidak ada kata kerja, tapi barang/aktivitasnya jelas BIAYA
  operasional yang tidak mungkin dijual pengguna (listrik, air, gas,
  bensin, parkir, tol, ongkir, gaji, upah, honor, THR, sewa tempat,
  kontrakan, pulsa, internet, wifi, pajak, servis, kemasan) -> keluar.
- Jika tidak ada kata kerja dan barangnya bisa dibeli maupun dijual
  (mis. "kerupuk lima belas ribu"), jenis = null supaya pengguna ditanya.

PANDUAN KATEGORI
Hanya berlaku bila nama kategori itu ADA di daftar yang diberikan.
Kategori keluar (beban):
- Bahan Baku: bahan yang diolah atau barang dagangan yang dijual lagi
  (tepung, gula, minyak, sayur, daging, telur, bumbu, kain, stok,
  kulakan, bayar ke pemasok/supplier), termasuk kemasan (plastik,
  kardus, stiker, selotip, gelas plastik).
- Transportasi: bensin, solar, parkir, tol, ongkir, ojek/gojek/grab,
  angkot, servis atau ganti oli kendaraan.
- Gaji: gaji, upah, honor, THR, bonus, lembur, bayar tukang/pekerja.
- Sewa: kontrakan, sewa kios/lapak/tempat, sewa alat, tenda, sound.
- Listrik dan Air: listrik, token/PLN, air, PDAM.
- Peralatan: membeli, mencicil, atau memperbaiki alat kerja (kompor,
  blender, etalase, timbangan, mesin, kulkas).
- Kegiatan: biaya acara, rapat, atau kegiatan organisasi (konsumsi,
  dekorasi, hadiah lomba, spanduk acara).
- Pengeluaran Lain: hanya bila tidak ada kategori lain yang cocok DAN
  aktivitasnya terlalu umum untuk dibuatkan kategori baru.
Kategori masuk:
- Penjualan: hasil menjual barang/produk, termasuk pembeli yang bayar
  atau transferan dari pelanggan.
- Jasa: bayaran atas jasa atau tenaga (jahit, servis, potong rambut).
- Iuran Anggota: iuran/kas dari anggota.
- Donasi: sumbangan atau donasi yang diterima.
- Modal Masuk: tambahan modal atau pinjaman yang diterima.

Balas HANYA JSON sesuai skema, tanpa penjelasan tambahan."""


async def panggil_gemini(
    system_prompt: str, user_prompt: str, response_schema: dict
) -> dict:
    """Kirim satu prompt ke Gemini dan kembalikan balasan JSON-nya.

    Dipakai bersama oleh semua endpoint AI, supaya penanganan key
    kosong, koneksi gagal, dan format balasan aneh cukup ditulis sekali.
    """
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY belum diisi di backend/.env",
        )

    body = {
        "system_instruction": {"parts": [{"text": system_prompt}]},
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": response_schema,
        },
    }

    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            resp = await client.post(
                GEMINI_URL,
                headers={
                    "x-goog-api-key": GEMINI_API_KEY,
                    "Content-Type": "application/json",
                },
                json=body,
            )
        except httpx.RequestError as e:
            raise HTTPException(
                status_code=502, detail=f"Gagal menghubungi Gemini: {e}"
            )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Gemini error {resp.status_code}: {resp.text}",
        )

    data = resp.json()
    try:
        teks_json = data["candidates"][0]["content"]["parts"][0]["text"]
        hasil = json.loads(teks_json)
    except (KeyError, IndexError, json.JSONDecodeError) as e:
        raise HTTPException(
            status_code=502,
            detail=f"Format balasan Gemini tidak terduga: {e}",
        )
    return hasil


@app.post("/v1/ai/parse-transaction", response_model=ParseTransaksiResponse)
async def parse_transaction(req: ParseTransaksiRequest) -> ParseTransaksiResponse:
    user_prompt = (
        f"Daftar kategori_masuk: {', '.join(req.kategori_masuk)}\n"
        f"Daftar kategori_keluar: {', '.join(req.kategori_keluar)}\n"
        f'Ucapan pengguna: "{req.teks}"'
    )

    hasil = await panggil_gemini(
        SYSTEM_PROMPT,
        user_prompt,
        {
            "type": "OBJECT",
            "properties": {
                "nominal": {"type": "INTEGER", "nullable": True},
                "jenis": {"type": "STRING", "nullable": True},
                "kategori": {"type": "STRING", "nullable": True},
                "metode": {"type": "STRING", "nullable": True},
                "catatan": {"type": "STRING"},
            },
            "required": ["catatan"],
        },
    )

    return ParseTransaksiResponse(
        nominal=hasil.get("nominal"),
        jenis=hasil.get("jenis"),
        kategori=hasil.get("kategori"),
        metode=hasil.get("metode"),
        catatan=hasil.get("catatan", ""),
    )


# ── Analisis laporan ────────────────────────────────────────────────
#
# Angka laporan dihitung di HP dari basis data, bukan oleh AI. Pengguna
# tunanetra tidak bisa memeriksa ulang angka secara visual, jadi AI di
# sini hanya boleh memberi SARAN berupa kalimat tanpa angka. Saran yang
# tetap menyebut angka dibuang oleh _sebut_angka() sebelum dikirim.


class KategoriRingkas(BaseModel):
    nama: str = Field(max_length=60)
    total: int = Field(ge=0)
    jumlah_transaksi: int = Field(ge=0)


class AnalisisRequest(BaseModel):
    periode: str = Field(max_length=40)  # mis. "Oktober 2026"
    total_pendapatan: int = Field(ge=0)
    total_beban: int = Field(ge=0)
    jumlah_transaksi: int = Field(ge=0)
    pendapatan_bulan_lalu: int | None = Field(default=None, ge=0)
    beban_bulan_lalu: int | None = Field(default=None, ge=0)
    rincian_pendapatan: list[KategoriRingkas] = Field(max_length=50)
    rincian_beban: list[KategoriRingkas] = Field(max_length=50)


class AnalisisResponse(BaseModel):
    judul: str
    saran: list[str]
    nada: Literal["positif", "negatif", "netral"]


ANALISIS_PROMPT = """Kamu penasihat keuangan untuk pemilik usaha kecil
(UMKM) atau bendahara organisasi kecil di Indonesia. Penggunanya
termasuk tunanetra: jawabanmu akan DIBACAKAN oleh pembaca layar.

Dari ringkasan laporan satu bulan yang diberikan, tulis:
- judul: satu frasa pendek (maksimal enam kata) yang merangkum
  kondisi keuangan bulan itu.
- saran: dua sampai tiga saran praktis yang bisa langsung dilakukan.
  Tiap saran SATU kalimat pendek, Bahasa Indonesia sehari-hari, tanpa
  istilah akuntansi yang rumit.
- nada: "positif" bila laba dan kondisinya membaik, "negatif" bila rugi
  atau beban naik tajam, selain itu "netral".

ATURAN WAJIB:
- JANGAN menulis angka, nominal rupiah, persentase, atau jumlah apa
  pun, baik dengan digit maupun dieja (mis. "lima ribu", "tiga
  persen"). Angka resmi sudah dibacakan aplikasi; kamu cukup menyebut
  nama kategori dan arahnya (naik, turun, terbesar, terkecil).
- Hanya pakai fakta dari data yang diberikan. Jangan menebak penyebab
  yang tidak ada di data, dan jangan mengarang kategori.

Balas HANYA JSON sesuai skema, tanpa penjelasan tambahan."""


_POLA_ANGKA = re.compile(
    r"\d|%|\b(rp|rupiah|persen|ratus|puluh|belas|ribu|juta|miliar|triliun)\b",
    re.IGNORECASE,
)


def _sebut_angka(teks: str) -> bool:
    return bool(_POLA_ANGKA.search(teks))


def _arah(sekarang: int, lalu: int | None) -> str:
    if lalu is None:
        return "tidak ada data bulan lalu"
    if sekarang > lalu:
        return "naik dibanding bulan lalu"
    if sekarang < lalu:
        return "turun dibanding bulan lalu"
    return "sama dengan bulan lalu"


def _daftar_kategori(rincian: list[KategoriRingkas]) -> str:
    if not rincian:
        return "(tidak ada)"
    return "\n".join(
        f"  - {k.nama}: Rp{k.total}, {k.jumlah_transaksi} transaksi"
        for k in rincian
    )


@app.post("/v1/ai/analysis", response_model=AnalisisResponse)
async def analisis_laporan(req: AnalisisRequest) -> AnalisisResponse:
    # Laporan kosong tidak perlu dianalisis AI — hemat kuota dan waktu.
    if req.jumlah_transaksi == 0:
        return AnalisisResponse(
            judul="Belum ada transaksi",
            saran=[
                "Catat setiap uang masuk dan keluar supaya saran bisa diberikan."
            ],
            nada="netral",
        )

    laba = req.total_pendapatan - req.total_beban
    # Arah perubahan dihitung di sini, bukan diserahkan ke AI, supaya
    # AI tidak salah membandingkan angka.
    user_prompt = (
        f"Periode: {req.periode}\n"
        f"Jumlah transaksi: {req.jumlah_transaksi}\n"
        f"Total pendapatan: Rp{req.total_pendapatan} "
        f"({_arah(req.total_pendapatan, req.pendapatan_bulan_lalu)})\n"
        f"Total beban: Rp{req.total_beban} "
        f"({_arah(req.total_beban, req.beban_bulan_lalu)})\n"
        f"Kondisi: {'laba' if laba > 0 else 'rugi' if laba < 0 else 'impas'}\n"
        f"Rincian pendapatan per kategori (terbesar dulu):\n"
        f"{_daftar_kategori(req.rincian_pendapatan)}\n"
        f"Rincian beban per kategori (terbesar dulu):\n"
        f"{_daftar_kategori(req.rincian_beban)}"
    )

    hasil = await panggil_gemini(
        ANALISIS_PROMPT,
        user_prompt,
        {
            "type": "OBJECT",
            "properties": {
                "judul": {"type": "STRING"},
                "saran": {"type": "ARRAY", "items": {"type": "STRING"}},
                "nada": {
                    "type": "STRING",
                    "enum": ["positif", "negatif", "netral"],
                },
            },
            "required": ["judul", "saran", "nada"],
        },
    )

    saran = [
        s.strip()
        for s in hasil.get("saran", [])
        if isinstance(s, str) and s.strip() and not _sebut_angka(s)
    ][:3]
    if not saran:
        raise HTTPException(
            status_code=502,
            detail="AI tidak memberi saran yang bisa dipakai",
        )

    judul = str(hasil.get("judul", "")).strip()
    if not judul or _sebut_angka(judul):
        judul = "Saran keuangan bulan ini"

    nada = hasil.get("nada")
    if nada not in ("positif", "negatif", "netral"):
        nada = "netral"

    return AnalisisResponse(judul=judul, saran=saran, nada=nada)


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True, "key_configured": bool(GEMINI_API_KEY)}
