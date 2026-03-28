<!DOCTYPE html>
<html>
<head>
    <title>{{ $subjectText }}</title>
</head>
<body style="font-family: Arial, sans-serif; background-color: #f8fafc; padding: 20px;">
    <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <h2 style="color: #0f172a; text-align: center; font-size: 24px;">🛡️ Averroes Crypto Syariah</h2>
        <p style="color: #334155; font-size: 16px;">Assalamu'alaikum,</p>
        <p style="color: #334155; font-size: 16px; line-height: 1.5;">{{ $messageText }}</p>
        
        <div style="text-align: center; margin: 30px 0;">
            <span style="display: inline-block; padding: 15px 30px; background-color: #047857; color: #ffffff; font-size: 28px; font-weight: bold; border-radius: 8px; letter-spacing: 6px;">
                {{ $otp }}
            </span>
        </div>
        
        <p style="color: #334155; font-size: 14px; text-align: center; line-height: 1.5; background-color: #fef3c7; padding: 12px; border-radius: 6px;">
            Kode OTP ini bersifat <b>rahasia</b> dan hanya berlaku dalam beberapa waktu ke depan.<br>
            Jangan berikan, menyalin, atau memperlihatkan kode ini kepada siapa pun guna mitigasi risiko pembajakan akun Anda.
        </p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 30px 0;">
        <p style="color: #94a3b8; font-size: 12px; text-align: center;">
            &copy; {{ date('Y') }} Averroes - Platform Filter dan Edukasi Aset Kripto Syariah.<br>
            Pesan digital ini disalurkan secara otomatis melalui sistem komputasi terverifikasi, mohon tidak membalas email ini.
        </p>
    </div>
</body>
</html>
