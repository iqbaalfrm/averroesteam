# Averroes Mobile (Flutter)

Runbook singkat untuk development, UAT, dan build release mobile.

## Prasyarat

- Flutter SDK terpasang (`flutter --version`)
- Device/emulator siap
- Backend Averroes aktif (lokal/staging/production)

## Setup Environment

App membaca file `.env` (lihat `lib/bootstrap.dart`).

### Development (lokal)

```bash
cd apps/mobile
copy .env.example .env
flutter pub get
flutter run
```

Default `API_BASE_URL` dev (emulator Android): `http://10.0.2.2:8080`

### Staging

```bash
cd apps/mobile
copy .env.staging.example .env
```

Lalu ubah `API_BASE_URL` ke domain staging final.

### Production

```bash
cd apps/mobile
copy .env.production.example .env
```

Lalu ubah `API_BASE_URL` ke domain production final.

## Validasi Sebelum UAT

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

Catatan:
- Jika ada warning lama yang belum dibersihkan, catat sebagai known issue.
- Pastikan `.env` yang aktif mengarah ke backend target UAT.

## Build Release

### Android APK (uji internal cepat)

```bash
cd apps/mobile
flutter build apk --release
```

### Android App Bundle (Play Store/internal testing)

```bash
cd apps/mobile
flutter build appbundle --release
```

### iOS (jika dipakai)

```bash
cd apps/mobile
flutter build ios --release
```

Pastikan signing Android/iOS sudah dikonfigurasi sebelum build final.

## Play Store Readiness (Android)

Checklist teknis minimum sebelum upload `aab`:

- Ubah `applicationId` dan `namespace` ke ID final (bukan `com.example...`) di `android/app/build.gradle.kts`.
- Siapkan keystore release dan isi `android/key.properties` (lihat contoh: `android/key.properties.example`).
- Pastikan `API_BASE_URL` production sudah HTTPS (release build mematikan cleartext).
- Update `version` di `pubspec.yaml` (versionName + versionCode).
- Pastikan `android:label` sesuai nama app publik.
- Siapkan URL Privacy Policy untuk Play Console (wajib).

Langkah signing (ringkas):

```bash
cd apps/mobile/android
copy key.properties.example key.properties
```

Lalu isi `storeFile`, `storePassword`, `keyAlias`, `keyPassword` sesuai keystore rilis.

## Checklist UAT Mobile (Flow Kritis)

Checklist minimum yang harus dicek manual:

- [ ] Login email/password berhasil
- [ ] Register berhasil lalu bisa login
- [ ] Login tamu berhasil
- [ ] Lupa password -> verifikasi OTP -> reset password berhasil
- [ ] Home/Beranda tampil tanpa error/overflow
- [ ] Edukasi: list kelas tampil (`loading/empty/error` state masuk akal)
- [ ] Detail kelas tampil (modul/materi/quiz)
- [ ] Materi bisa ditandai selesai
- [ ] Quiz submit berhasil dan feedback jelas
- [ ] Progress kelas tampil benar
- [ ] Sertifikat bisa generate saat syarat terpenuhi
- [ ] Screener tampil (termasuk fallback saat request gagal)
- [ ] Logout lalu login ulang (token persistence / reset state OK)

## Troubleshooting Singkat

- `dotenv load gagal`: pastikan file `.env` ada di `apps/mobile/`.
- Request timeout / API tidak jalan: cek `API_BASE_URL` dan status backend target.
- Android emulator tidak bisa akses localhost host machine: gunakan `http://10.0.2.2:<port>`.

## Catatan Release

- Tentukan `API_BASE_URL` staging/production final sebelum UAT/release.
- Update versioning di `pubspec.yaml` sebelum build final.
- Simpan secret/API key di luar repo untuk environment produksi jika memungkinkan.
