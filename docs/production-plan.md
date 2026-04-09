# Production Plan - Averroes

## Tujuan

Dokumen ini adalah rencana deploy production untuk monorepo **Averroes** setelah keputusan arsitektur baru tim:

- Database pindah dari **MongoDB** ke **Supabase PostgreSQL**
- Auth utama pindah dari **JWT custom backend** ke **Supabase Auth**
- Wallet onboarding dan wallet linking memakai **Privy**

Tujuan akhirnya adalah rilis yang lebih aman, terukur, mudah dioperasikan, dan lebih siap untuk fitur wallet di mobile.

## Scope

- `apps/backend` (Flask API + admin + integrasi auth verification)
- `apps/mobile` (Flutter app)
- `packages/*` (shared Flutter packages)
- Supabase project:
  - PostgreSQL
  - Auth
  - Storage/Realtimes jika dipakai
- Privy:
  - login/link wallet
  - embedded wallet / wallet provisioning
- Migrasi data dari MongoDB ke PostgreSQL
- Monitoring, backup, rollback, dan cutover production

## Keputusan Arsitektur Final

### 1. Identity dan session

- **Supabase Auth** menjadi sumber identitas utama user.
- Login email/password, OTP, dan session aplikasi mengikuti Supabase Auth.
- `auth.users.id` menjadi canonical user identity untuk seluruh sistem.

### 2. Wallet dan Web3 onboarding

- **Privy** dipakai untuk wallet provisioning, wallet linking, dan pengalaman Web3/mobile wallet yang lebih ringan.
- Privy **bukan** sumber identitas utama aplikasi.
- Privy user/wallet di-link ke user Supabase pada tabel aplikasi.

### 3. Business API

- **Flask backend tetap dipertahankan** untuk business logic, admin flow, integrasi existing, dan endpoint domain seperti edukasi, quiz, sertifikat, portofolio, zakat, pustaka, dan konsultasi.
- Backend tidak lagi menerbitkan JWT aplikasi sendiri untuk mobile.
- Backend memverifikasi access token dari Supabase Auth dan menggunakan `supabase_user_id` sebagai identity principal.

### 4. Database

- **Supabase PostgreSQL** menjadi source of truth data aplikasi.
- MongoDB lama diperlakukan sebagai sumber migrasi, bukan target akhir production.
- Storage file diusahakan pindah ke Supabase Storage atau object storage lain yang persistent.

## Prinsip Integrasi Supabase Auth + Privy

Supaya arsitekturnya tidak tumpang tindih, pembagiannya harus tegas:

- Supabase Auth:
  - register/login
  - email verification
  - password reset / OTP
  - access token / refresh token
  - session user aplikasi
- Privy:
  - embedded wallet
  - wallet linking
  - wallet metadata
  - future on-chain identity UX
- Flask backend:
  - verifikasi Supabase token
  - role/authorization aplikasi
  - sinkronisasi profil user
  - business rules domain
- PostgreSQL:
  - profile user
  - relasi role
  - data bisnis
  - relasi ke wallet / Privy identity

## Target Arsitektur Production

- `Flutter Mobile App`
  - `Supabase Auth SDK` untuk login/session
  - `Privy SDK` untuk wallet
- `Flutter Mobile App` -> HTTPS -> `Nginx/Caddy (Reverse Proxy)` -> `Gunicorn + Flask`
- `Gunicorn + Flask` -> `Supabase PostgreSQL`
- `Gunicorn + Flask` -> `Supabase Storage / object storage` untuk file
- `Gunicorn + Flask` -> verifikasi `Supabase JWT`
- `Gunicorn + Flask` -> sinkronisasi user profile dan wallet linkage
- Logging aplikasi -> file/agent -> monitoring/log aggregation

## Model Data Identitas (Recommended)

Minimal siapkan tabel aplikasi berikut di PostgreSQL:

- `profiles`
  - `id uuid primary key` -> sama dengan `auth.users.id`
  - `email`
  - `nama`
  - `role`
  - `avatar_url`
  - `is_active`
  - `created_at`
  - `updated_at`
- `user_wallets`
  - `id uuid primary key`
  - `user_id uuid references profiles(id)`
  - `privy_user_id`
  - `wallet_address`
  - `wallet_type`
  - `is_primary`
  - `created_at`
- `auth_audit_logs` (opsional)
  - event auth penting
  - provider login
  - linked wallet

Prinsip penting:

- `profiles.id = auth.users.id`
- data domain aplikasi tidak lagi bergantung pada ObjectId Mongo
- wallet disimpan sebagai relasi ke user aplikasi, bukan identitas utama

## Deliverables

- Supabase project production siap
- Schema PostgreSQL final terdokumentasi
- Mapping MongoDB -> PostgreSQL terdokumentasi
- Migrasi data awal berhasil diverifikasi
- Supabase Auth aktif untuk login/register/reset password
- Privy terintegrasi untuk wallet onboarding/linking
- Flask backend memverifikasi Supabase token
- Mobile app release mengarah ke auth flow baru
- Monitoring, backup, rollback, dan cutover plan terdokumentasi
- Smoke test dan UAT minimum lulus

## Status Teknis Repo Saat Ini

Temuan penting dari codebase saat ini:

- Backend masih memakai **MongoDB** sebagai database utama
- Backend masih memakai **JWT custom** via `Flask-JWT-Extended`
- Banyak endpoint domain masih bergantung pada decorator auth backend sekarang
- Mobile app masih login ke endpoint `/api/auth/*` milik Flask
- Password reset, OTP register, guest login, dan profile update masih dikelola backend lama

Implikasinya:

- Ini bukan sekadar ganti connection string database
- Ini adalah migrasi arsitektur data dan identity
- Scope migrasi harus diphase dengan disiplin agar tidak merusak flow release mobile

## Checklist Readiness (Pre-Production)

### 1. Konfigurasi & Secrets

- [ ] Set `APP_ENV=production`
- [ ] Set `SUPABASE_URL`
- [ ] Set `SUPABASE_ANON_KEY` untuk mobile
- [ ] Set `SUPABASE_SERVICE_ROLE_KEY` hanya di backend/server
- [ ] Set `SUPABASE_JWKS_URL` atau konfigurasi verifikasi JWT Supabase yang dipakai backend
- [ ] Set `PRIVY_APP_ID`
- [ ] Set `PRIVY_APP_SECRET` hanya di backend jika diperlukan
- [ ] Set `PRIVY_CLIENT_ID`/config mobile sesuai SDK
- [ ] Review redirect URL / deep link mobile auth
- [ ] Review `.env` agar tidak ada kredensial dev/test
- [ ] Simpan secrets di secret manager / vault / environment server, bukan commit Git

### 2. Database & Migration

- [ ] Desain schema PostgreSQL final untuk seluruh domain utama
- [ ] Buat mapping koleksi MongoDB -> tabel PostgreSQL
- [ ] Buat script migrasi yang idempotent
- [ ] Migrasikan data user, edukasi, progress, quiz, sertifikat, portofolio, pustaka, diskusi, dan domain lain yang diperlukan
- [ ] Verifikasi foreign key, unique constraint, dan indeks penting
- [ ] Siapkan backup MongoDB sebelum cutover
- [ ] Siapkan backup Supabase/Postgres harian + retensi backup
- [ ] Uji restore backup ke environment staging/test

### 3. Auth & Identity Readiness

- [ ] Putuskan provider login awal yang aktif di Supabase Auth
- [ ] Migrasikan user existing ke Supabase Auth atau siapkan forced reset/password re-enrollment
- [ ] Tentukan strategi email verification untuk user lama
- [ ] Tentukan strategi guest user: dipertahankan, dihapus, atau diubah ke anonymous session
- [ ] Tentukan strategi role (`user`, `admin`, dll) di tabel aplikasi
- [ ] Implement link antara `profiles.id` dan `privy_user_id`
- [ ] Tentukan kapan wallet otomatis dibuat: saat signup, saat first login, atau saat user masuk fitur wallet

### 4. Backend Readiness

- [ ] Ganti middleware auth dari JWT custom ke verifikasi token Supabase
- [ ] Hapus ketergantungan mobile pada endpoint `/api/auth/login`, `/register`, `/lupa-password` lama setelah flow baru stabil
- [ ] Tambah helper `current_user` berbasis `supabase_user_id`
- [ ] Pastikan role/authorization tidak hanya percaya claim client
- [ ] Audit seluruh endpoint yang sebelumnya memakai `@jwt_required()`
- [ ] Pastikan `SUPABASE_SERVICE_ROLE_KEY` tidak pernah bocor ke mobile
- [ ] Review admin flow: tetap pakai session server-side atau dipindah bertahap
- [ ] Set ukuran upload, timeout, dan storage target sesuai kebutuhan

### 5. Mobile App Release

- [ ] Integrasikan Supabase Auth SDK di Flutter
- [ ] Integrasikan Privy SDK di Flutter
- [ ] Refactor login/register/reset password agar mengikuti Supabase flow
- [ ] Refactor penyimpanan token/session agar tidak lagi bergantung pada JWT custom backend
- [ ] Tambah flow wallet linking di onboarding atau profile
- [ ] Verifikasi login, refresh session, logout, relink wallet, dan resume session
- [ ] Build release Android/iOS mengarah ke Supabase project yang benar
- [ ] UAT internal sebelum distribusi publik

### 6. Monitoring & Operasional

- [ ] Logging backend terstruktur untuk verifikasi auth, sync profile, dan wallet linking
- [ ] Monitoring uptime endpoint healthcheck
- [ ] Alert untuk error rate auth tinggi / service down / disk hampir penuh
- [ ] Monitoring Supabase database connections, storage growth, dan auth errors
- [ ] Catat SOP restart service dan insiden

## Mapping Data MongoDB -> PostgreSQL (Draft Awal)

Mapping final harus divalidasi sebelum implementasi script migrasi.

| MongoDB Collection | PostgreSQL Table (Draft) | Catatan |
|---|---|---|
| `users` | `profiles` | `auth.users` pegang identity, `profiles` pegang data aplikasi |
| `kelas` | `classes` | master kelas |
| `modul` | `class_modules` | relasi ke `classes` |
| `materi` | `class_materials` | relasi ke `class_modules` |
| `materi_progress` | `material_progress` | relasi ke `profiles` dan `class_materials` |
| `quiz` | `quizzes` | relasi ke `classes` |
| `quiz_submissions` | `quiz_submissions` | relasi ke `profiles` dan `quizzes` |
| `sertifikat` | `certificate_templates` | template sertifikat |
| `sertifikat_user` | `user_certificates` | hasil generate user |
| `portofolio` | `portfolios` | user-based |
| `portofolio_riwayat` | `portfolio_history` | histori aksi |
| `diskusi` | `discussion_threads` / `discussion_replies` | bisa dipisah atau single table parent-child |
| `buku` | `books` | pustaka |
| `kategori_buku` | `book_categories` | pustaka |
| `kajian` | `kajian_items` | konten kajian |
| `berita` | `news_items` | konten berita |
| `screener` | `screeners` | data screener |
| `sessions` | `consultation_sessions` | domain konsultasi |

## Langkah Implementasi Production (Runbook)

### Phase 0 - Scope Freeze & Audit (H-14 s/d H-10)

1. Freeze perubahan besar fitur auth dan data model.
2. Inventaris seluruh endpoint yang membaca/menulis MongoDB.
3. Inventaris seluruh endpoint yang memakai auth JWT custom.
4. Tetapkan domain mana yang wajib ikut cutover di gelombang pertama.
5. Putuskan strategi migrasi user existing.

Output wajib:

- daftar collection Mongo yang aktif
- daftar endpoint auth lama
- keputusan guest user
- keputusan user migration vs forced reset

### Phase 1 - Schema & Auth Design (H-10 s/d H-7)

1. Buat schema PostgreSQL final di Supabase.
2. Tentukan constraint, indeks, dan relasi inti.
3. Definisikan tabel `profiles` dan `user_wallets`.
4. Finalisasi arsitektur:
   - Supabase Auth = identity/session
   - Privy = wallet/linking
   - Flask = business API + auth verification
5. Finalisasi strategi role dan admin authorization.

Output wajib:

- schema SQL final
- mapping Mongo -> Postgres
- auth sequence diagram

### Phase 2 - Integrasi Auth Baru (H-7 s/d H-4)

1. Integrasikan Supabase Auth di mobile.
2. Integrasikan Privy di mobile.
3. Buat mekanisme verifikasi token Supabase di Flask.
4. Tambahkan helper sync profile:
   - buat profile jika belum ada
   - update metadata dasar bila perlu
5. Tambahkan endpoint wallet linking jika flow butuh server acknowledgement.

Flow target:

- user login via Supabase Auth
- mobile dapat session/token
- mobile panggil Flask API dengan bearer token Supabase
- backend verifikasi token
- backend load/create profile user
- mobile link/create wallet via Privy
- wallet metadata tersimpan ke PostgreSQL

### Phase 3 - Migrasi Data (H-4 s/d H-2)

1. Backup penuh MongoDB.
2. Jalankan migrasi ke PostgreSQL pada staging.
3. Verifikasi jumlah record, relasi, dan sampel data.
4. Fix mismatch data type, unique conflict, dan nullability issue.
5. Ulangi migrasi hingga hasil staging stabil.

Checklist validasi:

- [ ] jumlah user masuk akal
- [ ] progress belajar user cocok
- [ ] quiz submission cocok
- [ ] sertifikat user cocok
- [ ] pustaka/kategori tidak putus relasi
- [ ] data portofolio user cocok

### Phase 4 - UAT & Hotfix (H-2 s/d H-1)

1. Jalankan UAT dengan auth flow baru.
2. Uji login, logout, refresh session, reset password, dan relink wallet.
3. Uji flow inti:
   - auth
   - home
   - edukasi
   - progress
   - quiz
   - sertifikat
   - profil
   - fitur wallet terkait
4. Catat bug by severity.
5. Rilis hotfix seperlunya.

### Phase 5 - Cutover Production (Hari H)

1. Freeze write traffic ke MongoDB jika dibutuhkan.
2. Jalankan migrasi final ke Supabase Postgres.
3. Switch backend production ke Postgres/Supabase.
4. Switch mobile release candidate ke auth flow baru.
5. Jalankan smoke test dari luar server.
6. Monitor 24-48 jam pertama dengan fokus auth dan data consistency.

## Smoke Test Minimum (Post-Deploy)

- [ ] Signup / login Supabase Auth berhasil
- [ ] Session restore setelah app restart berhasil
- [ ] Logout berhasil
- [ ] Reset password / OTP flow berhasil
- [ ] Link wallet via Privy berhasil
- [ ] Endpoint protected Flask menerima token Supabase dengan benar
- [ ] Akses data kelas berhasil
- [ ] Menandai materi selesai berhasil
- [ ] Submit quiz berhasil
- [ ] Generate sertifikat berhasil
- [ ] Upload file tersimpan di storage persistent
- [ ] Admin page dapat diakses hanya oleh pihak berwenang

## Flow Kritis UAT Mobile (Updated)

- [ ] Register / login via Supabase Auth
- [ ] Reset password / verifikasi email
- [ ] Restore session saat app dibuka ulang
- [ ] Link atau create wallet via Privy
- [ ] Buka Beranda/Home
- [ ] Masuk ke Kelas/Edukasi dan buka detail materi
- [ ] Simpan progress belajar
- [ ] Submit Quiz
- [ ] Generate / lihat Sertifikat
- [ ] Buka / edit Profil

## Risiko Utama

### Risiko teknis

- Migrasi user lama ke Supabase Auth bisa jadi bottleneck terbesar
- Perubahan ObjectId Mongo ke UUID/int Postgres bisa memutus relasi jika mapping jelek
- Endpoint existing sangat banyak yang mengasumsikan JWT custom
- Dual auth semantics antara Supabase dan Privy bisa membingungkan jika boundary tidak disiplin

### Risiko produk

- User lama bisa gagal login jika migrasi password/account tidak jelas
- Flow wallet bisa menambah friction onboarding jika dipaksa terlalu awal
- Fitur non-kritikal bisa memperlambat cutover jika ikut dimigrasikan bersamaan

### Mitigasi

- Gunakan Supabase Auth sebagai satu-satunya auth aplikasi
- Jadikan Privy wallet opsional pada fase awal jika perlu
- Prioritaskan domain kritikal untuk wave pertama
- Siapkan fallback/rollback yang jelas

## Rollback Plan

### Trigger Rollback

- Error rate auth tinggi setelah deploy
- User existing gagal login massal
- Migrasi data menyebabkan inkonsistensi kritikal
- Endpoint utama tidak stabil > 15 menit

### Prosedur Rollback

1. Nonaktifkan release mobile yang mengarah ke flow auth baru jika perlu.
2. Rollback backend ke release sebelumnya.
3. Arahkan traffic kembali ke stack lama jika cutover penuh belum aman.
4. Gunakan backup database yang sesuai:
   - MongoDB backup sebelum cutover
   - Postgres backup/snapshot bila diperlukan
5. Verifikasi smoke test minimum pada stack rollback.
6. Catat insiden dan root cause sebelum redeploy.

## Rencana Tanggung Jawab (Isi Nama Tim)

- PIC Backend/Auth Verification: `TBD`
- PIC Database Migration: `TBD`
- PIC Mobile Auth/Privy: `TBD`
- PIC Infra/Server: `TBD`
- PIC QA/UAT: `TBD`
- PIC Release Approval: `TBD`

## Timeline Singkat (Template)

- H-14: Freeze scope auth/data + audit
- H-10: Final schema SQL + auth design
- H-7: Integrasi Supabase Auth + Privy dimulai
- H-4: Migrasi data staging + verifikasi
- H-2: UAT auth/data end-to-end
- H-1: Final hotfix + release candidate
- H: Cutover production + monitoring intensif
- H+1/H+2: Evaluasi awal post-release

## Catatan Penting

- Jangan jalankan production dengan MongoDB sebagai target akhir jika keputusan tim sudah final pindah ke Supabase.
- Jangan biarkan `SUPABASE_SERVICE_ROLE_KEY` masuk ke mobile app.
- Jangan menjalankan dua sumber auth utama untuk session aplikasi.
- Gunakan **Supabase Auth sebagai identity utama**, dan **Privy sebagai wallet layer**.
- Pastikan seluruh secret disimpan di luar repository Git.