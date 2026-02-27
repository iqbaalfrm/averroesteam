# Clean Code / Clean Repo Checklist (Averroes)

Tanggal mulai: 26 Februari 2026

Dokumen ini fokus pada kebersihan codebase dan repository, terpisah dari backlog fitur.

## Tujuan

- Repo mudah dipahami setelah restrukturisasi monorepo (`apps/`, `packages/`, `docs/`)
- Noise commit berkurang (artefak build/temp/log tidak ikut)
- Dokumentasi status sinkron dengan implementasi
- Screen/flow kritikal punya kualitas kode dan UX baseline yang konsisten

## Baseline yang Sudah Dikerjakan (26 Feb 2026)

- [x] Tambah `.editorconfig` (UTF-8, LF, newline final, indent konsisten)
- [x] Tambah `.gitattributes` (normalisasi line ending + binary files)
- [x] Rapikan `.gitignore` (cache Python, coverage, log/temp)
- [x] Hilangkan metadata template Flutter web (`apps/mobile/web/index.html`, `apps/mobile/web/manifest.json`)
- [x] Sync dokumen backend dengan implementasi auth recovery + smoke test lokal
- [x] Tambah runbook mobile (`apps/mobile/README.md`)
- [x] Tambah scaffold `apps/web` (framework-agnostic) + `README.md` + struktur `src/public/tests`

## Clean Repo (Prioritas)

### 1. Finalisasi Restrukturisasi Monorepo

Status repo saat audit: banyak file `D` dari folder lama `averroes/` dan folder baru `apps/`, `packages/`, `docs/` belum jadi baseline commit.

Checklist:

- [ ] Konfirmasi bahwa folder legacy `averroes/` memang akan dihapus penuh (setelah keputusan CSV legacy)
- [x] Pastikan semua file penting mobile dari `averroes/` sudah termigrasi ke struktur baru [audit 26 Feb 2026, mismatch hanya `.gitkeep`/`.gitignore`/`.metadata`]
- [ ] Putuskan nasib file legacy CSV (`archive/drop/port`) berdasarkan audit `docs/monorepo-restructure-audit-2026-02-26.md`
- [ ] Buat 1 commit khusus “repo restructure” (tanpa campur fitur lain)
- [ ] Setelah commit, targetkan `git status` bersih sebelum lanjut cleanup fitur

### 2. Hilangkan Sisa Template / Placeholder

- [ ] Ganti `com.example.averroes_app` (Android namespace/applicationId) ke ID final
- [ ] Konfigurasi signing release Android (hapus TODO build.gradle saat siap)
- [ ] Review copy placeholder/demo di screen non-kritikal
- [ ] Isi `TBD` penting pada dokumen release (PIC, freeze date, owner)

### 3. Konsistensi Dokumentasi

- [ ] Tetapkan satu sumber kebenaran status eksekusi (mis. `docs/yang-belum-dikerjakan-averroes.md`)
- [ ] Sinkronkan `production-plan`, `production-ui-plan`, dan progress aktual mingguan
- [ ] Catat hasil smoke test staging (tanggal + environment + hasil)

## Clean Code (Prioritas)

### 1. Error Handling & UX State (Flow Kritis)

- [ ] Standarkan mapping error `timeout/network/401/5xx` pada mobile
- [ ] Tambah CTA retry/login ulang saat token expired
- [ ] Lengkapi state `loading/empty/error` untuk screen `Sertifikat` (masih demo)
- [ ] Audit manual di device kecil/sedang untuk overflow/layout

### 2. Reusability UI Components

- [ ] Satukan komponen auth (`login/register/lupa password`) lebih jauh
- [ ] Standardisasi state cards (`loading/empty/error`) lintas screen
- [ ] Kurangi duplikasi style card/button/snackbar

### 3. Kualitas Kode & Tooling

- [ ] Jalankan `flutter analyze` full app dan kelompokkan warning existing
- [ ] Jalankan formatter pada file yang diubah (`dart format`, formatter Python bila diperlukan)
- [ ] Tambah/rapikan smoke test command yang terdokumentasi untuk backend + mobile

## Aturan Eksekusi Cleanup (Supaya Repo Tetap Rapi)

- Pisahkan commit berdasarkan jenis:
  - `repo hygiene`
  - `docs sync`
  - `ux/state fixes`
  - `feature work`
- Hindari campur refactor besar dengan perubahan behavior dalam 1 commit
- Update dokumen status setiap kali blocker utama tertutup
