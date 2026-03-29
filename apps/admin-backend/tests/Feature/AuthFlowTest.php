<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Foundation\Testing\WithFaker;
use Tests\TestCase;
use App\Models\User;

class AuthFlowTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        // Clear all users for stable test environment via MongoDB query syntax
        User::query()->delete();
    }

    public function test_registrasi_dan_otp_lalu_login()
    {
        // 1. Register
        $response = $this->postJson('/api/auth/register', [
            'nama_lengkap' => 'Tes Pengguna',
            'email' => 'auth_test_dummy@example.com',
            'password' => 'rahasia123',
        ]);

        $response->assertStatus(200);
        $data = $response->json();
        $this->assertTrue($data['status'], "Registrasi gagal");
        $otp = $data['data']['otp_dummy_skripsi'];

        // 2. Coba Login tanpa Verifikasi OTP (seharusnya status=false, ada needs_verification=true)
        $response = $this->postJson('/api/auth/login', [
            'email' => 'auth_test_dummy@example.com',
            'password' => 'rahasia123',
        ]);
        $data = $response->json();
        $this->assertFalse($data['status']);
        $this->assertTrue(isset($data['data']['needs_verification']));

        // 3. Verifikasi OTP
        $response = $this->postJson('/api/auth/verifikasi-otp', [
            'email' => 'auth_test_dummy@example.com',
            'otp' => $otp,
        ]);
        $response->assertStatus(200);
        $this->assertTrue($response->json('status'));

        // 4. Login yang Berhasil
        $response = $this->postJson('/api/auth/login', [
            'email' => 'auth_test_dummy@example.com',
            'password' => 'rahasia123',
        ]);
        $response->assertStatus(200);
        $this->assertTrue($response->json('status'));
        $this->assertNotNull($response->json('data.token'));
    }

    public function test_lupa_dan_reset_password()
    {
        $user = User::create([
            'nama_lengkap' => 'Tester Lupa Password',
            'email' => 'lupa_password@example.com',
            'password' => bcrypt('passwordlawas'),
            'role' => 'user',
            'is_verified' => true,
        ]);

        // 1. Permintaan Lupa Password (Minta OTP)
        $response = $this->postJson('/api/auth/lupa-password', [
            'email' => 'lupa_password@example.com'
        ]);
        $response->assertStatus(200);
        $data = $response->json();
        $this->assertTrue($data['status']);
        $reset_otp = $data['data']['otp_dummy_skripsi'];

        // 2. Eksekusi Reset Password menggunakan OTP
        $response = $this->postJson('/api/auth/reset-password', [
            'email' => 'lupa_password@example.com',
            'otp' => $reset_otp,
            'new_password' => 'passwordsandibaru'
        ]);
        $response->assertStatus(200);
        $this->assertTrue($response->json('status'));

        // 3. Login menggunakan password yang baru
        $response = $this->postJson('/api/auth/login', [
            'email' => 'lupa_password@example.com',
            'password' => 'passwordsandibaru',
        ]);
        $response->assertStatus(200);
        $this->assertTrue($response->json('status'));
    }
}
