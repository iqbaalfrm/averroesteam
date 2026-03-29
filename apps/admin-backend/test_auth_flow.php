<?php
require __DIR__.'/vendor/autoload.php';
$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Illuminate\Http\Request;
use App\Http\Controllers\Api\AuthController;
use Illuminate\Support\Facades\Validator;

$controller = app(AuthController::class);

echo "Membersihkan users lama...\n";
User::query()->delete();

try {
    // Register
    $request = Request::create('/api/auth/register', 'POST', [
        'nama_lengkap' => 'Tes Pengguna',
        'email' => 'auth_test_dummy@example.com',
        'password' => 'rahasia123',
    ]);
    $response = $controller->register($request);
    $data = json_decode($response->getContent(), true);
    echo "1. Register Status: " . ($data['status'] ? 'Berhasil' : 'Gagal') . "\n";
    if(!$data['status']) print_r($data);
    $otp = $data['data']['otp_dummy_skripsi'] ?? null;

    // Validate OTP
    $request = Request::create('/api/auth/verifikasi-otp', 'POST', [
        'email' => 'auth_test_dummy@example.com',
        'otp' => $otp,
    ]);
    $response = $controller->verifyOtp($request);
    $data = json_decode($response->getContent(), true);
    echo "2. Verifikasi OTP: " . ($data['status'] ? 'Berhasil' : 'Gagal') . "\n";
    if(!$data['status']) print_r($data);

    // Login
    $request = Request::create('/api/auth/login', 'POST', [
        'email' => 'auth_test_dummy@example.com',
        'password' => 'rahasia123',
    ]);
    $response = $controller->login($request);
    $data = json_decode($response->getContent(), true);
    echo "3. Login: " . ($data['status'] ? 'Berhasil' : 'Gagal') . "\n";
    if(!$data['status']) print_r($data);

    // Lupa Password
    $request = Request::create('/api/auth/lupa-password', 'POST', [
        'email' => 'auth_test_dummy@example.com'
    ]);
    $response = $controller->forgotPassword($request);
    $data = json_decode($response->getContent(), true);
    echo "4. Persiapan Lupa Sandi: " . ($data['status'] ? 'Berhasil' : 'Gagal') . "\n";
    if(!$data['status']) print_r($data);
    $reset_otp = $data['data']['otp_dummy_skripsi'] ?? null;

    // Reset Password
    $request = Request::create('/api/auth/reset-password', 'POST', [
        'email' => 'auth_test_dummy@example.com',
        'otp' => $reset_otp,
        'new_password' => 'sandi1234'
    ]);
    $response = $controller->resetPassword($request);
    $data = json_decode($response->getContent(), true);
    echo "5. Reset Sandi: " . ($data['status'] ? 'Berhasil' : 'Gagal') . "\n";
    if(!$data['status']) print_r($data);

    // Login Ulang
    $request = Request::create('/api/auth/login', 'POST', [
        'email' => 'auth_test_dummy@example.com',
        'password' => 'sandi1234',
    ]);
    $response = $controller->login($request);
    $data = json_decode($response->getContent(), true);
    echo "6. Login Sandi Baru: " . ($data['status'] ? 'Berhasil' : 'Gagal') . "\n";
    if(!$data['status']) print_r($data);

} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
