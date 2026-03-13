# Backend Feature Execution Plan (Mobile-Connected Features) - Averroes

## Tujuan

Dokumen ini adalah rencana eksekusi backend agar fitur mobile yang bergantung ke API bisa dijalankan end-to-end untuk UAT/staging.

Fokus dokumen:

- memastikan endpoint yang dipanggil mobile benar-benar tersedia
- menutup gap contract API vs implementasi backend saat ini
- memastikan data seed dan auth JWT cukup untuk flow inti belajar
- menyiapkan checklist verifikasi sebelum UAT mobile

## Scope Prioritas (Backend untuk Mobile)

Fitur yang diprioritaskan agar bisa dieksekusi:

1. `Auth` (`login`, `register`, `guest`, `lupa password`, `verifikasi otp`, `reset password`)
2. `Home/Beranda` (feed `berita`)
3. `Edukasi` (kelas, detail, progress materi)
4. `Quiz` (submit jawaban)
5. `Sertifikat` (generate setelah memenuhi syarat)
6. `Screener` (list + metodologi)

Fitur non-blocker V1 (backend ada/parsial, bisa menyusul):

- `Diskusi`
- `Pustaka`
- `Portofolio`
- `Zakat`
- `Admin dashboard`
- `Chatbot` (bukan backend Flask internal)

## Baseline Kondisi Saat Ini (Repo Audit)

Backend stack aktif:

- `Flask` + `SQLAlchemy` + `Flask-Migrate` + `JWT`
- app entry: `apps/backend/run.py`, `apps/backend/wsgi.py`
- app factory: `apps/backend/app/__init__.py`
- config env: `apps/backend/app/config.py`
- seed data dev: `apps/backend/app/seed.py`

Temuan penting:

- Flow inti LMS backend sudah tersedia: kelas, materi complete, progress, quiz submit, sertifikat generate
- Seed dev sudah menyediakan data dummy untuk `kelas`, `materi`, `quiz`, `sertifikat`, `screener`, `berita`
- Ada gap endpoint auth yang dipanggil mobile tetapi belum ada di backend:
  - `POST /api/auth/google`
  - `POST /api/auth/lupa-password`
  - `POST /api/auth/verifikasi-otp`
  - `POST /api/auth/reset-password`

## Matriks Kecocokan Mobile vs Backend (Current State)

| Fitur Mobile | Endpoint dari Mobile | Status Backend | Catatan |
|---|---|---|---|
| Register | `POST /api/auth/register` | `Ready` | Sudah ada |
| Login | `POST /api/auth/login` | `Ready` | Sudah ada |
| Guest Login | `POST /api/auth/guest` | `Ready` | Sudah ada |
| Login Google | `POST /api/auth/google` | `Missing` | Mobile memanggil endpoint ini |
| Lupa Password (request OTP) | `POST /api/auth/lupa-password` | `Missing` | Perlu minimal stub/dev flow |
| Verifikasi OTP | `POST /api/auth/verifikasi-otp` | `Missing` | Perlu store OTP sementara |
| Reset Password | `POST /api/auth/reset-password` | `Missing` | Perlu finalisasi reset |
| Berita list home | `GET /api/berita?limit=10` | `Partial` | Endpoint ada, tetapi pakai pagination (`page`, `per_page`) |
| List kelas | `GET /api/kelas` | `Ready` | Sudah ada |
| Detail kelas | `GET /api/kelas/{id}` | `Ready` | Sudah ada |
| Progress kelas | `GET /api/kelas/{id}/progress` | `Ready` | JWT required |
| Complete materi | `POST /api/materi/complete` | `Ready` | JWT required |
| Submit quiz | `POST /api/quiz/submit` | `Ready` | JWT required |
| Generate sertifikat | `POST /api/sertifikat/generate` | `Ready` | JWT required + syarat kelulusan |
| Screener | `GET /api/screener` | `Ready` | Sudah ada |

## Gap Utama yang Harus Ditutup (Agar Fitur Bisa Dieksekusi)

### P0 (Release/UAT Blocker)

- Tambah endpoint auth:
  - `POST /api/auth/lupa-password`
  - `POST /api/auth/verifikasi-otp`
  - `POST /api/auth/reset-password`
- Tentukan strategi OTP untuk `dev/staging`:
  - simpan di tabel DB (recommended), atau
  - simpan in-memory sementara (hanya dev, tidak stabil untuk multi-process)
- Standarkan response payload agar cocok dengan mobile (format `status/message/data`)
- Tambah test/smoke flow auth + forgot password

### P1 (UAT Stabilizer)

- Putuskan behavior `POST /api/auth/google`:
  - stub sementara (return `501` dengan pesan jelas), atau
  - implementasi minimal token verify (jika kredensial tersedia)
- Tambah dukungan query `limit` di `GET /api/berita` atau update mobile ke `per_page` (Done: alias `limit` -> `per_page`)
- Tambah endpoint healthcheck eksplisit (mis. `GET /api/health`) untuk smoke test
- Logging error backend minimum untuk endpoint auth/LMS

### P2 (Post-UAT Improvement)

- Rate limit endpoint auth sensitif
- Expiry OTP + attempt limit
- Audit/trace log untuk reset password
- Contract docs API (OpenAPI/Postman collection)

## Prinsip Implementasi (Pragmatis untuk UAT)

- Prioritaskan endpoint yang dibutuhkan mobile saat ini, bukan redesign auth total
- Gunakan implementasi aman minimum yang bisa di-upgrade
- Jangan ubah contract endpoint LMS yang sudah dipakai mobile jika tidak perlu
- Semua perubahan auth baru harus kompatibel dengan JWT flow existing

## Phase Eksekusi Backend

### Phase 1 - API Contract Alignment (START HERE)

Status: `Executed (Contract Finalized for Current Mobile + Google Stub Decision)`

Tujuan:

- Mengunci contract endpoint backend yang dipakai mobile
- Menandai endpoint mana yang `ready`, `missing`, `partial`
- Mencegah perubahan liar selama UAT prep

Checklist:

- [x] Audit endpoint backend existing vs route mobile
- [x] Identifikasi gap auth forgot password & google login
- [x] Finalkan keputusan `google login`: `stub` atau `implement`
- [x] Finalkan contract `forgot password` payload/response:
  - [x] `lupa-password`
  - [x] `verifikasi-otp`
  - [x] `reset-password`
- [x] Tambah dokumen contract ringkas per endpoint (di dokumen ini / `docs/`)

Output:

- Matriks endpoint final untuk UAT
- Keputusan implementasi `google login`
- Payload examples untuk auth reset flow

Keputusan final Phase 1:

- `POST /api/auth/google` memakai `stub` sementara dan mengembalikan `501` + pesan jelas (hindari `404` di mobile).
- Contract auth recovery dikunci kompatibel dengan mobile existing:
  - `verifikasi-otp` menerima `kode` (dan backend juga bisa menerima alias `otp`)
  - `reset-password` menerima `email`, `kode`, `password_baru`
- Response auth recovery dibuat kompatibel ganda:
  - `status` boolean + `pesan` (legacy mobile)
  - `message` + `data` (style baru)

### Phase 2 - Implementasi Auth Recovery (P0)

Status: `Executed (Implemented + Local Smoke Test Passed)`

Tujuan:

- Membuat flow `lupa password -> verifikasi otp -> reset password` berjalan di backend

Rencana implementasi (minimal viable):

1. Tambah model/tabel OTP reset password (recommended):
   - `email`
   - `otp_code`
   - `expired_at`
   - `is_used`
   - `attempt_count`
   - timestamps
2. Tambah endpoint `POST /api/auth/lupa-password`
   - validasi email
   - generate OTP
   - simpan OTP
   - pada dev/staging: kembalikan OTP di response debug (opsional, gated by env)
3. Tambah endpoint `POST /api/auth/verifikasi-otp`
   - validasi OTP + expiry + belum dipakai
   - return token reset sementara / session reset key
4. Tambah endpoint `POST /api/auth/reset-password`
   - validasi reset key / OTP verification
   - update password hash user
   - tandai OTP `used`
5. Tambah test manual/smoke path

Checklist:

- [x] Model OTP dibuat + migration dibuat
- [x] Endpoint `lupa-password` jalan
- [x] Endpoint `verifikasi-otp` jalan
- [x] Endpoint `reset-password` jalan
- [x] Error handling jelas (email tidak ada / OTP salah / expired)
- [x] Response shape konsisten dengan endpoint auth existing

Acceptance criteria:

- User mobile bisa menyelesaikan flow forgot password di staging tanpa edit manual DB

### Phase 3 - Auth Compatibility & UX Support (P1)

Status: `In Progress (Google Stub + Password Min Length Applied)`

Tujuan:

- Menghindari error mobile pada endpoint auth tambahan dan memperjelas fallback

Checklist:

- [x] `POST /api/auth/google` diputuskan:
  - [ ] implement minimal, atau
  - [x] stub `501` + pesan jelas untuk mobile
- [ ] Tambah logging auth errors minimum
- [x] Tambah validasi password minimum (panjang, dsb.)
- [ ] Pastikan register/login/guest tetap lolos regresi

Acceptance criteria:

- Mobile tidak crash/terjebak state untuk tombol login Google / fallback error message terbaca

### Phase 4 - LMS + Home Data Readiness (P0/P1)

Status: `In Progress (Local End-to-End Flow Verified)`

Tujuan:

- Memastikan data dan endpoint untuk flow inti belajar konsisten untuk UAT

Checklist:

- [x] Verifikasi seed dev menghasilkan data:
  - `berita`
  - `kelas`
  - `modul`
  - `materi`
  - `quiz`
  - `sertifikat`
  - `screener`
- [x] Tambah dukungan `limit` di `GET /api/berita` atau dokumentasikan `per_page` (alias `limit` -> `per_page`)
- [x] Verifikasi flow JWT:
  - `register/login/guest` -> token
  - token dipakai ke progress/quiz/sertifikat
- [x] Verifikasi eligibility sertifikat (nilai >= 70 + semua materi/quiz selesai)
- [ ] Pastikan error message untuk unauthorized/expired token bisa ditangani mobile

Acceptance criteria:

- Flow `auth -> kelas -> materi complete -> quiz submit -> progress -> sertifikat` berhasil end-to-end

### Phase 5 - Smoke Test & UAT Backend Gate

Status: `In Progress (Local Smoke Test Passed, Staging Run Pending)`

Tujuan:

- Membuat gate backend sebelum UAT mobile dimulai

Checklist smoke test minimum:

- [x] `GET /` -> 200
- [x] `POST /api/auth/register` -> 201 + token
- [x] `POST /api/auth/login` -> 200 + token
- [x] `POST /api/auth/guest` -> 200 + token
- [x] `POST /api/auth/lupa-password` -> 200
- [x] `POST /api/auth/verifikasi-otp` -> 200
- [x] `POST /api/auth/reset-password` -> 200
- [x] `GET /api/berita` -> 200 + items
- [x] `GET /api/kelas` -> 200 + list
- [x] `GET /api/kelas/{id}` -> 200 + detail
- [x] `GET /api/kelas/{id}/progress` (JWT) -> 200
- [x] `POST /api/materi/complete` (JWT) -> 200
- [x] `POST /api/quiz/submit` (JWT) -> 200
- [x] `POST /api/sertifikat/generate` (JWT, after pass criteria) -> 200
- [x] `GET /api/screener` -> 200

Output:

- Checklist smoke test terisi
- Catatan bug backend (`High/Medium/Low`)
- Keputusan siap UAT mobile atau belum

## Payload Contract Draft (Auth Recovery)

Draft ini untuk sinkronisasi backend-mobile. Sesuaikan bila UI butuh field berbeda, tetapi kunci sebelum implementasi.

### `POST /api/auth/lupa-password`

Request:

```json
{
  "email": "user@example.com"
}
```

Response sukses (staging/dev):

```json
{
  "status": "success",
  "message": "OTP berhasil dikirim",
  "data": {
    "email": "user@example.com",
    "expires_in_seconds": 300,
    "otp_debug": "123456"
  }
}
```

### `POST /api/auth/verifikasi-otp`

Request:

```json
{
  "email": "user@example.com",
  "kode": "123456"
}
```

Response sukses:

```json
{
  "status": "success",
  "message": "OTP valid",
  "data": {
    "email": "user@example.com",
    "verified": true
  }
}
```

### `POST /api/auth/reset-password`

Request:

```json
{
  "email": "user@example.com",
  "kode": "123456",
  "password_baru": "PasswordBaru123"
}
```

Response sukses:

```json
{
  "status": "success",
  "message": "Password berhasil diubah",
  "data": null
}
```

## Rekomendasi Teknis Implementasi (Minimal Risiko)

- Simpan OTP di DB (`Flask-SQLAlchemy`) agar aman untuk `gunicorn` multi worker
- Gunakan TTL pendek (5-10 menit)
- Hash OTP di DB jika ingin lebih aman; untuk staging MVP boleh plaintext sementara + catatan hardening
- Contract final saat ini memakai `kode` untuk kompatibilitas mobile existing (bisa di-upgrade ke `reset_token` pada fase hardening berikutnya)
- Bungkus `otp_debug` hanya untuk `development/staging` via env flag

## Risiko & Mitigasi

Risiko:

- Mobile sudah memanggil endpoint auth yang belum ada -> error UAT
- Implementasi OTP terlalu cepat tetapi tidak aman/stabil
- Perubahan auth merusak login/register existing
- Contract mismatch field name (`otp`, `code`, `password_baru`) menyebabkan integrasi gagal

Mitigasi:

- Kunci contract dulu (Phase 1) sebelum coding
- Tambah smoke test manual untuk semua auth endpoint
- Jaga endpoint existing tetap backward compatible
- Gunakan env flag untuk behavior debug OTP

## Tracking Eksekusi (Backend)

| Item | Priority | Status | PIC | Catatan |
|---|---|---|---|---|
| Finalkan contract auth recovery | P0 | Done | TBD | Contract final + kompatibel mobile existing |
| Implement `lupa-password` | P0 | Done | TBD | Endpoint + OTP store berjalan |
| Implement `verifikasi-otp` | P0 | Done | TBD | Endpoint validasi OTP berjalan |
| Implement `reset-password` | P0 | Done | TBD | Update password hash + OTP mark used |
| Keputusan `google login` (stub/real) | P1 | Done (Stub 501) | TBD | Hindari endpoint 404 |
| Dukungan `limit` berita / alignment query | P1 | Done | TBD | `limit` alias ke `per_page` di backend |
| Smoke test backend feature set | P0 | In Progress | TBD | Lulus lokal 26 Feb 2026, perlu run di staging |

## Catatan Eksekusi

- Mulai dari `Phase 1` dan `Phase 2` terlebih dulu karena itu blocker paling nyata dari audit route mobile.
- Setelah auth recovery jalan, flow LMS kemungkinan besar sudah bisa dieksekusi karena endpoint dan seed datanya sudah tersedia.
- Update 26 Feb 2026 (lokal): smoke test `scripts/backend_smoke_auth_lms.py` lulus untuk register/login, auth recovery OTP, berita, screener, flow LMS progress, dan generate sertifikat. Verifikasi `POST /api/auth/guest` juga lulus (`200` + token) via cek manual lokal.
