# Play Console Launch Checklist

Status teknis repo per 9 April 2026:

- `applicationId`: `id.averroes.app`
- `versionName`: `1.0.0`
- `versionCode`: `1`
- `minSdk`: `28`
- `targetSdk`: `35`
- Release bundle: `apps/mobile/build/app/outputs/bundle/release/app-release.aab`

## Wajib sebelum submit production

- Host `docs/privacy-policy.html` ke URL HTTPS publik.
- Jika memakai GitHub Pages repo ini, kandidat URL-nya:
  - `https://iqbaalfrm.github.io/averroesteam/privacy-policy.html`
- Isi field Privacy Policy di Play Console dengan URL publik tersebut.
- Siapkan akun reviewer atau instruksi App Access untuk OTP/login.
- Lengkapi form Data safety sesuai integrasi nyata:
  - account data: nama, email
  - app activity: progress belajar, kuis, sertifikat
  - optional integrations: notification settings, wallet linking, chatbot
- Verifikasi edge function Supabase production sudah deploy:
  - `auth-send-otp`
  - `custom-auth-reset-password`
  - `delete-account`
- Verifikasi migration Supabase production sudah terpasang.
- Jika berita mau tampil dengan gambar publisher asli dan link artikel asli, deploy worker VPS:
  - `apps/vps-news-sync`
  - isi `.env` worker dengan `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY`
  - jalankan `python news_sync_worker.py` atau mode `systemd --loop`
- Pastikan provider Auth Supabase yang dipakai production sudah aktif:
  - Anonymous sign-ins untuk login tamu
  - Google provider jika tombol Google login ingin ditampilkan
- Pastikan secret edge function production sudah terisi:
  - `SUPABASE_URL`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `APP_BRAND_NAME`
  - salah satu provider email berikut:
    - `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `RESEND_FROM_NAME`
    - atau `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM_ADDRESS`, `MAIL_FROM_NAME`, `MAIL_ENCRYPTION`

## Deploy commands

Contoh deploy Supabase production:

```bash
supabase link --project-ref <PROJECT_REF>
supabase db push
supabase functions deploy auth-send-otp
supabase functions deploy custom-auth-reset-password
supabase functions deploy delete-account
supabase secrets set --env-file supabase/.env.functions.example
```

Catatan:

- Isi `supabase/.env.functions.example` dengan value production asli sebelum `supabase secrets set`.
- Migration terbaru juga memperbaiki insert native untuk `portfolio_items`, `discussion_posts`, dan `consultation_sessions`, jadi `supabase db push` wajib dijalankan sebelum smoke test mobile.

Contoh publish Privacy Policy dengan GitHub Pages:

```bash
git add docs/privacy-policy.html
git commit -m "docs: update privacy policy"
git push origin <branch>
```

Lalu aktifkan GitHub Pages untuk branch yang memuat folder `docs/`.

## Store listing assets

- App name:
  - `Averroes`
- Short description:
  - Isi maksimal 80 karakter.
- Full description:
  - Isi maksimal 4000 karakter.
- App icon:
  - Gunakan 512 x 512 PNG.
  - Candidate source: `apps/mobile/web/icons/Icon-512.png`
- Phone screenshots:
  - Siapkan minimal 2.
  - Disarankan: Login, Beranda, Screener, Kajian, Zakat, Pustaka.
- Feature graphic:
  - Siapkan 1024 x 500 PNG.
- Contact details:
  - Email support aktif.
  - Website jika ada.

## App content forms

- App access
- Ads declaration
- Content rating
- Target audience
- News app declaration:
  - pilih sesuai scope aplikasi
- Data safety
- Account deletion:
  - tandai bahwa penghapusan akun tersedia di dalam aplikasi

## Release sanity check

- Naikkan `version` di `apps/mobile/pubspec.yaml` sebelum upload berikutnya.
- Pastikan `.env` production berisi:
  - `API_BASE_URL`
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_REDIRECT_URL`
  - `PRIVY_APP_ID`
  - `PRIVY_CLIENT_ID`
  - `GROQ_API_KEY`
- Isi `GOOGLE_WEB_CLIENT_ID` jika Google login ingin ditampilkan.
- Untuk mode full serverless, `SUPABASE_NATIVE_ENABLED=true` wajib aktif di build production.
- Arsitektur production yang disarankan:
  - app + data utama: Supabase
  - scraping berita: `apps/vps-news-sync` di VPS
- Jalankan:
  - `flutter test`
  - `flutter build appbundle --release`

## Saran screenshot

- `Login / Register`
- `Beranda`
- `Screener Syariah`
- `Kajian`
- `Kalkulator Zakat`
- `Pustaka`
