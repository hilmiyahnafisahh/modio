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
- kategori: PILIH SATU dari daftar kategori untuk jenis yang kamu tentukan
  di atas (kategori_masuk jika jenis masuk, kategori_keluar jika jenis
  keluar), yang paling cocok dengan isi ucapan. null jika tidak ada yang
  cocok sama sekali atau jenis tidak jelas. Jangan mengarang kategori di
  luar daftar yang diberikan.
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
        catatan=hasil.get("catatan", ""),
    )


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True, "key_configured": bool(GEMINI_API_KEY)}
