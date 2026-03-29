# Proper Release Checklist Averroes

Checklist ini fokus pada kesiapan produk, bukan semua fitur harus selesai. Targetnya: aplikasi terasa matang, stabil, jelas nilainya, dan aman untuk dipresentasikan atau dipakai user awal.

Catatan status:

- `[x]` berarti sudah saya rapikan atau align di source code
- `[ ]` berarti masih perlu UAT, verifikasi runtime, atau belum selesai penuh

## 1. Core Release Gate

### Wajib beres sebelum dianggap proper

- [ ] Auth end-to-end jalan
- [ ] Beranda stabil dan tidak ada shortcut yang salah
- [ ] Screener Syariah stabil
- [x] Kajian bisa tampil dan diputar di dalam aplikasi
- [ ] Zakat bisa dihitung dengan benar
- [ ] Pustaka bisa dibuka dan dibaca
- [ ] Chatbot bisa merespons tanpa error
- [x] Placeholder untuk fitur yang ditahan sudah konsisten
- [ ] Tidak ada runtime error merah
- [ ] Tidak ada translasi mentah yang tampil ke user

### Tidak wajib selesai untuk release awal

- [ ] Psikolog tetap placeholder
- [ ] Konsultasi tetap placeholder
- [ ] Diskusi tetap placeholder
- [ ] Fitur lanjutan yang memang direncanakan pasca-launch tidak dipaksakan aktif

## 2. Auth

### Wajib

- [ ] Login email + password berhasil
- [x] Register berhasil kirim data
- [ ] OTP verifikasi register berhasil
- [ ] Lupa password berhasil kirim OTP
- [ ] Reset password berhasil
- [ ] Guest login berhasil
- [ ] Google login berhasil jika memang diaktifkan
- [ ] Semua state loading, error, dan success muncul dengan benar
- [x] UI login, register, forgot password, OTP, reset password sudah konsisten

### Nice to have

- [ ] Validasi form lebih rapi
- [ ] Pesan error backend lebih manusiawi

## 3. Beranda

### Wajib

- [ ] Jadwal shalat tampil normal
- [ ] Kartu portofolio tampil normal
- [x] Semua shortcut fitur mengarah ke route yang benar
- [x] Tidak ada overflow pada grid fitur
- [x] Bottom navigation stabil
- [x] Label fitur sesuai nama final

### Nice to have

- [ ] Poles spacing dan hierarki visual
- [ ] Tambah skeleton/loading yang lebih halus

## 4. Screener Syariah

### Wajib

- [ ] Data coin tampil
- [ ] Search berjalan
- [ ] Filter status berjalan
- [x] Default mode Top 100 Market berjalan
- [ ] Detail status syariah terbaca jelas
- [ ] Empty state dan error state aman

### Nice to have

- [ ] Detail metodologi lebih rapi
- [ ] Penjelasan fiqh dipoles lagi

## 5. Kajian

### Wajib

- [ ] Halaman Kajian bisa dibuka tanpa error
- [x] Video bisa diputar di dalam aplikasi
- [x] List video tampil
- [x] Thumbnail tampil normal
- [x] Fallback video sementara tetap tampil jika endpoint backend belum siap
- [ ] Jika backend aktif, data admin terbaca

### Nice to have

- [ ] Kategori kajian
- [ ] Search kajian
- [ ] Auto-sync playlist/channel

## 6. Zakat

### Wajib

- [ ] Input manual harta dan hutang berjalan
- [ ] Aset bersih dihitung benar
- [ ] Nishab tampil
- [ ] Harga emas tampil normal
- [ ] Status wajib / belum wajib jelas
- [ ] Nilai zakat 2,5% benar
- [ ] Tombol Bayar Sekarang mengarah ke BAZNAS
- [x] Popup bantuan cara pakai berjalan

### Nice to have

- [ ] Penjelasan zakat diperjelas lagi
- [ ] Transparansi fallback harga emas

## 7. Pustaka

### Wajib

- [x] Daftar ebook tampil
- [x] Pagination berjalan
- [x] Detail ebook tampil
- [x] PDF/reader bisa dibuka
- [x] Empty state dan error state aman

### Nice to have

- [ ] Kategori lebih matang
- [ ] Bookmark atau last read

## 8. Chatbot

### Wajib

- [x] Branding Averroes sudah benar
- [ ] Kirim prompt ke Groq berhasil
- [x] Setting chatbot berjalan
- [x] Toggle sertakan dalil berjalan
- [x] Mode jawaban singkat/normal/detail berjalan
- [x] Reset chat berjalan
- [x] Error API tidak bikin halaman rusak

### Nice to have

- [ ] Preset FAQ crypto syariah
- [ ] Bank dalil kurasi
- [ ] Fokus jawaban per topik

## 9. Pustaka Visual dan UX

### Wajib

- [x] Tidak ada layar yang terasa beda sendiri kualitasnya
- [x] Typografi cukup konsisten
- [x] Warna dan komponen inti konsisten
- [x] Tombol utama jelas
- [x] Empty state, loading state, dan error state ada di fitur utama

### Nice to have

- [ ] Motion/transition lebih halus
- [ ] Skeleton loading lebih seragam

## 10. Placeholder dan Scope Control

### Wajib

- [x] Psikolog menampilkan placeholder yang jelas
- [x] Konsultasi menampilkan placeholder yang jelas
- [x] Diskusi menampilkan placeholder yang jelas
- [x] Tidak ada entry point yang diam-diam masih membuka halaman lama
- [x] Copy placeholder profesional dan konsisten

## 11. Backend dan Admin

### Wajib

- [x] Endpoint auth aktif
- [x] Endpoint screener aktif
- [x] Endpoint kajian aktif atau fallback aman
- [x] Endpoint pustaka aktif
- [x] Endpoint zakat aktif
- [x] Admin bisa input konten penting
- [x] Error backend tidak menampilkan raw crash ke user

### Nice to have

- [x] Seed data demo yang rapi
- [ ] Dashboard admin lebih enak dipakai

## 12. Demo Readiness

### Wajib

- [ ] Ada minimal 1 alur demo yang mulus dari buka app sampai selesai
- [x] Data demo tidak kosong
- [x] Tidak ada tombol yang membingungkan saat demo
- [x] Fitur yang belum siap sudah disamarkan dengan baik
- [x] Tidak ada route 404 dari mobile ke backend pada flow utama

### Suggested demo flow

- [ ] Buka aplikasi
- [ ] Login atau guest
- [ ] Lihat beranda
- [ ] Masuk Screener
- [ ] Masuk Kajian
- [ ] Coba kalkulator Zakat
- [ ] Buka Pustaka
- [ ] Coba Chatbot

## 13. Final Pre-Release Sweep

- [ ] Cek semua teks typo
- [ ] Cek semua icon dan label
- [ ] Cek semua route utama
- [ ] Cek semua tombol CTA
- [ ] Cek semua state loading/error/empty
- [ ] Cek semua integrasi eksternal
- [ ] Cek auth token dan logout
- [ ] Cek tampilan di ukuran HP utama
- [ ] Cek full restart app tidak merusak flow

## 14. Rekomendasi Prioritas Nyata

Kalau dikerjakan bertahap, urutan paling masuk akal:

1. Auth
2. Beranda
3. Screener
4. Kajian
5. Zakat
6. Pustaka
7. Chatbot
8. Placeholder cleanup
9. Final UI polish
10. Demo rehearsal

## 15. Definition of Proper

Averroes bisa dianggap proper untuk release awal jika:

- user bisa masuk ke aplikasi tanpa bingung
- value utama aplikasi langsung terlihat
- fitur inti berjalan tanpa error fatal
- fitur yang belum siap tidak merusak persepsi kualitas
- demo flow bisa dijalankan dari awal sampai akhir dengan mulus
