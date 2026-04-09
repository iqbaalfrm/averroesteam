# MongoDB -> Supabase/Postgres Migration

## Files

- `apps/backend/scripts/sql/supabase_schema.sql`
- `apps/backend/scripts/sql/supabase_native.sql`
- `apps/backend/scripts/sql/supabase_content_native.sql`
- `apps/backend/scripts/sql/supabase_custom_auth.sql`
- `apps/backend/scripts/sql/supabase_storage.sql`
- `apps/backend/scripts/migrate_mongo_to_postgres.py`
- `supabase/migrations/20260409040000_supabase_schema.sql`
- `supabase/migrations/20260409040500_supabase_native.sql`
- `supabase/migrations/20260409040700_supabase_custom_auth.sql`
- `supabase/migrations/20260409041000_supabase_content_native.sql`
- `supabase/migrations/20260409042000_supabase_storage.sql`

## Env Minimum

- `MONGODB_URI`
- `DB_NAME`
- `POSTGRES_URL` atau `SUPABASE_DB_URL`

Jika mau sekalian membuat user `auth.users` via Supabase Admin API:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_MIGRATION_CREATE_AUTH_USERS=true`

## Example

Dry run:

```powershell
python apps/backend/scripts/migrate_mongo_to_postgres.py --dry-run
```

Apply schema lalu migrasi:

```powershell
python apps/backend/scripts/migrate_mongo_to_postgres.py --apply-schema
```

Apply schema, migrasi data, dan buat auth users Supabase:

```powershell
python apps/backend/scripts/migrate_mongo_to_postgres.py --apply-schema --create-auth-users
```

## Push SQL via Supabase CLI

Kalau repo sudah di-link ke project Supabase dan mau apply SQL langsung ke remote database:

```powershell
supabase link --project-ref <project-ref>
$env:SUPABASE_DB_PASSWORD='<database-password>'
supabase db push
```

Catatan:

- `supabase db push` tetap butuh password database project Supabase.
- Urutan migrasi remote yang dipakai repo ini adalah:
  - `20260409040000_supabase_schema.sql`
  - `20260409040500_supabase_native.sql`
  - `20260409040700_supabase_custom_auth.sql`
  - `20260409041000_supabase_content_native.sql`
  - `20260409042000_supabase_storage.sql`

## Notes

- Script memakai UUID stabil berbasis `legacy_mongo_id`, jadi aman untuk rerun.
- User yang belum bisa langsung dipetakan ke Supabase Auth akan masuk `public.auth_migration_queue`.
- Password hash lama dari Flask/Werkzeug tidak dipindah ke Supabase Auth. User lama tetap perlu reset password atau re-auth provider sesuai status di queue.

## Custom 4-Digit OTP Auth

Jika mau signup dan lupa password memakai OTP email 4 digit custom tanpa OTP bawaan Supabase Auth:

1. Apply SQL berikut ke project Supabase:

```sql
\i apps/backend/scripts/sql/supabase_schema.sql
\i apps/backend/scripts/sql/supabase_native.sql
\i apps/backend/scripts/sql/supabase_content_native.sql
\i apps/backend/scripts/sql/supabase_custom_auth.sql
```

2. Deploy Edge Functions:

```powershell
supabase functions deploy custom-auth-send-otp
supabase functions deploy custom-auth-verify-otp
supabase functions deploy custom-auth-reset-password
```

3. Isi secret function di Supabase:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `RESEND_API_KEY`
- `RESEND_FROM_EMAIL`
- `RESEND_FROM_NAME` optional
- `APP_BRAND_NAME` optional

4. Aktifkan di mobile env:

```env
SUPABASE_CUSTOM_OTP_ENABLED=true
SUPABASE_CUSTOM_OTP_LENGTH=4
```

Catatan:

- Flow ini membuat user email/password lewat Admin API lalu memverifikasi email memakai tabel challenge OTP custom.
- Template email bawaan Supabase Auth tidak dipakai untuk signup/recovery custom ini.
- Untuk kirim email dibutuhkan provider seperti Resend.

## Supabase Native Content

Jika mobile mau membaca konten langsung dari Supabase tanpa Flask untuk modul berikut:

- edukasi
- portofolio
- diskusi
- berita/home
- kajian
- reels
- pustaka
- sertifikat

Pastikan SQL berikut juga sudah di-apply:

```sql
\i apps/backend/scripts/sql/supabase_content_native.sql
\i apps/backend/scripts/sql/supabase_storage.sql
```

Lalu aktifkan di env mobile:

```env
SUPABASE_NATIVE_ENABLED=true
```

Catatan khusus `pustaka`:

- akses file native akan langsung jalan jika row `books` punya `drive_file_id`
- atau jika `extra_data` menyimpan URL absolut seperti `file_url`, `download_url`, `preview_url`, atau `cover_url`
- jika `storage_provider='supabase'`, mobile sekarang bisa membaca object path dari `file_key` / `cover_key` atau `extra_data.file_path`, `extra_data.download_path`, `extra_data.preview_path`, `extra_data.cover_path`
- bucket default yang dipakai mobile:
  - `pustaka-files` untuk PDF/EPUB private
  - `pustaka-covers` untuk cover public
- bucket bisa dioverride lewat env mobile:
  - `SUPABASE_PUSTAKA_FILES_BUCKET`
  - `SUPABASE_PUSTAKA_COVERS_BUCKET`
  - `SUPABASE_STORAGE_SIGNED_URL_TTL`
- format path yang didukung:
  - `folder/subfolder/file.pdf`
  - atau explicit bucket override `bucket-name:path/to/file.pdf`
- contoh row `books` yang siap Supabase Storage:

```sql
update public.books
set
  storage_provider = 'supabase',
  file_key = 'kelas/bitcoin-syariah/ebook.pdf',
  cover_key = 'kelas/bitcoin-syariah/cover.webp',
  extra_data = jsonb_build_object(
    'file_bucket', 'pustaka-files',
    'cover_bucket', 'pustaka-covers',
    'file_is_public', false,
    'cover_is_public', true
  )
where slug = 'bitcoin-syariah';
```

- field lama seperti `file_key` / `cover_key` yang masih berupa path lokal backend tidak cukup untuk mode serverless; file tersebut perlu dipindah ke Supabase Storage atau diganti ke URL publik yang bisa diakses mobile

Catatan tambahan:

- `screeners` sekarang dibaca dari tabel Supabase lalu diperkaya harga/rank/logo lewat CoinGecko public API langsung dari mobile
- `pasar` sekarang memakai Binance public API langsung dari mobile untuk global market, list aset, detail, dan chart
- `consultation_sessions` dipakai untuk menyimpan permintaan konsultasi dari mobile; flow no-VPS saat ini melanjutkan user ke WhatsApp ahli setelah request tersimpan, bukan ke Midtrans backend
- `user_wallets` sekarang bisa dibaca/tulis langsung dari mobile lewat RLS Supabase
- `zakat` mode no-VPS memakai live gold/fx fallback langsung dari mobile, tanpa endpoint backend `/api/zakat/nishab`
- `login tamu` di mode Supabase native butuh `Anonymous sign-ins` aktif di Supabase Auth; lihat docs: https://supabase.com/docs/guides/auth/auth-anonymous
