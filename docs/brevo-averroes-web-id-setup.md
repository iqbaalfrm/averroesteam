# Brevo Domain Setup

Status saat ini:

- Brevo API sudah terhubung ke Supabase Edge Functions
- sender aktif yang dipakai sekarang: `fileamansentosa@gmail.com` (`sender id = 1`)
- sender domain sudah dibuat: `noreply@averroes.web.id` (`sender id = 2`)
- domain `averroes.web.id` di Brevo masih `verified=false` dan `authenticated=false`

## DNS records yang perlu ditambahkan

Tambahkan record berikut di DNS `averroes.web.id`:

```text
Type: TXT
Host: @
Value: brevo-code:001c6cdc64a9ad368e921bcebcbcb16c
```

```text
Type: CNAME
Host: brevo1._domainkey
Value: b1.averroes-web-id.dkim.brevo.com
```

```text
Type: CNAME
Host: brevo2._domainkey
Value: b2.averroes-web-id.dkim.brevo.com
```

```text
Type: TXT
Host: _dmarc
Value: v=DMARC1; p=none; rua=mailto:rua@dmarc.brevo.com
```

## SPF

Brevo menjelaskan bahwa record SPF mereka memakai:

```text
v=spf1 include:spf.brevo.com mx ~all
```

Kalau domain kamu sudah punya SPF lain, gabungkan jadi satu record saja.

## Setelah DNS verified

Setelah Brevo menandai domain sebagai verified/authenticated, ganti secret Supabase:

```bash
supabase secrets set BREVO_SENDER_ID=2
```

Lalu deploy ulang:

```bash
supabase functions deploy auth-send-otp
supabase functions deploy custom-auth-send-otp
```

Setelah itu email OTP akan keluar dari `noreply@averroes.web.id`.
