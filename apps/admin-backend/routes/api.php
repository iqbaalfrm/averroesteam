<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;

Route::prefix('auth')->group(function () {
    // Terapkan pembatasan laju akses mitigasi (Maksimal 6 permintaan per menit)
    Route::middleware('throttle:6,1')->group(function () {
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/verifikasi-otp', [AuthController::class, 'verifyOtp']);
        Route::post('/resend-otp', [AuthController::class, 'resendOtp']);
        Route::post('/login', [AuthController::class, 'login']);
        Route::post('/lupa-password', [AuthController::class, 'forgotPassword']);
        Route::post('/reset-password', [AuthController::class, 'resetPassword']);
        Route::post('/guest', [AuthController::class, 'guestLogin']);
        Route::post('/google', [AuthController::class, 'googleLogin']);
    });
    
    // Rute Keluaran (Logout) membutuhkan autentikasi
    Route::middleware('auth:sanctum')->post('/logout', [AuthController::class, 'logout']);
});

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', function (Request $request) {
        return response()->json([
            'status' => true,
            'pesan' => 'Profil berhasil ditarik',
            'data' => $request->user(),
        ]);
    });
});
