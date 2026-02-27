# UI Style Guide V1 (Mobile) - Averroes

## Arah Visual

Tema: `Calm Learning + Islamic Fintech`

Karakter:

- tenang, bersih, tidak terlalu ramai
- modern dan profesional
- hangat (sand) + tegas (slate) + aksen hijau (emerald)
- fokus pada keterbacaan dan alur belajar

## Design Tokens (Freeze V1)

### Color Palette

Gunakan warna dari `packages/core/lib/constants/app_colors.dart` sebagai basis.

- `Primary / Brand`
  - `AppColors.emeraldDark` `#0B3D2E`
  - `AppColors.emerald` `#0F766E`
- `Primary Surface`
  - `AppColors.emeraldSoft` `#ECFDF5`
- `Background`
  - `AppColors.sand` `#FFFAF3`
- `Text`
  - `AppColors.slate` `#0F172A`
  - `AppColors.muted` `#64748B`
- `Accent / Highlight`
  - `AppColors.amber` `#F59E0B`
  - `AppColors.amberSoft` `#FEF3C7`

Aturan:

- Maksimal 1 warna aksen dominan per screen (emerald)
- Amber hanya untuk status/hint/highlight, bukan CTA utama default
- Hindari warna random hardcoded jika sudah ada token setara

### Typography

Font utama: `Plus Jakarta Sans`

Scale (V1 baseline):

- `Display / Hero`: `28-32`, `700-800`
- `H1`: `22-24`, `700`
- `H2`: `18-20`, `700`
- `Body`: `14-16`, `400-500`
- `Caption`: `11-13`, `500-700`
- `Button`: `14-16`, `700`

Aturan:

- Maksimal 3 level teks utama terlihat di satu section
- Hindari terlalu banyak `fontWeight` campur aduk dalam satu card
- Gunakan `muted` untuk teks sekunder, bukan menurunkan opacity berlebihan

### Spacing Scale

Spacing scale freeze V1:

- `4`, `8`, `12`, `16`, `20`, `24`, `32`

Aturan:

- Antar elemen dalam group: `8-12`
- Antar section: `16-24`
- Padding horizontal screen default: `20` atau `24` (konsisten per screen)
- Jangan campur nilai ganjil acak kecuali kebutuhan layout spesifik

### Radius & Border

Radius baseline:

- Input / button kecil: `12`
- Card standar: `16`
- Card utama / panel: `20`
- Pill / chip: `999`

Border:

- gunakan border tipis (`1`) untuk memisahkan surface jika shadow minim
- warna border netral lembut (slate sangat muda / emerald soft)

### Elevation / Shadow

Aturan shadow V1:

- Shadow ringan, bukan efek dramatis
- Gunakan shadow hanya untuk layer penting (CTA floating, panel utama)
- Banyak card cukup border + kontras surface tanpa shadow besar

## Komponen Inti (Freeze V1)

### Primary Button

- Background: `emerald`
- Text: putih
- Tinggi konsisten (target `48-52`)
- Radius `12-16`
- State wajib:
  - normal
  - pressed
  - disabled
  - loading

### Secondary Button

- Surface putih / emeraldSoft
- Border tipis
- Teks `slate` atau `emerald`
- Jangan menyaingi visual weight tombol primary

### Input Field

- Label jelas + placeholder ringkas
- State wajib:
  - default
  - focus
  - error
  - disabled
- Error text spesifik, bukan generik

### Card

Jenis card V1:

- `info card` (konten ringkas)
- `action card` (ada CTA)
- `list item card` (navigasi/list)

Aturan:

- Satu card = satu tujuan utama
- Jangan campur terlalu banyak badge/ikon/CTA dalam satu card

### State Views

Wajib tersedia untuk screen data-driven:

- `Loading`: skeleton/spinner sesuai konteks
- `Empty`: pesan spesifik + CTA berikutnya
- `Error`: sebab ringkas + tombol retry

## Screen Guidance (V1 Prioritas)

### Login / Register

- Fokus pada form usability, bukan dekorasi berlebihan
- CTA utama harus langsung terlihat tanpa scroll (device umum)
- Pesan error harus dekat dengan konteks
- Ornamen/pattern boleh ada, tapi opacity rendah dan tidak mengganggu form

### Home / Beranda

- Prioritaskan hierarki section (top content > fitur utama > konten tambahan)
- Kurangi kompetisi visual antar card
- Pastikan section title dan CTA "lihat semua" konsisten
- Gunakan ritme spacing yang stabil agar screen panjang tetap enak dibaca

### Edukasi / Quiz / Sertifikat

- Fokus progress dan status (jelas, bukan dekoratif)
- CTA "lanjutkan", "submit", "generate" harus paling dominan
- State loading/error untuk network wajib jelas

### Profile

- Kelompokkan menu berdasarkan fungsi (akun, aktivitas, bantuan, logout)
- Hindari daftar menu terlalu datar tanpa hierarki

## No-Slop Review Checklist (Per PR UI)

- [ ] Screen punya fokus utama yang jelas
- [ ] Tidak ada hardcoded warna acak yang keluar dari token
- [ ] Spacing mengikuti scale
- [ ] CTA utama paling menonjol
- [ ] State `loading/empty/error` jelas (jika screen data-driven)
- [ ] Copy tidak generik ("No data", "Something went wrong") tanpa konteks
- [ ] Visual konsisten dengan login/home/edukasi V1

## Catatan Implementasi

- V1 tidak mengejar redesign total semua halaman.
- Mulai dari komponen + flow utama, lalu scale ke screen lain.
- Jika screen lama belum diredesign, minimal sesuaikan token warna/spacing agar tidak bentrok.
