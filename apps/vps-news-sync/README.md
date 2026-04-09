# VPS News Sync

Worker ini khusus untuk pekerjaan yang tidak cocok dijalankan penuh di Supabase, yaitu:

- fetch Google News RSS
- resolve URL Google News ke URL publisher asli
- ambil `og:image` dari halaman publisher
- sinkronkan hasilnya ke tabel `public.news_items` di Supabase

Targetnya: mobile tetap baca berita langsung dari Supabase, sementara scraping dan resolusi link dijalankan di VPS.

## Kenapa dipisah dari serverless

Bagian app yang tetap serverless:

- auth custom OTP via Supabase Edge Functions
- delete account via Supabase Edge Functions
- data utama mobile via tabel Supabase
- wallet linking via tabel `user_wallets`

Bagian yang lebih cocok di VPS:

- scraping RSS berulang
- resolve link Google News yang butuh request tambahan
- ekstraksi metadata publisher seperti `og:image`

## Jalankan lokal

```bash
cd apps/vps-news-sync
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env
python news_sync_worker.py
```

## Jalankan loop worker

```bash
python news_sync_worker.py --loop
```

Interval default diambil dari `NEWS_SYNC_INTERVAL_SECONDS`.

Untuk smoke test cepat:

```bash
python news_sync_worker.py --limit 8
```

## Env

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NEWS_SYNC_FEEDS`
- `NEWS_SYNC_LIMIT`
- `NEWS_SYNC_INTERVAL_SECONDS`

## Deploy ke VPS

Contoh target folder:

```bash
/var/www/AverroesTeam/apps/vps-news-sync
```

Langkah umum:

```bash
cd /var/www/AverroesTeam/apps/vps-news-sync
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
nano .env
python news_sync_worker.py
```

Kalau sudah normal, pasang `systemd`:

```bash
sudo cp deploy/averroes_news_sync.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable averroes_news_sync
sudo systemctl start averroes_news_sync
sudo journalctl -u averroes_news_sync -f
```

## Output yang diharapkan

Row `news_items` di Supabase akan memakai:

- `source_url` = URL publisher asli
- `image_url` = thumbnail publisher asli
- `source_name` = nama sumber/publisher
- `provider` = `google_news_resolved` jika decode berhasil
