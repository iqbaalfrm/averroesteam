# Averroes Backend (Flask)

Backend API dan admin dashboard untuk aplikasi Averroes.

## Menjalankan Lokal (Development)

```bash
cd apps/backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
flask --app run.py db upgrade
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
flask --app run.py db upgrade
gunicorn -w 3 -k gthread --threads 4 -b 0.0.0.0:5000 wsgi:app
```

## Konfigurasi Environment

Gunakan `.env` dan atur minimal:
- `APP_ENV=production`
- `SECRET_KEY=<random panjang dan kuat>`
- `JWT_SECRET_KEY=<random panjang dan kuat>`
- `DATABASE_URL=<postgresql://... atau mysql://...>`

Konfigurasi scraping berita crypto:
- `NEWS_SCRAPER_ENABLED=true`
- `NEWS_SCRAPER_INTERVAL_SECONDS=21600` (6 jam)
- `NEWS_SCRAPER_LIMIT=20`
- `NEWS_SCRAPER_FEEDS=https://cryptowave.co.id/`

Catatan:
- Saat `APP_ENV=production`, app akan gagal start jika secret wajib belum diisi.
- Seed data otomatis hanya aktif di mode development.

## Production Checklist

1. Set `APP_ENV=production`.
2. Gunakan DB managed (PostgreSQL/MySQL), jangan `sqlite` untuk production.
3. Set `SECRET_KEY` dan `JWT_SECRET_KEY` dengan nilai acak kuat.
4. Jalankan migrasi: `flask --app run.py db upgrade`.
5. Jalankan via Gunicorn (`wsgi:app`), bukan `python run.py`.
6. Pasang reverse proxy (Nginx/Caddy) + HTTPS.
7. Pastikan `UPLOAD_FOLDER` menggunakan persistent storage.
8. Ganti kredensial admin dev dan nonaktifkan seed di production (otomatis lewat `APP_ENV=production`).
9. Batasi akses `/admin` (IP allowlist/VPN/SSO jika memungkinkan).
10. Aktifkan logging dan monitoring error.
