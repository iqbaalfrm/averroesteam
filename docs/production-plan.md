# Production Plan - Averroes

## Tujuan

Dokumen ini adalah rencana deploy production untuk monorepo **Averroes** (Flutter mobile + Python/Flask backend) agar rilis lebih aman, terukur, dan mudah di-rollback.

## Scope

- `apps/backend` (Flask API + admin)
- `apps/mobile` (Flutter app)
- `packages/*` (shared Flutter packages)
- Infrastruktur production (server, database, reverse proxy, storage, monitoring)

## Asumsi Teknis Saat Ini

- Backend: **Flask** + **Gunicorn** (`wsgi:app`)
- Mobile: **Flutter**
- Migration DB: `flask --app run.py db upgrade`
- Environment config via `.env`
- Backend mendukung DB production (`DATABASE_URL`) dan tidak disarankan pakai SQLite di production

## Target Arsitektur Production (Recommended)

- `Mobile App (Android/iOS)` -> HTTPS -> `Nginx/Caddy (Reverse Proxy)` -> `Gunicorn + Flask`
- `Gunicorn + Flask` -> `Managed PostgreSQL` (recommended)
- `Gunicorn + Flask` -> `Persistent Storage` untuk upload (disk ter-mount / object storage)
- Logging aplikasi -> file/agent -> monitoring/log aggregation

## Deliverables

- Environment production siap (`.env` production terisi aman)
- Database production + migrasi berhasil
- Backend berjalan via `gunicorn` di belakang reverse proxy + HTTPS
- Mobile app build release mengarah ke API production
- Monitoring, backup, dan rollback plan terdokumentasi
- Smoke test dan UAT minimum lulus

## Checklist Readiness (Pre-Production)

### 1. Konfigurasi & Secrets

- [ ] Set `APP_ENV=production`
- [ ] Set `SECRET_KEY` (random kuat)
- [ ] Set `JWT_SECRET_KEY` (random kuat)
- [ ] Set `DATABASE_URL` ke PostgreSQL/MySQL production
- [ ] Verifikasi `UPLOAD_FOLDER` ke lokasi persistent
- [ ] Review `.env` agar tidak ada kredensial dev/test
- [ ] Simpan secrets di secret manager / vault / minimal environment server (bukan commit Git)

### 2. Database

- [ ] Buat database production (user terpisah, privilege minimum)
- [ ] Jalankan migrasi: `flask --app run.py db upgrade`
- [ ] Verifikasi struktur tabel dan data awal wajib
- [ ] Siapkan backup harian + retensi backup
- [ ] Uji restore backup ke environment staging/test

### 3. Backend Readiness

- [ ] Install dependency: `pip install -r requirements.txt`
- [ ] Jalankan backend production command:
  - `gunicorn -w 3 -k gthread --threads 4 -b 0.0.0.0:5000 wsgi:app`
- [ ] Pasang process manager (`systemd` / supervisor)
- [ ] Batasi akses `/admin` (IP allowlist / VPN / auth kuat)
- [ ] Pastikan seed dev tidak aktif (`APP_ENV=production`)
- [ ] Konfigurasi CORS hanya untuk origin yang diperlukan
- [ ] Set ukuran upload dan timeout sesuai kebutuhan

### 4. Reverse Proxy & Network

- [ ] Pasang `Nginx`/`Caddy`
- [ ] Aktifkan HTTPS (TLS certificate valid)
- [ ] Redirect HTTP -> HTTPS
- [ ] Set header proxy (`X-Forwarded-*`)
- [ ] Rate limiting dasar untuk endpoint sensitif (login/admin)
- [ ] Aktifkan gzip/brotli (opsional)

### 5. Mobile App Release

- [ ] Tentukan `API_BASE_URL` production di `.env`/build config Flutter
- [ ] Build release Android (`apk`/`aab`) dan iOS (jika dipakai)
- [ ] Verifikasi login, kelas, progress, quiz, sertifikat terhadap backend production/staging
- [ ] Update versioning (`versionName/versionCode` / iOS build number)
- [ ] UAT internal sebelum distribusi publik

### 6. Monitoring & Operasional

- [ ] Logging backend terstruktur (minimal level, timestamp, endpoint, error)
- [ ] Monitoring uptime endpoint healthcheck
- [ ] Alert untuk error rate tinggi / service down / disk hampir penuh
- [ ] Monitoring DB connections dan storage growth
- [ ] Catat SOP restart service dan insiden

## Langkah Implementasi Production (Runbook)

### Phase 1 - Hardening & Validasi (H-7 s/d H-3)

1. Freeze perubahan besar fitur.
2. Rapikan `.env.example` dan daftar variabel wajib.
3. Validasi migrasi DB di staging.
4. Uji flow kritikal:
   - auth/login
   - list/detail kelas
   - progress materi
   - submit quiz
   - generate sertifikat
5. Siapkan backup + restore test.

### Phase 2 - Deploy Backend (H-2 s/d H-1)

1. Provision server/VM atau platform deployment.
2. Install Python runtime + dependency system yang dibutuhkan.
3. Pull code release tag/branch.
4. Set environment variables production.
5. Jalankan migrasi:
   - `flask --app run.py db upgrade`
6. Jalankan Gunicorn via `systemd`.
7. Pasang dan konfigurasi reverse proxy + HTTPS.
8. Jalankan smoke test API dari luar server.

### Phase 3 - Release Mobile (Hari H)

1. Point mobile app ke API production.
2. Build release candidate.
3. UAT singkat dengan akun real/test production-safe.
4. Publish ke internal testing / store release (sesuai kebutuhan tim).
5. Monitor error dan feedback 24-48 jam pertama.

### Phase 4 - Upgrade & Evaluasi per Fitur Mobile (H+1 s/d H+14)

1. Kumpulkan data penggunaan fitur mobile (screen yang sering dibuka, flow yang sering dipakai, feedback user).
2. Catat issue mobile per fitur:
   - crash / freeze
   - loading lambat
   - error API / parsing data
   - masalah navigasi / UX
3. Evaluasi fitur mobile berdasarkan dampak dan stabilitas.
4. Prioritaskan hotfix mobile per fitur (minor release), hindari refactor besar di fase stabilisasi.
5. Rilis perbaikan bertahap dan lakukan smoke test pada screen/flow terkait.
6. Dokumentasikan hasil evaluasi untuk backlog backend dan mobile phase berikutnya.

## Smoke Test Minimum (Post-Deploy)

- [ ] `GET` endpoint publik merespons `200`
- [ ] Login JWT berhasil
- [ ] Akses data kelas berhasil
- [ ] Menandai materi selesai berhasil
- [ ] Submit quiz berhasil
- [ ] Generate sertifikat berhasil (jika syarat terpenuhi)
- [ ] Upload file (jika ada fitur upload) tersimpan di storage persistent
- [ ] Admin page dapat diakses hanya oleh pihak berwenang

## Evaluasi Per Fitur Mobile (Template)

Gunakan format ini setelah production berjalan agar upgrade mobile berikutnya berbasis data.

| Fitur/Screen Mobile | Status | Usage | Issue Utama | Prioritas | Aksi Upgrade |
|---|---|---:|---|---|---|
| Login/Register | TBD | TBD | TBD | High/Med/Low | Contoh: validasi form, error message, retry |
| Beranda/Home | TBD | TBD | TBD | High/Med/Low | Contoh: loading skeleton, optimasi fetch |
| Kelas & Materi | TBD | TBD | TBD | High/Med/Low | Contoh: cache list/detail, UX navigasi |
| Progress Belajar | TBD | TBD | TBD | High/Med/Low | Contoh: sinkronisasi status, retry submit |
| Quiz | TBD | TBD | TBD | High/Med/Low | Contoh: validasi submit, handling timeout |
| Sertifikat | TBD | TBD | TBD | High/Med/Low | Contoh: state loading/gagal, download/share |
| Profil | TBD | TBD | TBD | High/Med/Low | Contoh: edit profil, feedback sukses/gagal |
| Notifikasi (jika aktif) | TBD | TBD | TBD | High/Med/Low | Contoh: refresh state, empty state |

Kriteria evaluasi mobile yang disarankan:

- Stabilitas: crash, freeze, error UI/state
- UX: alur membingungkan, tombol tidak jelas, empty/error state
- Performa: waktu buka app, waktu buka screen, loading API
- Integrasi API: error parsing, timeout, retry, state tidak sinkron
- Kompatibilitas device: ukuran layar, versi Android/iOS, permission
- Nilai penggunaan: fitur paling sering dipakai dan paling berdampak

## Checklist Evaluasi Mobile (H+1 s/d H+14)

- [ ] Kumpulkan feedback user internal/tester per screen
- [ ] Catat crash/error dari log/testing manual
- [ ] Urutkan top 5 issue mobile paling mengganggu
- [ ] Pisahkan issue mobile vs issue backend/API
- [ ] Rilis hotfix mobile prioritas tinggi
- [ ] Verifikasi ulang flow kritikal setelah hotfix
- [ ] Susun backlog improvement UX/performa untuk sprint berikutnya

## Eksekusi Per Phase (Mobile First)

Section ini dipakai untuk eksekusi aktual per phase. Update status dan hasilnya setiap selesai phase.

### Phase 1 - Planning & Freeze (Mobile) [START HERE]

Status: `Executed (Draft Scope - Need Team Confirmation)`

Tujuan phase:

- Menetapkan scope rilis mobile pertama
- Freeze perubahan besar agar fokus stabilisasi
- Menentukan flow kritikal yang wajib lolos UAT
- Menyiapkan baseline konfigurasi release

Temuan awal (berdasarkan repo saat ini):

- Versi app saat ini di `apps/mobile/pubspec.yaml`: `0.1.0+1`
- `API_BASE_URL` di `apps/mobile/.env.example` masih default emulator: `http://10.0.2.2:8080`
- Konfigurasi API dibaca dari `.env` melalui `AppConfig.apiBaseUrl` di `apps/mobile/lib/app/config/app_config.dart`
- Modul mobile cukup banyak (contoh utama): login/register, home, edukasi, quiz, sertifikat, profile, pasar, portofolio, zakat, chatbot
- `apps/mobile/README.md` masih template default Flutter (belum ada panduan release/UAT mobile)

Output wajib Phase 1 (status eksekusi saat ini):

- [x] Tentukan target rilis mobile (draft: `internal testing / closed beta`)
- [x] Pilih scope fitur rilis V1 mobile (draft scope di bawah)
- [x] Tetapkan flow kritikal mobile untuk UAT (baseline + prioritas)
- [ ] Freeze fitur besar (catat tanggal freeze)
- [ ] Tentukan PIC mobile, PIC QA/UAT, PIC release approval
- [x] Tentukan target versi release (draft: `0.1.1+2`)
- [x] Tentukan endpoint API target untuk testing (draft: `staging`)

Flow kritikal UAT mobile (prioritas):

- [x] Login/Register
- [x] Buka Beranda/Home (cek konten/fetch berita)
- [x] Masuk ke Kelas/Edukasi dan buka detail materi
- [x] Submit Quiz
- [x] Generate/Lihat Sertifikat
- [x] Buka/Edit Profil
- [x] Lupa Password + Verifikasi OTP

Scope rilis V1 mobile (rekomendasi eksekusi):

Fitur wajib (release blocker jika gagal):

- [x] Auth: `login`, `register`, `lupa password`, `verifikasi otp`
- [x] Home/Beranda
- [x] Edukasi: list kelas, detail kelas, progress, materi complete
- [x] Quiz submit
- [x] Sertifikat
- [x] Profil dasar + logout

Fitur menengah (boleh ada, bukan blocker V1):

- [x] Screener
- [x] Pasar
- [x] Portofolio
- [x] Notifikasi

Fitur opsional / bisa ditunda jika mengganggu stabilisasi:

- [x] Chatbot (API eksternal Groq)
- [x] Reels
- [x] Diskusi
- [x] Psikolog / Konsultasi
- [x] Zikir / Pustaka / Bantuan / Kebijakan Privasi

Dasar teknis rekomendasi scope:

- [x] Modul terhubung backend/API langsung terdeteksi pada `home`, `edukasi`, `login`, `register`, `lupa_password`, `screener`
- [x] `chatbot` memakai API eksternal (`Groq`), dipisahkan dari release blocker V1
- [x] Flow inti belajar (`auth -> edukasi -> quiz -> sertifikat`) dijadikan prioritas stabilisasi

Catatan keputusan Phase 1 (draft awal, finalisasi tim):

- Target rilis: `internal testing / closed beta`
- Scope fitur wajib: `Auth, Home, Edukasi, Quiz, Sertifikat, Profil dasar`
- Scope fitur ditunda: `Chatbot (opsional), fitur non-kritikal jika bug tinggi`
- Tanggal freeze: `TBD`
- Versi release: `0.1.1+2` (draft)
- API target: `staging` (draft)
- PIC mobile: `TBD`
- PIC QA/UAT: `TBD`
- PIC approval: `TBD`

### Phase 2 - Readiness Audit Mobile

Status: `In Progress (Audit + Baseline Fixes Applied)`

Fokus:

- Validasi config release (`API_BASE_URL`, secrets non-mobile, mode build)
- Audit UX state (loading/error/empty) pada flow kritikal
- Audit issue integrasi API (timeout/parsing/retry)
- Susun daftar bug prioritas tinggi

Temuan audit awal (repo current state):

- [x] `API_BASE_URL` masih default emulator pada `apps/mobile/.env.example` (`http://10.0.2.2:8080`) -> perlu file/env release terpisah untuk staging/production
- [x] Config API mobile sudah tersentral via `AppConfig.apiBaseUrl` (`apps/mobile/lib/app/config/app_config.dart`) -> bagus untuk switch environment
- [x] `dotenv` load di `apps/mobile/lib/bootstrap.dart` sudah ada fallback log -> perlu validasi `.env` release tersedia saat build
- [x] `GetStorage` init sudah ada di bootstrap -> auth persistence siap diuji
- [x] Belum ada timeout `Dio` konsisten terdeteksi di mobile/network layer -> risiko loading menggantung
- [x] `packages/network/lib/interceptors.dart` masih kosong -> belum ada logging/auth header/retry standar
- [x] `apps/mobile/README.md` masih template default -> belum ada runbook QA/UAT/release mobile
- [x] `chatbot` memakai API eksternal Groq -> perlu dipisahkan dari blocker release mobile utama

Perbaikan baseline yang sudah diterapkan (Phase 2):

- [x] Tambah helper `Dio` terpusat `apps/mobile/lib/app/services/api_dio.dart`
- [x] Set timeout default (`connect/send/receive`) untuk request mobile
- [x] Tambah interceptor ringan (attach auth token otomatis + debug logging non-release)
- [x] Patch flow auth menggunakan client terpusat:
  - `apps/mobile/lib/modules/login/login_page.dart`
  - `apps/mobile/lib/modules/register/register_page.dart`
  - `apps/mobile/lib/modules/lupa_password/lupa_password_page.dart`
  - `apps/mobile/lib/modules/lupa_password/verifikasi_otp_page.dart`
- [x] Patch `edukasi`, `home`, `screener` agar memakai client terpusat:
  - `apps/mobile/lib/modules/edukasi/edukasi_api.dart`
  - `apps/mobile/lib/modules/home/beranda_page.dart`
  - `apps/mobile/lib/modules/screener/screener_page.dart`
- [x] Tambah template env mobile:
  - `apps/mobile/.env.staging.example`
  - `apps/mobile/.env.production.example`
- [x] `flutter analyze` pada file yang diubah: tidak ada error compile dari perubahan (hanya warning/info existing)

Checklist eksekusi Phase 2 (mobile-first):

- [x] Definisikan strategi environment mobile (`.env.staging`, `.env.production`, atau CI secrets) [template example dibuat]
- [ ] Tetapkan `API_BASE_URL` staging untuk UAT dan production untuk release [menunggu domain/API final]
- [ ] Audit screen kritikal: loading state / empty state / error state
- [x] Audit timeout dan error handling `Dio` pada fitur wajib [baseline timeout + interceptor diterapkan]
- [x] Audit sinkronisasi auth token untuk endpoint JWT (edukasi/progress/quiz/sertifikat) [auth header auto-attach + existing auth options masih ada]
- [ ] Audit fallback UX saat backend down / timeout
- [x] Dokumentasikan langkah build & UAT mobile di `apps/mobile/README.md` atau `docs/` [ditambahkan `apps/mobile/README.md` pada 26 Feb 2026]

Output Phase 2 yang ditargetkan:

- Daftar bug/risiko `High`, `Medium`, `Low`
- Daftar perbaikan wajib sebelum UAT
- Daftar improvement yang bisa ditunda pasca rilis

### Phase 3 - UAT & Hotfix Mobile

Status: `Pending`

Fokus:

- Jalankan UAT pada flow kritikal
- Catat bug by severity
- Rilis hotfix bertahap
- Re-test flow terdampak

### Phase 4 - Go Live Mobile

Status: `Pending`

Fokus:

- Final build release
- Publish ke channel distribusi
- Monitoring awal 24-48 jam

### Phase 5 - Upgrade & Evaluasi Fitur Mobile (Post Release)

Status: `Pending`

Fokus:

- Kumpulkan feedback, issue, dan usage
- Prioritaskan per fitur/screen
- Jalankan minor improvement iteratif

## Rollback Plan

### Trigger Rollback

- Error rate tinggi setelah deploy
- Login/auth gagal massal
- Migrasi menyebabkan query/error kritikal
- Endpoint utama tidak stabil > 15 menit

### Prosedur Rollback

1. Rollback aplikasi ke release sebelumnya (tag/commit terakhir stabil).
2. Restart service backend (`systemd`).
3. Jika masalah dari migrasi DB:
   - restore backup DB, atau
   - jalankan migration downgrade (hanya jika sudah diuji)
4. Verifikasi smoke test minimum.
5. Catat insiden dan root cause sebelum redeploy.

## Rencana Tanggung Jawab (Isi Nama Tim)

- PIC Backend: `TBD`
- PIC Mobile: `TBD`
- PIC Infra/Server: `TBD`
- PIC QA/UAT: `TBD`
- PIC Release Approval: `TBD`

## Timeline Singkat (Template)

- H-7: Freeze fitur + review checklist
- H-5: Staging test lengkap + backup/restore test
- H-3: Finalisasi env production + hardening server
- H-2: Deploy backend production + smoke test
- H-1: UAT mobile release candidate
- H: Release mobile + monitoring intensif
- H+1/H+2: Evaluasi awal post-release
- H+3 s/d H+14: Upgrade & evaluasi fitur mobile (iteratif)

## Catatan Penting

- Jangan gunakan `sqlite` untuk production.
- Jangan jalankan backend production dengan `python run.py`.
- Pastikan folder upload tidak hilang saat restart/redeploy.
- Simpan secret di luar repository Git.
