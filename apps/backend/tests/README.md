# Backend Tests

Folder ini untuk test backend terotomasi (unit/integration) dan fixtures.

Contoh target bertahap:
- test auth (`register/login/guest/lupa-password/reset-password`)
- test LMS flow (`kelas -> materi -> quiz -> progress -> sertifikat`)
- test regression untuk response shape (`status/pesan/message`)

Catatan:
- Smoke test manual/CLI saat ini ada di `scripts/backend_smoke_auth_lms.py`.
