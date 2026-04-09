# Serverless vs VPS Boundary

Dokumen ini memisahkan komponen yang tetap dijalankan di Supabase dari komponen yang memang lebih aman/stabil jika dijalankan di VPS.

## Tetap serverless di Supabase

- `supabase/functions/auth-send-otp`
- `supabase/functions/custom-auth-reset-password`
- `supabase/functions/delete-account`
- tabel app utama:
  - `profiles`
  - `user_wallets`
  - `discussion_posts`
  - `books`, `book_categories`
  - `news_items`
  - `kajian_items`
  - `screeners`
  - `consultation_*`

Alasan:

- data utama dibaca langsung mobile lewat Supabase
- auth custom, delete account, dan RLS lebih cocok dekat dengan data
- mobile production sudah dibangun dengan `SUPABASE_NATIVE_ENABLED=true`

## Jalan di VPS

### `apps/vps-news-sync`

Tugas:

- fetch Google News RSS
- resolve URL Google News ke publisher asli
- ambil `og:image` dari halaman publisher
- sinkronkan hasil ke `public.news_items`

Alasan:

- scraping berulang tidak ideal di mobile
- proses decode URL Google News butuh request tambahan
- ekstraksi metadata publisher lebih cocok dijalankan background worker
- lebih mudah dipantau di VPS lewat log dan `systemd`

## Status arsitektur saat ini

- Mobile:
  - baca berita dari `news_items` Supabase
  - tap berita langsung buka `source_url` eksternal
- Supabase:
  - tetap jadi source of truth untuk app
- VPS:
  - hanya dipakai sebagai worker ingest berita

## Prinsip ke depan

- Kalau fitur bisa dibaca/tulis aman lewat RLS dan Edge Functions, tetap di Supabase.
- Kalau fitur butuh crawling, scraping, scheduler, atau request panjang berulang, taruh di app VPS terpisah.
- Jangan campur worker VPS dengan API mobile kalau tidak diperlukan.
