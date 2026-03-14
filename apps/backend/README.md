# Averroes Backend (Flask)

Backend API dan admin dashboard untuk aplikasi Averroes.

## Menjalankan Lokal (Development)

Pastikan MongoDB sudah berjalan (misal di `localhost:27017`).

```bash
cd apps/backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env

# Jalankan server
python run.py
```

Backend aktif di `http://localhost:5000`.

## Endpoint LMS Utama

- `GET /api/kelas`
- `GET /api/kelas/<kelas_id>` (detail kelas + modul + materi)
- `GET /api/kelas/<kelas_id>/progress` (JWT)
- `POST /api/materi/complete` (JWT)
- `POST /api/quiz/submit` (JWT)
- `POST /api/sertifikat/generate` (JWT, hanya jika progress memenuhi syarat)

## Menjalankan Production (Gunicorn)

```bash
cd apps/backend
pip install -r requirements.txt
gunicorn -w 3 -k gthread --threads 4 -b 0.0.0.0:5000 wsgi:app
```

## Konfigurasi Environment

Gunakan `.env` dan atur minimal:
- `APP_ENV=production`
- `SECRET_KEY=<random panjang dan kuat>`
- `JWT_SECRET_KEY=<random panjang dan kuat>`
- `MONGODB_URI=mongodb://...`
- `DB_NAME=averroes_db`
- `UPLOAD_FOLDER` (opsional). Jika path relatif (mis. `uploads`), otomatis dipetakan ke `apps/backend/uploads`.
  Pastikan folder ini writable oleh user service (contoh `www-data`).

Konfigurasi scraping berita crypto:
- `NEWS_SCRAPER_ENABLED=true`
- `NEWS_SCRAPER_INTERVAL_SECONDS=21600` (6 jam)
- `NEWS_SCRAPER_LIMIT=20`
- `NEWS_SCRAPER_FEEDS=https://cryptowave.co.id/`

Catatan:
- Saat `APP_ENV=production`, app akan gagal start jika secret wajib belum diisi.
- Seed data otomatis beserta pembuatan index hanya aktif jika di config diaktifkan.

## Production Checklist

1. Set `APP_ENV=production`.
2. Gunakan MongoDB klaster (contoh: MongoDB Atlas), bukan yang lokal untuk production yang andal.
3. Set `SECRET_KEY` dan `JWT_SECRET_KEY` dengan nilai acak kuat.
4. Jalankan via Gunicorn (`wsgi:app`), bukan `python run.py`.
5. Pasang reverse proxy (Nginx/Caddy) + HTTPS.
6. Pastikan `UPLOAD_FOLDER` menggunakan persistent storage.
   Jika error `Permission denied: 'uploads'`, buat folder dan set permission:
   - `sudo mkdir -p /var/www/AverroesTeam/apps/backend/uploads`
   - `sudo chown -R www-data:www-data /var/www/AverroesTeam/apps/backend/uploads`
7. Ganti kredensial admin (default `admin123`) saat di env production.
8. Batasi akses `/admin` (IP allowlist/VPN/SSO jika memungkinkan).
9. Aktifkan logging dan monitoring error.

# 1. Install ulang package untuk mendapat PyMongo (dan hapus SQLAlchemy)
pip install -r requirements.txt

# 2. Setup environment untuk menggunakan PyMongo Lokal (pastikan mongodb daemon berjalan)
# Di dalam [.env](cci:7://file:///c:/skripsi/AverroesTeam/apps/backend/.env:0:0-0:0), silakan setting:
# MONGODB_URI=mongodb://localhost:27017
# DB_NAME=averroes_db

# 3. Jalankan server background
python run.py

# 4. Verifikasi dan Smoke Test Endpoint (Skenario auth & Edukasi Lms)
python scripts/backend_smoke_auth_lms.py
