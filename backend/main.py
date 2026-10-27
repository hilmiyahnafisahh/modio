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

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

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
- jenis: "masuk" jika ini uang yang diterima/didapat (mis. jualan, terima
  pembayaran, dapat pemasukan), "keluar" jika ini uang yang dikeluarkan/
  dibelanjakan (mis. beli, bayar, keluar biaya). null jika benar-benar
  tidak jelas arahnya.
- kategori: cari kategori yang paling cocok dari daftar kategori untuk
  jenis yang kamu tentukan di atas (kategori_masuk jika jenis masuk,
  kategori_keluar jika jenis keluar). Jika salah satu kategori di daftar
  itu jelas cocok dengan isi ucapan, PILIH PERSIS nama itu apa adanya
  (jangan ubah ejaan/kapitalisasinya). Jika TIDAK ADA kategori di daftar
  yang cocok, tapi ucapan cukup jelas menyebutkan jenis barang/
  aktivitasnya (mis. "bayar listrik", "jual kerajinan tangan"), buat
  nama kategori baru yang singkat (satu sampai tiga kata, format judul,
  mis. "Listrik", "Kerajinan Tangan") merangkum itu — kategori baru ini
  akan otomatis ditambahkan ke daftar kategori pengguna. null hanya jika
  jenis transaksinya sendiri tidak jelas, atau ucapan sama sekali tidak
  memberi info soal kategori apa pun.
- metode: "tunai" jika ucapan menyebut uang tunai/cash/kontan, atau
  "non tunai" jika menyebut transfer, QRIS, kartu debit/kredit, e-wallet
  (mis. OVO, GoPay, Dana), atau metode nontunai lain. null jika metode
  pembayaran sama sekali tidak disebutkan dalam ucapan.
- catatan: ringkasan singkat barang/aktivitasnya (bukan nominal, bukan
  kategori), dalam Bahasa Indonesia natural, maksimal satu kalimat pendek.

Balas HANYA JSON sesuai skema, tanpa penjelasan tambahan."""


@app.post("/v1/ai/parse-transaction", response_model=ParseTransaksiResponse)
async def parse_transaction(req: ParseTransaksiRequest) -> ParseTransaksiResponse:
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY belum diisi di backend/.env",
        )

    user_prompt = (
        f"Daftar kategori_masuk: {', '.join(req.kategori_masuk)}\n"
        f"Daftar kategori_keluar: {', '.join(req.kategori_keluar)}\n"
        f'Ucapan pengguna: "{req.teks}"'
    )

    body = {
        "system_instruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": {
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

    return ParseTransaksiResponse(
        nominal=hasil.get("nominal"),
        jenis=hasil.get("jenis"),
        kategori=hasil.get("kategori"),
        metode=hasil.get("metode"),
        catatan=hasil.get("catatan", ""),
    )


class RincianKategori(BaseModel):
    nama: str
    total: int
    jumlah_transaksi: int
    persen: int  # porsi terhadap total jenisnya, dihitung di app


class AnalisisLaporanRequest(BaseModel):
    periode: str  # mis. "Januari 2026"
    total_pendapatan: int
    total_beban: int
    laba_bersih: int
    jumlah_transaksi: int
    perubahan_pendapatan: int | None  # persen vs bulan lalu, null jika tak ada pembanding
    perubahan_beban: int | None
    rincian_pendapatan: list[RincianKategori]
    rincian_beban: list[RincianKategori]


class AnalisisLaporanResponse(BaseModel):
    analisis: str


ANALISIS_PROMPT = """Kamu asisten keuangan untuk pemilik usaha kecil (UMKM)
Indonesia yang memakai aplikasi Modio. Sebagian pengguna adalah tunanetra
dan mendengarkan jawabanmu lewat pembaca layar.

Dari laporan laba rugi satu bulan yang diberikan, tulis analisis singkat
dalam tiga bagian, masing-masing diawali judul pada barisnya sendiri:
Evaluasi laba rugi:
Perencanaan ke depan:
Penilaian kondisi usaha:

Aturan wajib:
- Semua angka sudah dihitung oleh aplikasi. JANGAN menghitung, menjumlah,
  membulatkan, atau mengarang angka baru. Jika menyebut angka, salin
  persis dari data. Lebih baik tidak menyebut angka daripada salah.
- Teks polos saja. Tanpa Markdown: tanpa tanda bintang, pagar, garis
  bawah, atau tabel. Daftar boleh memakai tanda hubung di awal baris.
- Bahasa Indonesia sederhana, ramah, dan praktis. Tanpa istilah akuntansi
  yang rumit. Saran harus konkret dan bisa dilakukan usaha kecil.
- Maksimal sekitar 200 kata secara keseluruhan."""


def _rupiah(n: int) -> str:
    tanda = "minus " if n < 0 else ""
    return f"{tanda}Rp {abs(n):,}".replace(",", ".")


def _baris_rincian(rincian: list[RincianKategori]) -> str:
    if not rincian:
        return "- (tidak ada)"
    return "\n".join(
        f"- {r.nama}: {_rupiah(r.total)}, {r.jumlah_transaksi} transaksi, "
        f"{r.persen} persen"
        for r in rincian
    )


def _baris_perubahan(label: str, persen: int | None) -> str:
    if persen is None:
        return f"{label} dibanding bulan lalu: tidak ada data pembanding"
    arah = "naik" if persen >= 0 else "turun"
    return f"{label} dibanding bulan lalu: {arah} {abs(persen)} persen"


@app.post("/v1/ai/analyze-report", response_model=AnalisisLaporanResponse)
async def analyze_report(req: AnalisisLaporanRequest) -> AnalisisLaporanResponse:
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY belum diisi di backend/.env",
        )

    user_prompt = (
        f"Periode: {req.periode}\n"
        f"Total pendapatan: {_rupiah(req.total_pendapatan)}\n"
        f"Total beban biaya: {_rupiah(req.total_beban)}\n"
        f"Laba bersih: {_rupiah(req.laba_bersih)}\n"
        f"Jumlah transaksi: {req.jumlah_transaksi}\n"
        f"{_baris_perubahan('Pendapatan', req.perubahan_pendapatan)}\n"
        f"{_baris_perubahan('Beban biaya', req.perubahan_beban)}\n"
        f"Rincian pendapatan per kategori:\n"
        f"{_baris_rincian(req.rincian_pendapatan)}\n"
        f"Rincian beban biaya per kategori:\n"
        f"{_baris_rincian(req.rincian_beban)}"
    )

    body = {
        "system_instruction": {"parts": [{"text": ANALISIS_PROMPT}]},
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
    }

    # Sedikit di bawah batas tunggu app (20 detik), supaya app menerima
    # pesan galat yang jelas dari sini, bukan sekadar timeout.
    async with httpx.AsyncClient(timeout=18.0) as client:
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
        teks = data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError) as e:
        raise HTTPException(
            status_code=502,
            detail=f"Format balasan Gemini tidak terduga: {e}",
        )

    # Jaga-jaga bila model tetap memakai Markdown: pembaca layar akan
    # membacakan tanda bintang dan pagar satu per satu.
    teks = teks.replace("**", "").replace("#", "").strip()

    return AnalisisLaporanResponse(analisis=teks)


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True, "key_configured": bool(GEMINI_API_KEY)}
