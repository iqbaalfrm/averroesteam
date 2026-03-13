# Audit UX/UI Mobile (13 Mar 2026)

Scope audit cepat (kode statis):
- Auth (login, register, lupa password, verifikasi OTP)
- Home/Beranda
- Edukasi (list, detail, quiz)
- Sertifikat
- Profil
- Kebijakan Privasi (copy dan konsistensi)

## Ringkasan

- Auth sudah rapi, komponen dan spacing cukup konsisten.
- Edukasi dan Quiz sudah punya state loading/error/empty yang jelas.
- Sertifikat sudah data-driven dan ada state lengkap, tetapi visualnya masih terlalu dekoratif dan tidak konsisten dengan style guide.
- Home dan Profile masih padat dan banyak hardcoded style.
- Konten kebijakan privasi berpotensi tidak akurat untuk Play Store (data yang diklaim dikumpulkan).

## Temuan Prioritas (High)

1. Konsistensi visual lintas screen masih lemah
   - Banyak hardcoded color dan style di `home` dan `profile`.
   - Risiko: tampilan terasa tidak seragam dan sulit dirawat.
   - File: `apps/mobile/lib/modules/home/beranda_page.dart`, `apps/mobile/lib/modules/profile/profile_page.dart`.

2. Sertifikat terasa demo-like dan keluar dari sistem UI
   - Menggunakan kombinasi font dan dekorasi yang tidak selaras dengan style guide V1.
   - Risiko: persepsi kualitas turun pada flow utama.
   - File: `apps/mobile/lib/modules/sertifikat/sertifikat_page.dart`.

3. Konten Kebijakan Privasi berpotensi tidak akurat
   - Menyatakan pengumpulan data lokasi dan aktivitas ibadah tanpa bukti implementasi.
   - Risiko: mismatch data safety di Play Console.
   - File: `apps/mobile/lib/modules/kebijakan_privasi/kebijakan_privasi_page.dart`.

## Temuan Prioritas (Medium)

1. Home dan Profile terlalu padat secara visual
   - CTA dan konten utama kurang fokus.
   - Perlu pengurangan density dan standardisasi card.

2. Feedback error masih generik pada beberapa flow
   - Perlu mapping error network/timeout/401 agar lebih actionable.

## Temuan Prioritas (Low)

1. Beberapa tombol bantuan belum punya aksi jelas
   - Contoh di login top bar.

## Rekomendasi Eksekusi Cepat

1. Standarkan card/list item dan state component lintas screen.
2. Lakukan cleanup visual Home dan Profile (kurangi variasi style).
3. Sederhanakan visual Sertifikat agar selaras dengan style guide.
4. Audit ulang copy Kebijakan Privasi agar sesuai data yang benar-benar dikumpulkan.
