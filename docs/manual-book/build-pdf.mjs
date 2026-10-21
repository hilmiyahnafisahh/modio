// Membuat Manual_Book_Modio.pdf dari MANUAL_BOOK.md.
//
// Cara pakai (dari folder mana saja):
//   node docs/manual-book/build-pdf.mjs
//
// Butuh: Node.js, Google Chrome atau Microsoft Edge, dan koneksi internet
// (pustaka pengubah Markdown dimuat dari CDN saat dirender).
// Penanda screenshot di Markdown berbentuk kutipan yang diawali
// "[SCREENSHOT nn — ...]". Di PDF penanda itu tampil sebagai kotak garis
// putus-putus. Jika berkas yang disarankan sudah ada di folder screenshots/,
// gambarnya otomatis dipakai menggantikan kotak; jalankan ulang skrip ini
// setelah menaruh gambar.

import { readFileSync, writeFileSync, existsSync, unlinkSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const dir = dirname(fileURLToPath(import.meta.url));
const mdPath = join(dir, 'MANUAL_BOOK.md');
const htmlPath = join(dir, '.manual-book-render.html');
const pdfPath = join(dir, 'Manual_Book_Modio.pdf');

const browsers = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
];
const browser = browsers.find(existsSync);
if (!browser) {
  console.error('Chrome/Edge tidak ditemukan.');
  process.exit(1);
}

const markdown = readFileSync(mdPath, 'utf8');

const html = `<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<title>Manual Book Modio</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/marked/12.0.2/marked.min.js"></script>
<style>
  @page { size: A4; margin: 18mm 16mm 20mm; }
  * { box-sizing: border-box; }
  body {
    font-family: "Segoe UI", Inter, Arial, sans-serif;
    font-size: 10.5pt; line-height: 1.55; color: #1b2430; margin: 0;
  }
  h1, h2, h3 { color: #0b3d5c; line-height: 1.25; break-after: avoid; }
  h2 {
    font-size: 17pt; margin: 0 0 10pt; padding-bottom: 6pt;
    border-bottom: 2px solid #0b3d5c; break-before: page;
  }
  h3 { font-size: 13pt; margin: 18pt 0 6pt; }
  p, li { orphans: 3; widows: 3; }
  a { color: #0b5c8a; text-decoration: none; }
  hr { display: none; }
  code { font-family: Consolas, monospace; font-size: 9.5pt; background: #eef2f6; padding: 0 3px; border-radius: 3px; }
  pre { background: #eef2f6; padding: 8pt 10pt; border-radius: 6px; break-inside: avoid; }
  pre code { background: none; padding: 0; }
  table { width: 100%; border-collapse: collapse; margin: 8pt 0 12pt; font-size: 9.8pt; break-inside: auto; }
  tr { break-inside: avoid; }
  th { background: #0b3d5c; color: #fff; text-align: left; font-weight: 600; }
  th, td { border: 1px solid #c8d2dc; padding: 5pt 7pt; vertical-align: top; }
  tbody tr:nth-child(even) td { background: #f5f8fa; }
  blockquote {
    margin: 10pt 0; padding: 7pt 11pt; background: #f2f7fb;
    border-left: 4px solid #4a90c2; border-radius: 0 6px 6px 0; break-inside: avoid;
  }
  blockquote p { margin: 3pt 0; }

  /* Bingkai screenshot */
  figure.shot { margin: 12pt auto; text-align: center; break-inside: avoid; }
  figure.shot img {
    max-width: 62%; max-height: 150mm; border: 1px solid #c8d2dc;
    border-radius: 8px; box-shadow: 0 2px 6px rgba(0,0,0,.12);
  }
  figure.shot .kosong {
    width: 62%; height: 120mm; margin: 0 auto; border: 2px dashed #8aa4ba;
    border-radius: 10px; background: #f7fafc; color: #5b7184;
    display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6pt;
  }
  figure.shot .kosong .label { font-weight: 600; color: #33566f; padding: 0 10pt; }
  figure.shot .kosong code { background: #e3ebf2; }
  figure.shot figcaption { margin-top: 5pt; font-size: 9pt; color: #5b7184; font-style: italic; }

  /* Sampul */
  .sampul {
    height: 250mm; display: flex; flex-direction: column; justify-content: center;
    align-items: center; text-align: center; break-after: page;
  }
  .sampul h1 { font-size: 34pt; margin: 0 0 8pt; }
  .sampul .sub { font-size: 14pt; color: #33566f; margin: 0 0 4pt; }
  .sampul .meta { font-size: 10.5pt; color: #5b7184; }
  .sampul .garis { width: 60mm; height: 3px; background: #0b3d5c; margin: 16pt 0; }
</style>
</head>
<body>
<main id="isi"></main>
<script id="sumber" type="text/markdown">${markdown.replace(/<\/script/gi, '<\\/script')}</script>
<script>
  const isi = document.getElementById('isi');
  isi.innerHTML = marked.parse(document.getElementById('sumber').textContent);

  // Id judul ala GitHub agar tautan Daftar Isi berfungsi di PDF.
  isi.querySelectorAll('h1, h2, h3').forEach((h) => {
    h.id = h.textContent.trim().toLowerCase()
      .replace(/[^\\p{L}\\p{N}\\s-]/gu, '').replace(/\\s/g, '-');
  });

  // Sampul: judul, subjudul, dan info versi sebelum garis pertama.
  const h1 = isi.querySelector('h1');
  const [sub, meta] = h1.nextElementSibling.innerHTML.split(/<br>|\\n/);
  const sampul = document.createElement('section');
  sampul.className = 'sampul';
  sampul.innerHTML = '<h1>' + h1.textContent + '</h1><div class="garis"></div>' +
    '<p class="sub">' + sub + '</p><p class="meta">' + (meta || '') + '</p>';
  h1.nextElementSibling.remove();
  h1.replaceWith(sampul);
  // Daftar Isi tidak perlu dimulai di halaman baru setelah sampul.
  const h2Pertama = isi.querySelector('h2');
  if (h2Pertama) h2Pertama.style.breakBefore = 'auto';

  // Kutipan "[SCREENSHOT nn — ...]" -> bingkai screenshot. Isinya: baris
  // penanda, berkas yang disarankan (dalam <code>), dan keterangan gambar
  // (dalam <em>). Gambar dipakai bila berkasnya sudah ada.
  isi.querySelectorAll('blockquote').forEach((bq) => {
    if (!bq.textContent.trim().startsWith('[SCREENSHOT')) return;
    const penanda = bq.querySelector('strong')?.textContent ?? '';
    const file = bq.querySelector('code')?.textContent ?? '';
    const keterangan = bq.querySelector('em')?.textContent ?? '';
    const fig = document.createElement('figure');
    fig.className = 'shot';
    fig.innerHTML = '<div class="kosong"><div class="label"></div><code></code></div>' +
      '<figcaption></figcaption>';
    fig.querySelector('.label').textContent = penanda;
    fig.querySelector('code').textContent = file;
    fig.querySelector('figcaption').textContent = keterangan;
    if (file) {
      const gambar = new Image();
      gambar.alt = keterangan;
      gambar.onload = () => fig.querySelector('.kosong').replaceWith(gambar);
      gambar.src = file;
    }
    bq.replaceWith(fig);
  });
</script>
</body>
</html>`;

writeFileSync(htmlPath, html, 'utf8');

try {
  execFileSync(browser, [
    '--headless=new',
    '--disable-gpu',
    '--no-pdf-header-footer',
    '--virtual-time-budget=15000',
    `--print-to-pdf=${pdfPath}`,
    pathToFileURL(htmlPath).href,
  ], { stdio: 'ignore' });
} finally {
  unlinkSync(htmlPath);
}

console.log('PDF dibuat: ' + pdfPath);
