<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

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

        // LOGIKA PENUNJANG: Kirim OTP melalui log & API respon untuk masa percobaan skripsi
        Log::info("OTP Pendaftaran {$user->email} dikirim: {$otp}");

        return $this->jsonResponse(true, 'Registrasi tercatat secara aman. Silakan masukkan kode OTP yang telah disalurkan.', [
            'otp_dummy_skripsi' => $otp, // Sementara dilempar di response flutter untuk mempermudah tes emulator
            'email' => $user->email,
        ]);
    }

    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'required|string'
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return $this->jsonResponse(false, 'Miskonsepsi akun: Email ini tidak dijumpai dalam koleksi sistem.');
        }

        if ((string) $user->verify_otp !== (string) $request->otp) {
            return $this->jsonResponse(false, 'Verifikasi tertolak: Kode OTP belum sesuai.');
        }

        // Beres
        $user->is_verified = true;
        $user->verify_otp = null;
        $user->email_verified_at = now();
        $user->save();

        $token = $user->createToken('auth_token')->plainTextToken;

        return $this->jsonResponse(true, 'Verifikasi sempurna. Pendaftaran Anda sepenuhnya sah secara sistem di peladen admin-backend.', [
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => [
                'nama_lengkap' => $user->nama_lengkap,
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
            'access_token' => $token,
            'token_type' => 'Bearer',
            'user' => [
                'nama_lengkap' => $user->nama_lengkap,
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

        return $this->jsonResponse(true, 'Kode pemulihan mitigasi (OTP) berhasil diterbitkan untuk akun ini.', [
            'otp_dummy_skripsi' => $otp,
            'email' => $user->email,
        ]);
    }

    public function resetPassword(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'otp' => 'required|string',
            'new_password' => 'required|string|min:6'
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user || (string) $user->reset_otp !== (string) $request->otp) {
            return $this->jsonResponse(false, 'Otorisasi gagal: Sandi mitigasi OTP Anda telah kedaluwarsa atau tidak akurat.');
        }

        $user->password = Hash::make($request->new_password);
        $user->reset_otp = null;
        $user->save();

        return $this->jsonResponse(true, 'Pemulihan wewenang akun (Reset Sandi) sukses dilaksanakan secara presisi.');
    }
}
