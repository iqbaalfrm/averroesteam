$baseUrl = "http://127.0.0.1:8000/api/auth"
$headers = @{Accept="application/json"}

function ApiPost($path, $body) {
    try {
        $r = Invoke-WebRequest -Uri "$baseUrl$path" -Method POST -ContentType "application/json" -Headers $headers -Body $body -UseBasicParsing
        return $r.Content | ConvertFrom-Json
    } catch {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $errBody = $reader.ReadToEnd()
        return $errBody | ConvertFrom-Json
    }
}

Write-Host "`n=== 1. REGISTER ===" -ForegroundColor Cyan
$reg = ApiPost "/register" '{"nama_lengkap":"Iqbal Tes Auth","email":"iqbal_tes_auth@averroes.com","password":"rahasia123"}'
Write-Host "Status: $($reg.status) | Pesan: $($reg.pesan)"
$otp = $reg.data.otp_dummy_skripsi
Write-Host "OTP yang diterima: $otp"

Write-Host "`n=== 2. LOGIN TANPA VERIFIKASI (harus gagal) ===" -ForegroundColor Cyan
$login1 = ApiPost "/login" '{"email":"iqbal_tes_auth@averroes.com","password":"rahasia123"}'
Write-Host "Status: $($login1.status) | Pesan: $($login1.pesan)"

Write-Host "`n=== 3. VERIFIKASI OTP ===" -ForegroundColor Cyan
$verify = ApiPost "/verifikasi-otp" "{`"email`":`"iqbal_tes_auth@averroes.com`",`"kode`":`"$otp`"}"
Write-Host "Status: $($verify.status) | Pesan: $($verify.pesan)"
Write-Host "Token diterima: $($verify.data.token -ne $null)"

Write-Host "`n=== 4. LOGIN SETELAH VERIFIKASI (harus berhasil) ===" -ForegroundColor Cyan
$login2 = ApiPost "/login" '{"email":"iqbal_tes_auth@averroes.com","password":"rahasia123"}'
Write-Host "Status: $($login2.status) | Pesan: $($login2.pesan)"
Write-Host "Token: $($login2.data.token -ne $null) | Nama: $($login2.data.user.nama) | Role: $($login2.data.user.role)"

Write-Host "`n=== 5. LUPA PASSWORD ===" -ForegroundColor Cyan
$lupa = ApiPost "/lupa-password" '{"email":"iqbal_tes_auth@averroes.com"}'
Write-Host "Status: $($lupa.status) | Pesan: $($lupa.pesan)"
$resetOtp = $lupa.data.otp_dummy_skripsi
Write-Host "Reset OTP: $resetOtp"

Write-Host "`n=== 6. RESET PASSWORD ===" -ForegroundColor Cyan
$reset = ApiPost "/reset-password" "{`"email`":`"iqbal_tes_auth@averroes.com`",`"kode`":`"$resetOtp`",`"password_baru`":`"sandibaru456`"}"
Write-Host "Status: $($reset.status) | Pesan: $($reset.pesan)"

Write-Host "`n=== 7. LOGIN DENGAN PASSWORD BARU ===" -ForegroundColor Cyan
$login3 = ApiPost "/login" '{"email":"iqbal_tes_auth@averroes.com","password":"sandibaru456"}'
Write-Host "Status: $($login3.status) | Pesan: $($login3.pesan)"
$token = $login3.data.token

Write-Host "`n=== 8. LOGOUT ===" -ForegroundColor Cyan
try {
    $r = Invoke-WebRequest -Uri "$baseUrl/logout" -Method POST -ContentType "application/json" -Headers @{Accept="application/json"; Authorization="Bearer $token"} -UseBasicParsing
    $logout = $r.Content | ConvertFrom-Json
    Write-Host "Status: $($logout.status) | Pesan: $($logout.pesan)"
} catch {
    Write-Host "Logout error: $_"
}

Write-Host "`n=== 9. GUEST LOGIN ===" -ForegroundColor Cyan
$guest = ApiPost "/guest" '{}'
Write-Host "Status: $($guest.status) | Nama: $($guest.data.user.nama) | Role: $($guest.data.user.role)"

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "SEMUA TES SELESAI!" -ForegroundColor Green
