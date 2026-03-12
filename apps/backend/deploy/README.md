# Panduan Penyebaran (Deployment) Averroes Backend ke VPS Ubuntu

_Bismillah, berikhtiar menyiapkan peladen (server) yang aman, stabil, dan sesuai kaidah rekayasa perangkat lunak_. Panduan ini dirancang untuk memitigasi risiko *downtime* atau peretasan akses, berprinsip pada transparansi (log aplikasi) dan keandalan sistem *(Amanah)* untuk layanan Aplikasi Aset Kripto Syariah Averroes.

## Prasyarat (Syarat Sah Sistem)

*   VPS dengan sistem operasi **Ubuntu 22.04 LTS** atau yang lebih baru.
*   Akses *root* atau *sudo*.
*   Domain yang telah di-*pointing* ke alamat IP Publik VPS.

## Langkah-langkah Ikhtiar (Penyebaran)

1.  **Eksekusi Skrip Persiapan (*Setup*) VPS**
    Skrip ini akan memasang Python, Nginx, dan MongoDB sebagai basis tata niaga data.
    ```bash
    chmod +x setup_vps.sh
    ./setup_vps.sh
    ```
2.  **Pemindahan Berkas (Penyerahan Amanah Kodifikasi)**
    Gunakan `git clone` atau `scp` untuk membawa repo *AverroesTeam* ke ranah `/var/www/AverroesTeam`. Pastikan struktur menjadi: `/var/www/AverroesTeam/apps/backend`

3.  **Membuat Kesepakatan Lapis Virtual (*Virtual Environment*)**
    ```bash
    cd /var/www/AverroesTeam/apps/backend
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
    ```
4.  **Konfigurasi Parameter (*Environment*)**
    Amanah rahasia sistem disembunyikan menggunakan _DotEnv_:
    ```bash
    cp .env.example .env
    nano .env
    ```
    *Ubah variabel:*
    `APP_ENV=production`
    `SECRET_KEY=isi-dengan-rentetan-huruf-acak`
    `JWT_SECRET_KEY=isi-dengan-rentetan-huruf-acak`

5.  **Pengikatan Layanan (Systemd)**
    Agar *Gunicorn* (sebagai penengah komunikasi Flask) selalu menjaga aplikasi agar tetap siuman:
    ```bash
    sudo cp deploy/averroes_backend.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl start averroes_backend
    sudo systemctl enable averroes_backend
    ```
6.  **Pengaturan Penjaga Gerbang Khusus (Nginx)**
    Nginx akan bertindak sebagai pengatur muatan akses HTTP, mencegah *spam* dan menjadi wakil (Tawkil) perutean dari domain eksternal ke Flask internal.
    ```bash
    sudo cp deploy/nginx_averroes.conf /etc/nginx/sites-available/averroes
    sudo ln -s /etc/nginx/sites-available/averroes /etc/nginx/sites-enabled/
    sudo systemctl test nginx
    sudo systemctl restart nginx
    ```
7.  **Sertifikasi Keamanan HTTPS (Let's Encrypt)**
    Menjamin aliran data enkripsi (Mencegah Gharar informasi pada transmisi data):
    ```bash
    sudo apt install certbot python3-certbot-nginx -y
    sudo certbot --nginx -d api.domainanda.com
    ```

Selesai, alhamdulillah peladen kini telah kokoh berdiri. Terus pantau log (mitigasi risiko operasional) lewat:
`sudo journalctl -u averroes_backend -f` atau melihat berkas log Nginx.
