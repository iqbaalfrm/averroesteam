# Audit Cepat UX State Mobile (26 Feb 2026)

Scope audit cepat:
- Auth (`login`, `register`, `lupa password`, `verifikasi OTP`)
- Home/Beranda
- Edukasi (`list`, `detail`, `quiz`)
- Sertifikat

Metode: audit kode statis (bukan test UI manual di device).

## Ringkasan

- `Home/Beranda` dan `Edukasi` sudah punya baseline state `loading/error/empty`.
- Auth flow sudah punya loading state tombol + snackbar feedback, tetapi masih ada gap UX pada tombol Google.
- `Quiz` sudah punya error card untuk progress, tapi loading progress belum terlihat jelas di UI.
- `Sertifikat` masih screen statis/demo (belum data-driven, belum ada `loading/empty/error`).

## Temuan Prioritas (High)

### 1. Screen Sertifikat masih statis/demo

File: `apps/mobile/lib/modules/sertifikat/sertifikat_page.dart`

Indikasi:
- Screen berupa `StatelessWidget` tanpa fetch API (`apps/mobile/lib/modules/sertifikat/sertifikat_page.dart:5`)
- Data sertifikat hardcoded (`apps/mobile/lib/modules/sertifikat/sertifikat_page.dart:54`)
- Search field hanya visual placeholder, bukan input aktif (`apps/mobile/lib/modules/sertifikat/sertifikat_page.dart:179`)

Dampak:
- Tidak siap untuk UAT end-to-end sertifikat nyata.
- Tidak ada state `loading/empty/error`.

Action:
- Ubah ke data-driven page (fetch daftar sertifikat user).
- Tambahkan state `loading`, `empty`, `error`, `retry`.
- Bedakan item eligible / generated / gagal dengan copy yang jelas.

### 2. Tombol Google login masih bergantung validasi form email+password

File: `apps/mobile/lib/modules/login/login_page.dart`

Indikasi:
- `_loginGoogle()` memanggil `_validateForm()` sebelum request Google (`apps/mobile/lib/modules/login/login_page.dart:54`)
- Form validator login biasanya menuntut password, sehingga UX tombol Google bisa gagal sebelum menampilkan pesan stub backend.

Dampak:
- User menekan Google Login bisa mendapat error validasi password yang tidak relevan.
- Menyulitkan validasi fallback UX untuk endpoint stub `501`.

Action:
- Pisahkan validasi untuk Google (minimal email saja, atau tanpa validasi jika backend stub).
- Tampilkan pesan fallback yang spesifik dari endpoint `501`.

## Temuan Prioritas (Medium)

### 3. Quiz: loading progress tidak terlihat eksplisit

File: `apps/mobile/lib/modules/edukasi/kuis_page.dart`

Indikasi:
- Ada state `_isLoadingProgress` (`apps/mobile/lib/modules/edukasi/kuis_page.dart:21`)
- State ini hanya mempengaruhi disable tombol submit (`apps/mobile/lib/modules/edukasi/kuis_page.dart:222`)
- Belum ada spinner/skeleton/card loading khusus saat progress sedang dimuat

Dampak:
- User tidak tahu apakah progress sedang dimuat atau layar hanya diam.

Action:
- Tampilkan loading card/skeleton di area progress saat `_isLoadingProgress == true`.
- Bedakan error progress vs error submit kuis.

### 4. Error/feedback masih generik di beberapa flow

File:
- `apps/mobile/lib/modules/edukasi/kuis_page.dart`
- auth screens (snackbar-only)

Indikasi:
- Banyak fallback message generik (`Terjadi kesalahan`, `Gagal ...`) tanpa next step.

Dampak:
- UX recovery rendah saat backend timeout/unauthorized.

Action:
- Standardisasi mapping error `timeout`, `network`, `401`, `5xx`.
- Tambahkan CTA retry / login ulang bila token expired.

## Temuan Positif (Sudah Ada Baseline)

### Home/Beranda (berita)

File: `apps/mobile/lib/modules/home/beranda_page.dart`

- Sudah punya `_isLoading` dan `_errorMessage` (`apps/mobile/lib/modules/home/beranda_page.dart:826`)
- Ada fallback error jaringan (`apps/mobile/lib/modules/home/beranda_page.dart:873`)
- State error ditampilkan di UI section berita (`apps/mobile/lib/modules/home/beranda_page.dart:932`)

### Edukasi List

File: `apps/mobile/lib/modules/edukasi/edukasi_page.dart`

- Ada state `loading/error/empty` yang eksplisit:
  - loading spinner (`apps/mobile/lib/modules/edukasi/edukasi_page.dart:160`)
  - error card (`apps/mobile/lib/modules/edukasi/edukasi_page.dart:163`)
  - empty card (`apps/mobile/lib/modules/edukasi/edukasi_page.dart:168`)

## Rekomendasi Eksekusi Cepat (1-2 Hari)

1. Patch UX `login` Google button fallback (pisahkan validasi dari login email/password).
2. Refactor `Sertifikat` jadi data-driven minimal + state `loading/empty/error`.
3. Tambah loading state eksplisit pada `Quiz` progress.
4. Standarkan pesan error untuk timeout/network/unauthorized pada flow kritikal.
