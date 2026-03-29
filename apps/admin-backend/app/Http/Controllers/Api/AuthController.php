<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use App\Mail\OtpMail;

class AuthController extends Controller
{
    /**
     * Tampilan Respon Seragam Standar Aplikasi (Sesuai Fiqh Muamalah: Transparansi)
     */
    protected function jsonResponse($status, $pesan, $data = null)
    {
        return response()->json([
            'status' => $status,
            'pesan' => $pesan,
            'data' => $data
        ]);
    }

    public function register(Request $request)
    {
        $request->validate([
            'nama_lengkap' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
        ]);

        // Merumuskan 6 digit kode OTP Otomatis
        $otp = (string) rand(100000, 999999);

        // Proses pendaftaran dengan standar migrasi MongoDB
        $user = User::create([
            'nama_lengkap' => $request->nama_lengkap,
            'email' => $request->email,
            'password' => Hash::make($request->password), // Enkripsi bcrypt bawaan sanctum
            'role' => 'user', // Terapkan Role
            'verify_otp' => $otp,
            'is_verified' => false,
        ]);

        // LOGIKA PENUNJANG: Kirim OTP melalui log & Email
        Log::info("OTP Pendaftaran {$user->email} dikirim: {$otp}");
        
        try {
            Mail::to($user->email)->send(new OtpMail(
                $otp, 
                "Averroes - Verifikasi OTP Pendaftaran Akun", 
                "Terima kasih atas itikad baik Anda untuk mengambil peran mendalami ranah Fiqh. Berikut adalah rincian kode OTP untuk meloloskan registrasi Anda:"
            ));
        } catch (\Exception $e) {
            Log::error("Gagal mengirim email OTP: " . $e->getMessage());
        }

        return $this->jsonResponse(true, 'Registrasi tercatat secara aman. Silakan masukkan kode OTP yang telah disalurkan ke posel (email) Anda.', [
            'otp_dummy_skripsi' => $otp, // Sementara dilempar di response flutter untuk mempermudah tes emulator
            'email' => $user->email,
        ]);
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'nullable|string',
            'kode' => 'nullable|string',
        ]);

        // Kompatibilitas: Terima field 'otp' maupun 'kode' dari Flutter
        $otpInput = $request->otp ?? $request->kode;
        if (!$otpInput) {
            return $this->jsonResponse(false, 'Kode OTP wajib diisi.');
        }

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return $this->jsonResponse(false, 'Miskonsepsi akun: Email ini tidak dijumpai dalam koleksi sistem.');
        }

        if ((string) $user->verify_otp !== (string) $otpInput) {
            return $this->jsonResponse(false, 'Verifikasi tertolak: Kode OTP belum sesuai.');
        }

        // Beres
        $user->is_verified = true;
        $user->verify_otp = null;
        $user->email_verified_at = now();
        $user->save();

        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->jsonResponse(true, 'Verifikasi sempurna. Pendaftaran Anda sepenuhnya sah secara sistem di peladen admin-backend.', [
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => [
                'nama' => $user->nama_lengkap,
                'email' => $user->email,
                'role' => $user->role ?? 'user',
            ]
        ]);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|string|email',
            'password' => 'required|string',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || !Hash::check($request->password, $user->password)) {
            // Dalam prinsip keamanan, pesan error gagal login tidak boleh memberi tahu apanya yang salah (email atau pass).
            return $this->jsonResponse(false, 'Akses masuk dinafikan: Kredensial tidak valid di dalam sistem.');
        }

        if (!$user->is_verified && $user->role === 'user') {
            return $this->jsonResponse(false, 'Sistem mendeteksi bahwa akun Anda belum tervalidasi OTP. Harap verifikasi demi integritas data mitigasi.', ['needs_verification' => true]);
        }

        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->jsonResponse(true, 'Autentikasi diizinkan. Selamat datang di Averroes via Laravel Sanctum!', [
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => [
                'nama' => $user->nama_lengkap,
                'email' => $user->email,
                'role' => $user->role ?? 'user',
            ]
        ]);
    }

    public function forgotPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email'
        ]);

        $user = User::where('email', $request->email)->first();
        if (!$user) {
            return $this->jsonResponse(false, 'Email pengguna tidak tersedia di basis data.');
        }

        $otp = (string) rand(100000, 999999);
        $user->reset_otp = $otp;
        $user->save();

        Log::info("OTP Lupa Kata Sandi {$user->email}: {$otp}");

        try {
            Mail::to($user->email)->send(new OtpMail(
                $otp, 
                "Averroes - Pemulihan Hak Akses (Lupa Kata Sandi)", 
                "Kami mendapatkan titipan permohonan pemulihan sandi atas nama Anda. Selalu perhatikan tata kelola mitigasi kata sandi. Berikut adalah instrumen pemulihan sementaran (OTP) Anda:"
            ));
        } catch (\Exception $e) {
            Log::error("Gagal mengirim email pemulihan: " . $e->getMessage());
        }

        return $this->jsonResponse(true, 'Kode pemulihan mitigasi (OTP) berhasil diterbitkan dan disalurkan ke kotak masuk posel (email) Anda.', [
            'otp_dummy_skripsi' => $otp,
            'email' => $user->email,
        ]);
    }

    public function resetPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'nullable|string',
            'kode' => 'nullable|string',
            'new_password' => 'nullable|string|min:6',
            'password_baru' => 'nullable|string|min:6',
        ]);

        // Kompatibilitas: Terima field 'otp'/'kode' dan 'new_password'/'password_baru'
        $otpInput = $request->otp ?? $request->kode;
        $newPassword = $request->new_password ?? $request->password_baru;

        if (!$otpInput) {
            return $this->jsonResponse(false, 'Kode OTP wajib diisi.');
        }
        if (!$newPassword || strlen($newPassword) < 6) {
            return $this->jsonResponse(false, 'Kata sandi baru wajib diisi (minimal 6 karakter).');
        }

        $user = User::where('email', $request->email)->first();

        if (!$user || (string) $user->reset_otp !== (string) $otpInput) {
            return $this->jsonResponse(false, 'Otorisasi gagal: Sandi mitigasi OTP Anda telah kedaluwarsa atau tidak akurat.');
        }

        $user->password = Hash::make($newPassword);
        $user->reset_otp = null;
        $user->save();

        return $this->jsonResponse(true, 'Pemulihan wewenang akun (Reset Sandi) sukses dilaksanakan secara presisi.');
    }

    public function logout(Request $request)
    {
        // Mencabut token saat ini sehingga tidak berlaku lagi
        $request->user()->currentAccessToken()->delete();

        return $this->jsonResponse(true, 'Hubungan akses berhasil diputus. Sesi otentikasi Anda telah diakhiri secara aman.');
    }

    /**
     * Bug #11: Kirim ulang OTP Registrasi
     */
    public function resendOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return $this->jsonResponse(false, 'Email tidak ditemukan dalam sistem.');
        }

        if ($user->is_verified) {
            return $this->jsonResponse(false, 'Akun ini sudah terverifikasi. Silakan langsung masuk (login).');
        }

        $otp = (string) rand(100000, 999999);
        $user->verify_otp = $otp;
        $user->save();

        Log::info("Resend OTP Pendaftaran {$user->email}: {$otp}");

        try {
            Mail::to($user->email)->send(new OtpMail(
                $otp,
                "Averroes - Kirim Ulang Kode OTP Pendaftaran",
                "Berikut adalah kode OTP terbaru Anda untuk menyelesaikan proses registrasi:"
            ));
        } catch (\Exception $e) {
            Log::error("Gagal mengirim ulang email OTP: " . $e->getMessage());
        }

        return $this->jsonResponse(true, 'Kode OTP baru berhasil diterbitkan.', [
            'otp_dummy_skripsi' => $otp,
            'email' => $user->email,
        ]);
    }

    /**
     * Bug #12: Login Tamu (Guest) — Kompatibilitas dengan Flutter
     */
    public function guestLogin()
    {
        $guest = User::create([
            'nama_lengkap' => 'Pengguna Tamu',
            'email' => 'guest_' . uniqid() . '@averroes.local',
            'password' => Hash::make(bin2hex(random_bytes(16))),
            'role' => 'guest',
            'is_verified' => true,
        ]);

        $token = $guest->createToken('guest_token')->plainTextToken;

        return $this->jsonResponse(true, 'Login tamu berhasil', [
            'token' => $token,
            'user' => [
                'nama' => $guest->nama_lengkap,
                'email' => $guest->email,
                'role' => $guest->role,
            ]
        ]);
    }

    /**
     * Bug #12: Login Google — Kompatibilitas dengan Flutter
     */
    public function googleLogin(Request $request)
    {
        $request->validate([
            'id_token' => 'required|string',
        ]);

        // Placeholder: Untuk implementasi penuh, validasi id_token via Google API
        // Sementara ini mengembalikan pesan bahwa fitur belum aktif
        return $this->jsonResponse(false, 'Login Google belum dikonfigurasi di peladen Laravel. Silakan gunakan email/kata sandi.');
    }
}
