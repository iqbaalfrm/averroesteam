# Audit Restrukturisasi Monorepo (26 Feb 2026)

Tujuan audit:
- Memastikan migrasi dari struktur lama `averroes/` ke struktur baru `apps/`, `packages/`, `docs/` aman sebelum commit finalisasi restrukturisasi.

## Ringkasan Status

- Git masih menganggap struktur lama sebagai baseline (242 file `D`).
- Struktur baru (`apps/`, `packages/`, `docs/`) masih `untracked` karena belum ada commit baseline restrukturisasi.
- Audit mapping mobile menunjukkan migrasi fungsional sudah lengkap.

## Hasil Audit Mapping (Legacy Mobile -> Monorepo Baru)

Perbandingan otomatis:
- Sumber lama:
  - `averroes/mobile/averroes_app/*`
  - `averroes/mobile/packages/*`
- Target baru:
  - `apps/mobile/*`
  - `packages/*`

Hasil:
- Legacy mobile app files: `182`
- Legacy mobile package files: `12`
- New mobile files: `161`
- New package files: `8`
- File mapped yang tidak ada di struktur baru: `28`

### 28 File yang Tidak Termigrasi (Non-Kritis)

Mayoritas hanya file scaffold/placeholder:
- `.gitkeep` (folder kosong)
- `.gitignore` per-platform Flutter scaffold
- `.metadata` Flutter lokal

Kesimpulan:
- Tidak ada indikasi file source code inti mobile yang hilang.

### File Baru di Struktur Baru (Improvement)

File baru yang memang tidak ada di legacy:
- `apps/mobile/lib/app/services/api_dio.dart`
- `apps/mobile/lib/presentation/common/auth_ui_kit.dart`
- `apps/mobile/lib/presentation/common/content_ui.dart`

Kesimpulan:
- Ini adalah improvement valid, bukan mismatch migrasi.

## Backend: Perubahan Arsitektur (Bukan Sekadar Pindah Folder)

Legacy backend yang dihapus adalah backend Go (`averroes/backend/*`, 46 file tracked).

Struktur baru memakai backend Python/Flask (`apps/backend/*`), sehingga tidak ada mapping 1:1 file-to-file dan itu **wajar**.

Kategori legacy backend yang terhapus:
- Go modules (`go.mod`, `go.sum`)
- API handlers/services Go
- Dockerfile backend Go
- Seeder/database util Go

Kesimpulan:
- Penghapusan `averroes/backend/*` adalah perubahan arsitektur yang disengaja (Go -> Python), bukan kehilangan file migrasi.

## Risiko / Keputusan yang Perlu Dikonfirmasi

### 1. CSV legacy backend

Legacy files yang terdeteksi:
- `averroes/backend/docs/CSV Averroes.csv`
- `averroes/backend/docs/CSV_Averroes.csv`

Di struktur baru saat ini tidak terlihat file CSV serupa (yang ada hanya Postman collection di `docs/postman/`).

Status:
- `Perlu keputusan eksplisit`

Pilihan:
1. `Archive` ke `docs/archive/legacy-data/` jika masih berguna untuk referensi
2. `Drop` jika data sudah tidak dipakai / sudah terserap seed baru
3. `Port` ke `apps/backend` jika masih dibutuhkan untuk seed/import

### 2. Folder legacy root `averroes/` masih ada di filesystem

Saat audit, folder `averroes/` masih ada tetapi hanya menyisakan `averroes/mobile/` (dengan isi sudah terhapus dari Git perspective).

Status:
- Aman dihapus setelah commit finalisasi restrukturisasi, **jika** item CSV di atas sudah diputuskan.

## Rekomendasi Finalisasi Restrukturisasi (Langkah Praktis)

1. Putuskan nasib dua file CSV legacy (`archive/drop/port`).
2. Commit baseline restrukturisasi monorepo:
   - delete legacy `averroes/*`
   - add `apps/*`, `packages/*`, `docs/*`
3. Setelah commit baseline, lanjutkan cleanup/feature work pada commit terpisah.

## Keputusan Audit (Sementara)

- `GO` untuk finalisasi restrukturisasi monorepo, dengan satu catatan:
  - selesaikan keputusan file CSV legacy terlebih dulu.
