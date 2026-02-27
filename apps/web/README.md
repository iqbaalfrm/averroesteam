# Averroes Web (Scaffold)

Folder ini disiapkan untuk frontend web terpisah jika dibutuhkan.

Status saat ini:
- Scaffold struktur saja (belum memilih framework final).
- Gunakan saat tim memutuskan implementasi web app/dashboard terpisah dari mobile.

## Struktur Awal

- `src/app/` : bootstrap app
- `src/features/` : feature modules
- `src/shared/` : komponen/util reusable
- `src/lib/` : helper low-level/client
- `public/` : static assets
- `tests/` : test web

## Keputusan yang Perlu Ditentukan Sebelum Implementasi

- Framework: React / Next.js / Vue / lainnya
- Styling system: CSS Modules / Tailwind / design system internal
- API integration strategy: shared contract/openapi/manual client
