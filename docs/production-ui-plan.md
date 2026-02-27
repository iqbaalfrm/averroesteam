# Production UI Improvement Plan (Mobile)

## Tujuan

Rencana production untuk meningkatkan kualitas UI mobile Averroes agar:

- lebih rapi, konsisten, dan layak rilis
- terasa intentional (bukan template generik / "AI slop")
- tetap stabil dan realistis dikerjakan bertahap

## Prinsip Utama (Anti AI Slop)

UI improvement wajib mengikuti prinsip ini:

- Satu arah visual yang jelas per release (jangan campur banyak gaya)
- Hierarki visual tegas (judul, subjudul, CTA, info sekunder)
- Spacing konsisten berbasis scale (mis. 4/8/12/16/24)
- Warna punya fungsi (brand, status, surface, text), bukan dekorasi random
- Komponen reusable sebelum menambah variasi baru
- State lengkap: `loading`, `empty`, `error`, `success`
- Konten nyata > placeholder generik
- Interaksi terasa sengaja (feedback tap, disabled state, progress)

Hal yang harus dihindari:

- Card + shadow + gradient generik di semua screen
- Terlalu banyak warna aksen tanpa sistem
- Typography acak per halaman
- CTA tidak jelas prioritasnya
- Layout "tempelan" tanpa alignment yang rapi
- Animasi ramai tapi tidak membantu task user

## Scope Fokus (Mobile UI)

Prioritas UI difokuskan ke flow utama belajar (V1):

1. `login`
2. `register`
3. `home/beranda`
4. `edukasi` (list kelas, detail, materi, quiz)
5. `sertifikat`
6. `profile`

Screen lain masuk fase berikutnya:

- `screener`, `pasar`, `portofolio`, `notifikasi`
- `chatbot`, `reels`, `diskusi`, `psikolog`, `konsultasi`
- `zakat`, `zikir`, `pustaka`, `bantuan`

## Output Production UI (Definition of Done)

Sebuah screen dianggap selesai jika:

- Visual konsisten dengan style guide terbaru
- Tidak ada overflow/layout pecah di device kecil umum
- Ada state `loading/empty/error` yang jelas
- CTA utama terlihat dalam 1-2 detik scan
- Kontras teks cukup (readability)
- Spacing dan alignment rapi
- Respons interaksi jelas (tap, disabled, success/error feedback)

## Phase Eksekusi (UI-First)

### Phase 1 - UI Direction & Design Freeze

Status: `Executed (Draft Freeze V1 - Need Team Confirmation)`

Tujuan:

- Menentukan arah visual tunggal untuk release ini
- Freeze style dasar sebelum redesign banyak screen

Checklist (status eksekusi saat ini):

- [x] Pilih tema visual (draft: `Calm Learning + Islamic Fintech`)
- [x] Tetapkan design tokens:
  - [x] color palette
  - [x] typography scale
  - [x] spacing scale
  - [x] radius & border style
  - [x] elevation/shadow rules
- [x] Tentukan pola komponen inti:
  - [x] primary button
  - [x] secondary button
  - [x] input field
  - [x] card
  - [x] app bar
  - [x] bottom navigation
- [x] Freeze aturan visual (draft freeze V1 dibuat, finalisasi tim diperlukan)

Deliverables:

- [x] `UI style guide` singkat: `docs/ui-style-guide-v1.md`
- [ ] Contoh 1 screen referensi final (home atau login)

Temuan Phase 1 (current app):

- [x] Theme dasar sudah punya arah visual yang layak (`emerald/sand/slate`) di `packages/core/lib/theme/app_theme.dart`
- [x] Token warna dasar sudah ada di `packages/core/lib/constants/app_colors.dart`
- [x] Font utama sudah konsisten `Plus Jakarta Sans` pada theme
- [x] Beberapa screen (contoh `login`, `home`) sudah punya karakter visual, tetapi masih banyak warna/style hardcoded per screen
- [x] Risiko inkonsistensi tinggi jika redesign langsung screen-by-screen tanpa freeze token/komponen

Keputusan design freeze V1 (draft):

- [x] Pertahankan arah warna `emerald + sand + slate`
- [x] Pertahankan font `Plus Jakarta Sans`
- [x] Gunakan spacing scale tetap (`4/8/12/16/20/24/32`)
- [x] Batasi shadow berat, lebih banyak border + kontras surface
- [x] Fokus V1 pada kualitas flow utama, bukan dekorasi berlebih

### Phase 2 - UI Audit Screen Prioritas (Current State)

Status: `Executed (Initial Audit - P1 Screens)`

Tujuan:

- Memetakan masalah UI nyata per screen, bukan redesign membabi buta

Checklist audit per screen:

- [x] Hierarki teks jelas?
- [x] CTA utama jelas?
- [x] Spacing/alignment konsisten?
- [x] Komponen konsisten dengan screen lain?
- [x] State `loading/empty/error` ada?
- [x] Readability bagus di layar kecil?
- [x] Terlalu ramai / terlalu kosong?
- [x] Copywriting jelas dan tidak generik?

Output:

- [x] Daftar masalah `High / Medium / Low` per screen (audit awal)
- [x] Prioritas redesign 1 sprint (draft)

Hasil audit awal (P1 screens):

Temuan umum lintas screen:

- [x] Banyak warna hardcoded di screen prioritas (`login`, `register`, `home`, `profile`, `sertifikat`) -> konsistensi sulit dijaga
- [x] Typography belum konsisten (campuran `Plus Jakarta Sans` dan `Inter`)
- [x] Komponen berulang belum terpusat (icon button, card, form field, snackbar style)
- [x] `edukasi` dan sebagian `home` sudah punya state `loading/empty/error` yang cukup baik (fondasi bagus)

Temuan per screen (ringkas):

- `Login` (`apps/mobile/lib/modules/login/login_page.dart`)
  - `Medium`: visual cukup matang, tetapi banyak hardcoded color dan komponen auth belum reusable
  - `Low`: spacing sudah baik namun belum mengikuti sistem global secara eksplisit
- `Register` (`apps/mobile/lib/modules/register/register_page.dart`)
  - `High`: mirip `login` tapi implementasi terpisah (risiko drift visual/UX)
  - `Medium`: banyak hardcoded color/shadow/radius dan avatar/logo via network image tanpa fallback visual jelas
- `Home/Beranda` (`apps/mobile/lib/modules/home/beranda_page.dart`)
  - `High`: visual density tinggi (gradient/badge/shadow/card style beragam) -> risiko ramai dan CTA kurang fokus
  - `High`: hardcoded styling sangat banyak -> maintenance mahal
  - `Medium`: fondasi hierarchy bagus, tapi perlu standardisasi card pattern
- `Edukasi List/Detail` (`apps/mobile/lib/modules/edukasi/edukasi_page.dart`, `apps/mobile/lib/modules/edukasi/kelas_detail_page.dart`)
  - `Medium`: paling siap dijadikan basis UI system data-driven
  - `Medium`: `_ErrorCard`/`_EmptyCard` dan beberapa komponen masih lokal (belum reusable)
- `Quiz` (`apps/mobile/lib/modules/edukasi/kuis_page.dart`)
  - `Medium`: flow usable dan CTA jelas, tapi feedback sukses/gagal masih generik
  - `Low`: hierarchy progress vs daftar soal bisa diperjelas
- `Sertifikat` (`apps/mobile/lib/modules/sertifikat/sertifikat_page.dart`)
  - `High`: dekorasi cukup berat + banyak data statis -> terasa seperti demo jika tidak disederhanakan
  - `High`: typography/palette berbeda dari freeze V1 (`Inter` + warna lokal)
  - `Medium`: belum terlihat state data-driven list utama (`loading/empty/error`)
- `Profile` (`apps/mobile/lib/modules/profile/profile_page.dart`)
  - `High`: typography dan palette menyimpang dari theme V1, hardcoded color sangat banyak
  - `Medium`: hero dan cards ekspresif tapi visual density tinggi

Prioritas redesign 1 sprint (draft):

1. `Auth system`: `login + register` (shared components + tokenization)
2. `Edukasi system`: `edukasi + quiz` (state components reusable)
3. `Home` cleanup pass (reduce density + standardize card patterns)
4. `Profile` alignment pass (typography + palette + spacing)
5. `Sertifikat` simplification pass (less decoration + state readiness)

Backlog temuan severity:

High:

- [ ] Inkonsistensi typography/palette antar screen prioritas
- [ ] Hardcoded colors berlebih (terutama `home`, `profile`, `sertifikat`)
- [ ] `login`/`register` belum berbagi sistem komponen auth
- [ ] `sertifikat` terasa terlalu dekoratif dan masih demo-like

Medium:

- [ ] Komponen state (`loading/empty/error`) belum distandarkan lintas screen
- [ ] Duplikasi `icon button`, `card`, `snackbar` style di banyak screen
- [ ] Visual density `home`/`profile` perlu diturunkan
- [ ] Feedback success/error beberapa flow masih generik

Low:

- [ ] Minor spacing drift pada auth screens
- [ ] Beberapa copy bisa dibuat lebih spesifik
- [ ] Cleanup lint/style warnings existing saat UI polish pass

### Phase 3 - Component System Refactor (Minimal, Production-Oriented)

Status: `In Progress (Auth + Edukasi Common Components Started)`

Tujuan:

- Mengurangi inkonsistensi UI lewat komponen reusable
- Hindari rewrite besar yang berisiko

Fokus:

- [x] Komponen tombol (auth baseline)
- [x] Komponen input/form field (auth baseline)
- [x] Komponen section header
- [ ] Komponen card/list item
- [x] Komponen state view (`loading`, `empty`, `error`) [baseline edukasi]
- [x] Token warna/spacing/typography terpusat (auth pass mulai memakai `AppColors` + helper)

Aturan implementasi:

- Refactor bertahap, screen-by-screen
- Jangan ubah logic bisnis jika tidak perlu
- Setiap perubahan UI harus tetap lolos flow fungsional

Progress implementasi saat ini:

- [x] Tambah shared auth UI helper `apps/mobile/lib/presentation/common/auth_ui_kit.dart`
- [x] Standarisasi snackbar auth (`login/register`) melalui helper
- [x] Standarisasi input decoration auth (`login/register`)
- [x] Standarisasi primary/secondary auth button style (baseline)
- [x] Tambah fallback visual untuk brand image pada auth (mengurangi risiko broken image)
- [x] Mulai migrasi warna auth ke token `AppColors`
- [x] Ekstrak reusable content UI components:
  - [x] `AppSectionHeader`
  - [x] `AppEmptyStateCard`
  - [x] `AppErrorStateCard`
  - [x] File: `apps/mobile/lib/presentation/common/content_ui.dart`
- [x] Terapkan komponen reusable ke `edukasi_page.dart` (section + state cards)

### Phase 4 - Screen Redesign (Prioritas V1)

Status: `In Progress (Auth + Home Cleanup Pass V2 + Edukasi/Profile Baseline Passes)`

Urutan eksekusi yang disarankan:

1. `login` + `register`
2. `home/beranda`
3. `edukasi` (list + detail)
4. `quiz`
5. `sertifikat`
6. `profile`

Checklist implementasi per screen:

- [x] Terapkan style guide (auth screens baseline)
- [x] Rapikan layout grid/spacing (home pass baseline)
- [x] Perjelas CTA utama & sekunder (auth screens dipertahankan/dirapikan)
- [x] Tambahkan state visual lengkap (auth loading/error sudah ada; distandarkan snackbar)
- [x] Review copy text (tone & clarity) [home berita state copy baseline]
- [ ] Uji di small screen + medium screen
- [ ] Uji dark/light jika didukung (jika tidak, pastikan konsisten satu mode)

### Phase 5 - UX Polish (No Slop Pass)

Tujuan:

- Final pass untuk memastikan UI terasa "designed", bukan auto-generated

Checklist polish:

- [ ] Konsistensi icon style
- [ ] Konsistensi radius/shadow/border
- [ ] Konsistensi alignment antar section
- [ ] Empty state punya pesan spesifik (bukan "No data")
- [ ] Error state membantu user langkah berikutnya
- [ ] Skeleton/loading sesuai bentuk konten
- [ ] Micro interaction secukupnya (tap feedback, progress, disabled)
- [ ] Hapus elemen dekoratif yang tidak menambah fungsi

### Phase 6 - Production QA UI & Release Gate

Release gate UI (harus lolos sebelum publish):

- [ ] Tidak ada overflow/render error di flow utama
- [ ] Tidak ada screen dengan style lama yang bentrok parah dengan style baru
- [ ] Kontras teks dan tombol cukup terbaca
- [ ] Form auth usable (validasi, error message, disabled state)
- [ ] Edukasi/quiz/sertifikat nyaman dipakai end-to-end
- [ ] Review visual oleh minimal 2 orang (bukan pembuat screen)

## Rubrik Review UI (Anti AI Slop Score)

Nilai tiap screen dari 1-5:

- `Visual Direction`: terasa punya identitas visual?
- `Hierarchy`: CTA dan informasi utama langsung terbaca?
- `Consistency`: selaras dengan screen lain?
- `Usability`: mudah dipakai tanpa kebingungan?
- `State Quality`: loading/empty/error/success jelas?
- `Craft`: alignment, spacing, copy, detail terasa rapi?

Interpretasi:

- `24-30`: siap production
- `18-23`: layak beta, perlu polish
- `<18`: jangan rilis, redesign ulang bagian inti

## Prioritas Perbaikan Cepat (Quick Wins)

Paling efektif untuk menaikkan kualitas UI cepat:

1. Standarisasi tombol + input + spacing
2. Rapikan hierarki typography di auth/home/edukasi
3. Tambah state `loading/empty/error` yang proper
4. Perjelas CTA utama pada screen padat
5. Hapus ornamen visual yang tidak membantu

## Risiko & Guardrail

Risiko:

- Redesign terlalu luas -> release molor
- Fokus visual tapi merusak flow fungsional
- Inkonsistensi karena banyak screen dikerjakan paralel tanpa style guide

Guardrail:

- Kerjakan berdasarkan phase dan prioritas screen
- Review visual per PR menggunakan rubrik
- Batasi eksperimen hanya pada 1-2 screen dulu, lalu scale
- Pisahkan bug UI vs bug API/backend saat QA

## Template Tracking (Per Screen)

Gunakan template ini untuk tracking eksekusi:

| Screen | Priority | Status | Problem Utama | Action | Reviewer | Score |
|---|---|---|---|---|---|---|
| Login | P1 | In Progress (V1 Pass) | Hardcoded color + auth components belum reusable | Shared auth components + tokenisasi (baseline diterapkan) | TBD | - |
| Register | P1 | In Progress (V1 Pass) | Drift visual vs login + hardcoded style | Satukan auth system + fallback asset (baseline diterapkan) | TBD | - |
| Home/Beranda | P1 | In Progress (Cleanup Pass V2) | Visual density tinggi + style terlalu beragam | Section header + state cards + tokenisasi `KartuJadwalShalat`/`KartuPortofolio` (baseline diterapkan) | TBD | - |
| Edukasi List | P1 | In Progress (System Pass Baseline) | State cards lokal + token belum penuh | Ekstrak reusable section/state components + apply ke page | TBD | - |
| Edukasi Detail | P1 | Audited | Komponen state & cards belum reusable | Standardisasi komponen data-driven | TBD | - |
| Quiz | P1 | Audited | Feedback generik + style belum seragam | Align dengan system edukasi | TBD | - |
| Sertifikat | P1 | Audited | Terlalu dekoratif + data statis | Simplification + state readiness | TBD | - |
| Profile | P1 | In Progress (Alignment Pass Baseline) | Typography/palette menyimpang + density tinggi | Align font ke `Plus Jakarta Sans`, token warna inti, spacing/card shell baseline | TBD | - |

## Catatan Eksekusi

- Fokus production UI bukan membuat semua screen "wah", tetapi membuat flow utama terasa matang, konsisten, dan enak dipakai.
- Kualitas UI naik cepat jika tim disiplin pada sistem (token + komponen + review), bukan redesign acak per halaman.
