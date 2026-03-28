# Averroes

## 1. Executive Summary

**Averroes** adalah platform edukasi dan utilitas digital untuk membantu Muslim memahami **aset kripto syariah**, **fiqh muamalah digital**, dan **pengelolaan aset secara lebih bertanggung jawab**.

Produk ini tidak diposisikan sebagai aplikasi sinyal trading. Averroes diposisikan sebagai:

- pusat edukasi crypto syariah
- alat bantu screening dan pengambilan keputusan awal
- jembatan antara literasi muamalah, teknologi, dan praktik finansial modern
- ekosistem konten yang menggabungkan pembelajaran, portofolio, zakat, pustaka, chatbot, reels, dan kajian video

Secara produk, Averroes menggabungkan tiga lapisan utama:

- **Learn**: edukasi kelas, materi, kuis, sertifikat, pustaka, reels, kajian
- **Analyze**: screener syariah, pasar spot, chatbot edukatif
- **Act**: portofolio, kalkulator zakat, pembayaran zakat via BAZNAS

---

## 2. Problem Statement

Pasar crypto di Indonesia berkembang cepat, tetapi ada gap besar di tiga area:

- Banyak pengguna Muslim tertarik pada aset digital, tetapi bingung menilai aspek **halal/haram**, **gharar**, **maysir**, dan **riba**.
- Edukasi crypto yang beredar sering fokus pada hype, profit, dan spekulasi, bukan pada **fondasi ilmu** dan **prinsip syariah**.
- Tools yang tersedia biasanya terpisah: belajar di satu tempat, cek market di tempat lain, hitung zakat di tempat lain, konsultasi di kanal lain.

**Averroes** hadir untuk merapikan pengalaman itu menjadi satu aplikasi yang lebih tenang, edukatif, dan terarah.

---

## 3. Solution Overview

Averroes menyediakan satu ekosistem mobile dengan backend admin untuk:

- mengedukasi user tentang fiqh muamalah dan crypto syariah
- membantu user memfilter aset dan memahami market
- membantu user mencatat aset dan menghitung kewajiban zakat
- menyajikan konten pembelajaran dalam berbagai format: kelas, buku, reels, dan video kajian
- menyediakan chatbot edukatif yang diarahkan khusus ke topik crypto syariah

Model pengalaman pengguna Averroes:

1. User masuk ke aplikasi.
2. User melihat ringkasan beranda: jadwal shalat, portofolio, fitur utama, berita.
3. User belajar dari materi, pustaka, reels, atau kajian.
4. User menganalisis aset lewat screener dan pasar.
5. User mencatat portofolio dan menghitung zakat.
6. User membayar zakat melalui kanal resmi jika diperlukan.

---

## 4. Target User

### Primary User

- Muslim pemula yang ingin memahami crypto dari sudut pandang syariah
- Mahasiswa, profesional muda, dan investor retail yang butuh panduan edukatif
- Pengguna yang ingin belajar muamalah digital dengan bahasa yang lebih sederhana

### Secondary User

- Komunitas edukasi Islam dan keuangan syariah
- Mentor, ustadz, atau ahli syariah yang ingin menyampaikan kajian digital
- Tim admin internal yang mengelola konten, data, dan pengalaman belajar

---

## 5. Product Positioning

**Averroes bukan aplikasi spekulasi.**

Ia diposisikan sebagai:

- aplikasi edukasi aset kripto syariah
- platform literasi fiqh muamalah digital
- alat bantu keputusan awal, bukan fatwa final
- aplikasi pembelajaran yang dekat dengan kebutuhan Muslim digital

Nilai diferensiasinya:

- syariah-first
- edukasi-first
- all-in-one experience
- relevan untuk konteks crypto modern

---

## 6. Product Modules

Di bawah ini adalah modul-modul utama Averroes berdasarkan implementasi repo saat ini.

### 6.1. Authentication & Account

Fungsi:

- login
- register
- login guest
- forgot password
- verifikasi OTP
- reset password
- Google Sign-In

Nilai:

- menurunkan friction onboarding
- mendukung guest mode untuk eksplorasi awal
- tetap mendukung akun penuh untuk fitur yang memerlukan identitas

Status:

- aktif
- Google login bergantung pada konfigurasi OAuth

### 6.2. Beranda

Fungsi:

- greeting user
- ringkasan jadwal shalat
- ringkasan portofolio
- akses cepat ke fitur utama
- berita terbaru

Nilai:

- membuat aplikasi terasa hidup sejak layar pertama
- menyatukan spiritual utility dan financial utility dalam satu dashboard

Status:

- aktif

### 6.3. Edukasi / LMS

Fungsi:

- daftar kelas
- detail kelas dengan struktur modul dan materi
- progress materi
- kuis
- sertifikat
- riwayat belajar

Cara kerja:

- user masuk ke halaman edukasi dan melihat katalog kelas yang tersedia
- setiap kelas memiliki detail pembelajaran yang disusun bertingkat: `kelas -> modul -> materi`
- user membuka materi satu per satu, lalu progress penyelesaian materi disimpan ke akun
- setelah materi selesai, user melanjutkan ke kuis kelas untuk mengukur pemahaman
- sistem menghitung progres materi, jumlah kuis yang sudah dijawab, jumlah jawaban benar, dan skor akhir
- jika semua materi selesai, semua kuis terjawab, dan skor minimal mencapai `95`, user menjadi eligible untuk generate sertifikat
- halaman profil juga dapat menarik ringkasan `last learning`, sehingga user bisa melanjutkan kelas terakhir yang sedang dipelajari

Nilai produk:

- menjadikan Averroes bukan hanya tool, tapi juga learning platform
- mendorong user dari curiosity ke pemahaman terstruktur
- membuat topik crypto syariah terasa lebih sistematis, tidak hanya potongan konten pendek
- memberi jalur belajar yang bisa diukur, bukan sekadar konsumsi konten pasif
- memperkuat trust karena pembelajaran, evaluasi, dan bukti kelulusan hadir dalam satu flow

Komponen inti LMS:

- `Kelas`: wadah utama tema belajar, misalnya topik pengantar crypto syariah atau fiqh muamalah digital
- `Modul`: pengelompokan materi per bab atau per fase pembelajaran
- `Materi`: unit belajar yang dibaca atau dipelajari user satu per satu
- `Quiz`: evaluasi pemahaman user pada level kelas
- `Materi Progress`: pencatatan materi yang sudah diselesaikan user
- `Sertifikat`: output akhir ketika syarat kelulusan terpenuhi

Yang membuat LMS ini penting:

- LMS menjadi tulang punggung edukasi Averroes, karena ia mengubah aplikasi dari sekadar kumpulan fitur menjadi kurikulum belajar
- untuk user pemula, LMS memberi urutan belajar yang jelas: mulai dari dasar, lanjut ke praktik, lalu evaluasi
- untuk tim produk, LMS membuka peluang ekspansi konten ke banyak kelas tanpa harus mengubah arsitektur inti aplikasi
- untuk stakeholder, LMS menunjukkan bahwa Averroes punya elemen pembelajaran yang terstruktur dan terukur, bukan hanya informasi sesaat

Operasional & admin:

- konten kelas, modul, materi, quiz, dan template sertifikat dikelola dari backend/admin
- backend menyediakan endpoint untuk daftar kelas, detail kelas, daftar materi, submit quiz, simpan progress, ambil progress kelas, last learning, generate sertifikat, dan daftar sertifikat user
- dengan pola ini, tim admin bisa menambah atau memperbarui kurikulum tanpa harus merilis ulang aplikasi mobile setiap kali ada perubahan konten

Status:

- aktif
- dikelola dari backend/admin

### 6.4. Screener Syariah

Fungsi:

- daftar aset crypto dengan status syariah
- filter status `Semua / Halal / Proses / Haram`
- pencarian ticker / nama koin
- detail penjelasan fiqh
- metodologi dan catatan analisis

Nilai:

- menjadi fitur diferensiasi paling kuat Averroes
- membantu user menyaring aset secara lebih tenang sebelum masuk ke market

Status:

- aktif
- saat ini diposisikan sebagai **Top 100 Market** secara default

### 6.5. Pasar Spot

Fungsi:

- daftar market crypto
- filter top gainers / losers / watchlist
- pencarian aset
- chart beberapa rentang waktu
- data market cap, volume, ATH, ATL, deskripsi aset

Nilai:

- memberi konteks pasar setelah user melakukan screening
- mendekatkan fitur edukasi ke data market aktual

Status:

- aktif

### 6.6. Portofolio

Fungsi:

- tambah aset
- edit aset
- hapus aset
- hitung total nilai portofolio
- asset allocation
- histori

Nilai:

- membantu user melacak eksposur aset
- menghubungkan data belajar dengan praktik pengelolaan aset

Status:

- aktif

### 6.7. Kalkulator Zakat Maal

Fungsi:

- input total harta manual
- input hutang jatuh tempo manual
- hitung aset bersih
- cek nishab
- hitung zakat 2,5%
- menampilkan harga emas live sebagai acuan
- bayar sekarang ke BAZNAS
- popup bantuan cara memakai kalkulator

Nilai:

- menjembatani literasi crypto dan kewajiban syariah
- menjadi fitur praktik yang sangat relevan untuk positioning Averroes

Status:

- aktif
- nishab berbasis `85 gram emas`
- tombol pembayaran diarahkan ke kanal resmi BAZNAS

### 6.8. Pustaka Digital

Fungsi:

- daftar ebook
- filter / kategori buku
- pagination daftar buku
- baca file di aplikasi
- cover, metadata, status publish

Nilai:

- memperluas format belajar di luar kelas
- membantu membangun positioning Averroes sebagai knowledge hub

Status:

- aktif
- dikelola lewat admin/backend

### 6.9. Chatbot Averroes

Fungsi:

- chatbot edukatif topik crypto syariah
- quick prompt
- mode jawaban `Singkat / Normal / Detail`
- opsi `Sertakan Dalil`
- reset chat
- guardrail agar bot fokus pada crypto, syariah, zakat, risiko, dan muamalah

Nilai:

- memberi pengalaman interaktif dan personal
- membantu user yang lebih suka bertanya daripada membaca materi panjang

Status:

- aktif
- memakai API eksternal Groq
- bersifat edukatif, bukan fatwa final

### 6.10. Reels

Fungsi:

- konten pendek bertema fiqh muamalah / syariah
- konsumsi konten cepat dan ringan
- mendukung distribusi insight singkat

Nilai:

- meningkatkan retensi
- memberi format konten yang lebih ringan dibanding kelas atau pustaka

Status:

- aktif
- backend mendukung seed/fallback data

### 6.11. Kajian Video

Sebelumnya fitur ini bernama `Zikir`, namun saat ini telah diarahkan menjadi **Kajian**.

Fungsi:

- list video kajian berbasis YouTube
- diputar di dalam aplikasi tanpa membuka aplikasi YouTube
- player utama + daftar video mirip pengalaman YouTube
- data video dikelola dari admin

Input admin:

- judul
- deskripsi
- link YouTube
- channel
- kategori
- durasi label
- urutan
- status aktif

Nilai:

- memperkuat distribusi konten ustadz/narasumber
- memudahkan tim konten mengelola kajian cukup dari admin panel

Status:

- aktif
- data sudah tidak hardcoded di mobile
- sudah terhubung ke backend admin

### 6.12. Diskusi

Visi fitur:

- ruang diskusi komunitas
- thread dan balasan
- potensi ruang VIP

Status saat ini:

- rute backend diskusi tersedia
- pada mobile user-facing utama saat ini dipasang placeholder `Belum Tersedia`

Artinya:

- fondasi backend ada
- pengalaman akhir untuk launch publik masih ditahan

### 6.13. Psikolog

Visi fitur:

- layanan psikolog / wellbeing dalam ekosistem aplikasi

Status saat ini:

- di mobile diarahkan ke placeholder `Belum Tersedia`

### 6.14. Konsultasi

Visi fitur:

- konsultasi ahli syariah
- sesi / transaksi konsultasi

Status saat ini:

- backend sesi dan ahli syariah tersedia
- mobile launch flow publik saat ini ditahan dengan placeholder

### 6.15. Profil & Utility

Fungsi:

- edit profil
- notifikasi
- bantuan
- kebijakan privasi
- sertifikat

Nilai:

- melengkapi pengalaman aplikasi secara end-to-end

Status:

- aktif

---

## 7. Admin & Content Management

Averroes memiliki **panel admin berbasis Flask + Jinja** untuk mengelola data inti produk.

Modul admin saat ini mencakup:

- dashboard
- LMS: kelas, modul, materi, quiz, sertifikat
- buku
- kategori buku
- screener
- berita
- kajian
- diskusi
- ahli syariah
- transaksi konsultasi
- pengguna

Fungsi admin:

- CRUD data konten
- upload file tertentu
- publish/unpublish konten
- mengatur urutan tampilan
- menjalankan aplikasi sebagai content-driven product

Nilai bisnis:

- tim non-developer bisa mengelola banyak konten tanpa perlu edit source code
- produk lebih scalable karena konten dipindah ke backend/admin

---

## 8. Feature Status Snapshot

### Ready / Active

- Auth
- Beranda
- Edukasi / LMS
- Screener
- Pasar Spot
- Portofolio
- Zakat
- Pustaka
- Chatbot
- Reels
- Kajian
- Profil, bantuan, notifikasi, kebijakan privasi

### Partial / Controlled Rollout

- Google Sign-In
- Konsultasi
- Diskusi
- beberapa integrasi pihak ketiga yang bergantung env/config production

### Deliberately Held / Placeholder

- Psikolog
- Konsultasi publik penuh
- Diskusi publik penuh

---

## 9. Tech Stack

## 9.1. Mobile App

Platform:

- **Flutter**
- **Dart SDK >= 3.3**

State, navigation, and app structure:

- **GetX** (`get`)
- custom route configuration via Get pages

Networking and storage:

- **Dio** untuk HTTP client
- **flutter_dotenv** untuk environment config
- **get_storage** untuk local lightweight persistence

UI and design:

- **google_fonts**
- **material_symbols_icons**
- shared UI package: `averroes_core`

Media and content:

- **syncfusion_flutter_pdfviewer** untuk PDF/ebook
- **youtube_player_iframe** untuk embedded YouTube kajian
- **webview_flutter** + platform packages untuk player webview
- **just_audio** untuk audio
- **share_plus** untuk sharing
- **url_launcher** untuk membuka tautan eksternal

Notification and scheduling:

- **flutter_local_notifications**
- **timezone**

Authentication:

- **google_sign_in**

Internal package modularization:

- `packages/core`
- `packages/network`
- `packages/shared_models`

## 9.2. Backend API

Framework:

- **Flask 3**

Core backend libraries:

- **Flask-JWT-Extended** untuk auth token
- **Flask-WTF** untuk CSRF/admin form
- **Flask-Mail** untuk email / OTP flow
- **gunicorn** untuk deployment
- **python-dotenv**
- **requests**

Database:

- **MongoDB**
- **PyMongo**

Payment and auth integrations:

- **midtransclient** untuk payment/session
- **google-auth** untuk Google OAuth verification

Architecture style:

- modular Flask blueprints
- public API + admin blueprint
- seedable development environment

## 9.3. Admin Panel

Rendering stack:

- **Flask server-side rendered templates**
- **Jinja2**
- **Tailwind CSS via CDN**

Admin orientation:

- lightweight internal CMS/control panel
- cepat dipakai untuk operasi konten

## 9.4. Web App

Folder `apps/web/` sudah disiapkan, tetapi saat ini masih **scaffold**.

Artinya:

- struktur web app sudah ada
- framework final belum dipilih
- belum menjadi channel utama produk saat ini

## 9.5. Shared Package Layer

`packages/core`

- tema
- konstanta UI
- shared visual foundation

`packages/network`

- abstraksi networking / shared network client

`packages/shared_models`

- tempat model bersama lintas modul

---

## 10. External Integrations

Averroes saat ini terhubung atau siap terhubung dengan beberapa layanan eksternal:

- **Groq API** untuk chatbot
- **Google OAuth** untuk login Google
- **Midtrans** untuk payment flow tertentu
- **Gold API** untuk harga emas
- **Exchange Rate API** untuk kurs USD/IDR
- **BAZNAS** untuk pembayaran zakat
- **YouTube** untuk video kajian
- **SMTP / Gmail-compatible mail** untuk email flow
- **Aladhan API** untuk jadwal shalat

---

## 11. Security & Operational Notes

Keputusan teknis penting yang terlihat di repo:

- autentikasi API menggunakan JWT
- admin panel dipisahkan dari mobile app flow
- config dibedakan antara development dan production
- production mewajibkan secret yang kuat
- upload file diarahkan ke storage lokal backend
- beberapa endpoint mobile non-auth tetap tersedia untuk konsumsi publik yang aman

Catatan:

- chatbot tetap harus diposisikan sebagai alat bantu edukasi
- jawaban syariah dari chatbot tidak boleh diposisikan sebagai fatwa final
- beberapa integrasi production tetap bergantung kualitas env dan deployment

---

## 12. Product Architecture Summary

Arsitektur tinggi Averroes:

1. **Mobile Flutter App** menjadi channel utama user.
2. Mobile mengakses **Flask API Backend**.
3. Backend menyimpan dan membaca data dari **MongoDB**.
4. Tim internal mengelola konten lewat **Admin Panel Flask**.
5. Backend/mobile mengonsumsi beberapa **API eksternal** untuk enrichment:
   - market
   - jadwal shalat
   - chatbot
   - harga emas
   - YouTube
   - payment

Secara produk, ini membuat Averroes bersifat:

- content-driven
- modular
- relatif cepat dikembangkan bertahap
- cocok untuk MVP yang berkembang menuju platform edukasi yang lebih besar

---

## 13. Why Averroes Matters

Averroes penting bukan karena menambah satu lagi aplikasi crypto, tetapi karena mencoba menjawab pertanyaan yang jarang dijawab secara rapi:

- bagaimana Muslim belajar crypto tanpa langsung masuk ke budaya spekulasi?
- bagaimana fiqh muamalah diterjemahkan ke konteks digital modern?
- bagaimana pembelajaran, analisis, dan aksi keuangan bisa dipersatukan dalam satu experience?

Jika dieksekusi dengan disiplin konten dan positioning yang konsisten, Averroes dapat menjadi:

- aplikasi edukasi crypto syariah yang unik di pasar
- pusat literasi fiqh muamalah digital
- basis produk yang dapat berkembang ke konsultasi, komunitas, premium content, dan dashboard web di fase berikutnya

---

## 14. Current Product Narrative

Pitch singkat Averroes:

> **Averroes adalah aplikasi edukasi aset kripto syariah yang membantu Muslim belajar, menyaring, mencatat, dan mengelola aset digital dengan pendekatan fiqh muamalah yang lebih tenang, praktis, dan terintegrasi.**

Versi yang lebih panjang:

> Averroes menggabungkan kelas edukasi, screener syariah, market insight, pustaka digital, video kajian, chatbot edukatif, portofolio, dan kalkulator zakat ke dalam satu ekosistem mobile. Dengan backend admin yang mengelola konten secara fleksibel, Averroes dirancang sebagai fondasi platform pembelajaran dan utilitas finansial syariah modern.
