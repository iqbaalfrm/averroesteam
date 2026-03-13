# Yang Belum Dikerjakan - Proyek Averroes

Tanggal cek: 13 Maret 2026  
Sumber: audit repo saat ini + `docs/production-plan.md` + `docs/production-ui-plan.md` + `docs/backend-feature-execution-plan.md`

## Catatan Penting (Status Dokumen vs Kode)

- Dokumen backend masih menandai beberapa item auth recovery sebagai `Planned`, tetapi implementasi sudah ada di `apps/backend/app/api/auth.py`:
  - `POST /api/auth/lupa-password`
  - `POST /api/auth/verifikasi-otp`
  - `POST /api/auth/reset-password`
  - `POST /api/auth/google` (stub `501`)
- Artinya, ada pekerjaan dokumentasi/status tracking yang belum disinkronkan.

## Progress Eksekusi (26 Feb 2026)

- [x] Smoke test backend lokal lulus (`scripts/backend_smoke_auth_lms.py`) + verifikasi `POST /api/auth/guest`
- [x] Sinkronisasi status dokumen backend (`docs/backend-feature-execution-plan.md`)
- [x] Runbook build/UAT mobile dibuat di `apps/mobile/README.md`
- [x] Audit cepat UX state screen kritikal dibuat di `docs/mobile-ux-audit-quick-2026-02-26.md`

## Prioritas Utama yang Masih Belum Selesai (Blocker Menuju UAT/Release)

### 1. Konfigurasi Environment & Release Mobile

- Tetapkan `API_BASE_URL` staging untuk UAT dan production untuk rilis (`docs/production-plan.md`).
- Finalisasi file env release (staging/production) dan validasi dipakai saat build.
- Dokumentasikan langkah build + UAT mobile (saat ini `apps/mobile/README.md` masih belum jadi runbook QA/UAT).

### 2. Audit UX Screen Kritis (Mobile)

- Audit state `loading / empty / error` pada flow kritikal.
- Audit fallback UX saat backend down/timeout.
- Verifikasi form auth benar-benar usable (validasi, error message, disabled state).
- Uji end-to-end edukasi/quiz/sertifikat untuk kenyamanan dan kejelasan state.

### 3. UAT & Hotfix

- `Phase 3 - UAT & Hotfix Mobile` masih `Pending`.
- `Phase 4 - Go Live Mobile` masih `Pending`.
- `Phase 5 - Upgrade & Evaluasi Fitur Mobile` masih `Pending`.

## Pekerjaan UI yang Masih Tersisa (Production UI Plan)

### Sistem UI / Konsistensi

- Komponen card/list item reusable belum selesai.
- Konsistensi icon style, radius/shadow/border, dan alignment antar section.
- Standardisasi komponen state (`loading/empty/error`) lintas screen.
- Kurangi duplikasi style (`icon button`, `card`, `snackbar`) di banyak screen.
- Cleanup lint/style warnings existing saat UI polish pass.

### Kualitas UX per Screen

- `login` / `register` belum sepenuhnya berbagi sistem komponen auth.
- `home` / `profile` masih perlu penurunan visual density.
- `sertifikat` masih terasa demo-like / terlalu dekoratif.
- Feedback success/error beberapa flow masih generik.
- Empty state dan error state perlu copy yang lebih spesifik dan membantu.
- Skeleton/loading perlu disesuaikan bentuk konten.

### QA UI / Release Gate (Belum Lolos)

- Belum diverifikasi bebas overflow/render error di flow utama.
- Belum dipastikan tidak ada bentrok style lama vs baru.
- Belum ada review visual minimal 2 orang.
- Belum ada penilaian rubrik final per screen (score masih `-` / reviewer `TBD`).

## Pekerjaan Backend yang Masih Tersisa

### Verifikasi & Smoke Test (Staging Masih Perlu)

- Smoke test backend sudah lulus di lokal (26 Feb 2026), tetapi masih perlu dijalankan terhadap environment staging dan hasilnya dicatat.
- Verifikasi seed data dev + flow JWT + eligibility sertifikat masih tercatat sebagai checklist belum selesai di dokumen.

### Penyelarasan Contract / API Minor

- Dukungan `limit` untuk berita: **Selesai di backend** (alias `limit` -> `per_page`), tinggal sinkronisasi dokumen/mobile bila diperlukan.
- Error message unauthorized/expired token perlu dipastikan mudah ditangani di mobile (masih checklist dokumen).

### Hardening Auth (Dokumen Belum Ditutup)

- Logging auth errors minimum (masih checklist dokumen).
- Review konsistensi response shape auth (dokumen masih open, walau implementasi sudah ada).
- Verifikasi regresi `register/login/guest` pasca perubahan auth recovery.

## Pekerjaan Operasional / Production (Banyak yang Masih Template)

Mayoritas checklist di `docs/production-plan.md` masih belum dikerjakan/diisi, terutama:

- Env production backend (`APP_ENV`, `SECRET_KEY`, `JWT_SECRET_KEY`, `DATABASE_URL`, `UPLOAD_FOLDER`).
- Setup DB production + migrasi + backup/restore test.
- Setup process manager (`systemd`) + reverse proxy (`Nginx/Caddy`) + HTTPS.
- Hardening (CORS, rate limit, admin access restriction).
- Monitoring/logging/alerting dan SOP insiden.
- Build release mobile (Android/iOS), versioning, dan UAT internal final.

## Tugas Manajerial/Koordinasi yang Belum Diisi

- Tanggal freeze fitur masih `TBD`.
- PIC mobile / QA-UAT / approval masih `TBD`.
- PIC backend / infra / release approval pada rencana tanggung jawab masih `TBD`.
- Reviewer UI dan score review per screen masih `TBD` / belum diisi.

## Rekomendasi Urutan Kerja Berikutnya (Singkat)

1. Finalkan `API_BASE_URL` staging + runbook UAT mobile.
2. Jalankan smoke test backend (`scripts/backend_smoke_auth_lms.py`) dan update status dokumen backend.
3. Audit UX state screen kritikal (auth, home, edukasi, quiz, sertifikat).
4. Tutup checklist UI release gate.
5. Finalisasi checklist production ops + PIC + timeline freeze.
