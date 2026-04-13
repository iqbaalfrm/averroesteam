# Averroes

Averroes adalah aplikasi edukatif tentang **Aset Kripto Syariah** dan **Fiqh Muamalah Digital**.
Fokus pada edukasi yang tenang, bukan ajakan investasi.

## Struktur Monorepo

```text
.
|- apps/
|  |- admin-backend/  # Admin backend terpisah
|  |- backend/        # Backend API utama (Flask)
|  |- mobile/         # Aplikasi Flutter utama
|  |- vps-news-sync/  # Worker VPS untuk sinkronisasi berita ke Supabase
|  `- web/            # Frontend web (scaffold/opsional)
|- packages/          # Shared Flutter packages
|- docs/              # Planning, runbook, tracking
|- scripts/           # Smoke test / automation helper
|- .editorconfig
|- .gitattributes
|- .gitignore
`- README.md
```

## Konvensi Struktur

- `apps/` untuk aplikasi runnable (`backend`, `admin-backend`, `mobile`, `web`)
- `apps/vps-news-sync/` untuk worker VPS yang tidak perlu ikut masuk jalur serverless utama
- `packages/` untuk kode reusable (tema, network, shared models)
- `docs/` untuk rencana, status, runbook, audit
- `scripts/` untuk helper operasional/testing (mis. smoke test)

## Menjalankan Mobile App (Flutter)

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Menjalankan Backend (Flask)

```bash
cd apps/backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python run.py
```

## Menjalankan Admin Backend

```bash
cd apps/admin-backend
composer install
copy .env.example .env
php artisan key:generate
php artisan serve
```

## Menjalankan Worker VPS News Sync

```bash
cd apps/vps-news-sync
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python news_sync_worker.py
```

Boundary arsitektur aplikasi dan worker telah dijelaskan selengkapnya di dalam `docs/averroes.md`.

## Tim

**Averroes Team** - Skripsi Project
