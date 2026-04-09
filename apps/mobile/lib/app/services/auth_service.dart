import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'privy_wallet_service.dart';
import 'supabase_native_service.dart';

class AuthFlowResult {
  const AuthFlowResult({
    required this.success,
    this.requiresVerification = false,
    this.message,
    this.user,
  });

  final bool success;
  final bool requiresVerification;
  final String? message;
  final Map<String, dynamic>? user;
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  final GetStorage _box = GetStorage();
  bool _initialized = false;

  bool get _isSupabaseEnabled => AppConfig.isSupabaseAuthEnabled;
  bool get _isCustomOtpEnabled =>
      _isSupabaseEnabled && AppConfig.isSupabaseCustomOtpEnabled;
  String get _authApiBaseUrl => AppConfig.authApiBaseUrl;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    if (_isSupabaseEnabled) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl!,
        anonKey: AppConfig.supabaseAnonKey!,
      );
      Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) async {
          await _cacheSupabaseSession();
        },
      );
      await _cacheSupabaseSession();
      if (sudahLogin) {
        await syncProfileFromBackend(silent: true);
        await _syncPrivyWalletSilently();
      }
    }
    _initialized = true;
  }

  Future<void> simpanToken(String token) async {
    await _box.write(_tokenKey, token);
  }

  Future<void> simpanUser(Map<String, dynamic> user) async {
    await _box.write(_userKey, user);
  }

  Future<void> simpanAuth(String token, Map<String, dynamic> user) async {
    await _box.write(_tokenKey, token);
    await _box.write(_userKey, user);
  }

  String? get token {
    if (_isSupabaseEnabled) {
      final String? accessToken =
          Supabase.instance.client.auth.currentSession?.accessToken;
      if (accessToken != null && accessToken.isNotEmpty) {
        return accessToken;
      }
    }
    return _box.read<String>(_tokenKey);
  }

  Map<String, dynamic>? get user {
    final dynamic data = _box.read(_userKey);
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    if (_isSupabaseEnabled) {
      final User? currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        return _basicSupabaseUser(currentUser);
      }
    }
    return null;
  }

  String? get role {
    final Map<String, dynamic>? u = user;
    if (u == null) {
      return null;
    }
    final raw = u['Role'] as String? ?? u['role'] as String?;
    return raw?.trim().toLowerCase();
  }

  String get namaUser {
    final Map<String, dynamic>? u = user;
    if (u == null) {
      return 'Pengguna';
    }
    final String nama = (u['Nama'] as String? ?? u['nama'] as String?) ?? '';
    return nama.isNotEmpty ? nama : 'Pengguna';
  }

  bool get sudahLogin {
    final String? activeToken = token;
    return activeToken != null && activeToken.isNotEmpty;
  }

  bool get adalahTamu {
    if (role == 'guest') {
      return true;
    }
    final Map<String, dynamic>? u = user;
    final String nama =
        ((u?['Nama'] as String?) ?? (u?['nama'] as String?) ?? '')
            .trim()
            .toLowerCase();
    final String email = ((u?['email'] as String?) ?? '').trim();
    return nama == 'pengguna tamu' && email.isEmpty;
  }

  bool get adalahUserTerdaftar =>
      sudahLogin && (role == 'user' || role == 'admin');

  Future<AuthFlowResult> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (_isSupabaseEnabled) {
      try {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        await _cacheSupabaseSession();
        final Map<String, dynamic>? profile =
            await syncProfileFromBackend(silent: true);
        await _syncPrivyWalletSilently();
        return AuthFlowResult(
          success: true,
          user: profile ?? user,
          message: 'Login berhasil',
        );
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Terjadi kesalahan saat login');
      }
    }
    return _legacyEmailLogin(email: email, password: password);
  }

  Future<AuthFlowResult> signUpWithEmailPassword({
    required String nama,
    required String email,
    required String password,
  }) async {
    if (_isCustomOtpEnabled) {
      final Map<String, dynamic> payload = await _invokeCustomOtpFunction(
        'auth-send-otp',
        <String, dynamic>{
          'mode': 'signup',
          'email': email.trim(),
          'full_name': nama.trim(),
          'password': password,
        },
      );
      return AuthFlowResult(
        success: true,
        requiresVerification: true,
        message: payload['message']?.toString() ??
            'Registrasi berhasil. Kode OTP ${AppConfig.otpLength} digit telah dikirim ke email Anda',
      );
    }

    if (_isSupabaseEnabled) {
      try {
        final AuthResponse response =
            await Supabase.instance.client.auth.signUp(
          email: email.trim(),
          password: password,
          data: <String, dynamic>{
            'full_name': nama.trim(),
            'name': nama.trim(),
          },
          emailRedirectTo: AppConfig.supabaseRedirectUrl,
        );
        await _cacheSupabaseSession();
        final bool requiresVerification = response.session == null;
        if (!requiresVerification) {
          await syncProfileFromBackend(silent: true);
          await _syncPrivyWalletSilently();
        }
        return AuthFlowResult(
          success: true,
          requiresVerification: requiresVerification,
          message: requiresVerification
              ? 'Registrasi berhasil. Kode OTP telah dikirim ke email Anda'
              : 'Registrasi berhasil',
          user: user,
        );
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Terjadi kesalahan saat registrasi');
      }
    }
    return _legacyRegister(nama: nama, email: email, password: password);
  }

  Future<AuthFlowResult> verifyOtp({
    required String email,
    required String otp,
    required String mode,
    String? password,
  }) async {
    if (_isCustomOtpEnabled) {
      final String normalizedMode = _normalizeOtpMode(mode);
      final Map<String, dynamic> payload = await _invokeCustomOtpFunction(
        'auth-send-otp',
        <String, dynamic>{
          'mode': normalizedMode,
          'email': email.trim(),
          'otp': otp.trim(),
        },
      );
      if (normalizedMode == 'signup' &&
          password != null &&
          password.trim().isNotEmpty) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        await _cacheSupabaseSession();
        await syncProfileFromBackend(silent: true);
        await _syncPrivyWalletSilently();
      }
      return AuthFlowResult(
        success: true,
        requiresVerification: false,
        message: payload['message']?.toString() ??
            (normalizedMode == 'signup'
                ? 'Email berhasil diverifikasi'
                : 'Kode OTP valid'),
        user: user,
      );
    }

    if (_isSupabaseEnabled) {
      try {
        final OtpType type =
            mode == 'register' ? OtpType.signup : OtpType.recovery;
        await Supabase.instance.client.auth.verifyOTP(
          email: email.trim(),
          token: otp.trim(),
          type: type,
        );
        await _cacheSupabaseSession();
        if (mode == 'register') {
          await syncProfileFromBackend(silent: true);
          await _syncPrivyWalletSilently();
        }
        return AuthFlowResult(
          success: true,
          requiresVerification: false,
          message: mode == 'register'
              ? 'Email berhasil diverifikasi'
              : 'Kode OTP valid',
          user: user,
        );
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Verifikasi OTP gagal');
      }
    }
    return _legacyVerifyOtp(email: email, otp: otp, mode: mode);
  }

  Future<void> resendOtp({
    required String email,
    required String mode,
  }) async {
    if (_isCustomOtpEnabled) {
      await _invokeCustomOtpFunction(
        'auth-send-otp',
        <String, dynamic>{
          'mode': _normalizeOtpMode(mode),
          'email': email.trim(),
          'is_resend': true,
        },
      );
      return;
    }

    if (_isSupabaseEnabled) {
      try {
        if (mode == 'register') {
          await Supabase.instance.client.auth.resend(
            type: OtpType.signup,
            email: email.trim(),
          );
        } else {
          await Supabase.instance.client.auth.resetPasswordForEmail(
            email.trim(),
            redirectTo: AppConfig.supabaseRedirectUrl,
          );
        }
        return;
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Gagal mengirim ulang OTP');
      }
    }

    if (mode == 'register') {
      await _legacyPost(
        '/api/auth/resend-otp-register',
        data: <String, dynamic>{'email': email.trim()},
      );
    } else {
      await _legacyPost(
        '/api/auth/lupa-password',
        data: <String, dynamic>{'email': email.trim()},
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (_isCustomOtpEnabled) {
      await _invokeCustomOtpFunction(
        'auth-send-otp',
        <String, dynamic>{
          'mode': 'recovery',
          'email': email.trim(),
        },
      );
      return;
    }

    if (_isSupabaseEnabled) {
      try {
        await Supabase.instance.client.auth.resetPasswordForEmail(
          email.trim(),
          redirectTo: AppConfig.supabaseRedirectUrl,
        );
        return;
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Gagal mengirim OTP reset password');
      }
    }

    await _legacyPost(
      '/api/auth/lupa-password',
      data: <String, dynamic>{'email': email.trim()},
    );
  }

  Future<void> updateRecoveredPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    if (_isCustomOtpEnabled) {
      await _invokeCustomOtpFunction(
        'custom-auth-reset-password',
        <String, dynamic>{
          'email': email.trim(),
          'otp': otp.trim(),
          'new_password': newPassword,
        },
      );
      return;
    }

    if (_isSupabaseEnabled) {
      try {
        if (Supabase.instance.client.auth.currentSession == null) {
          await Supabase.instance.client.auth.verifyOTP(
            email: email.trim(),
            token: otp.trim(),
            type: OtpType.recovery,
          );
        }
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );
        await logout();
        return;
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Gagal mengubah password');
      }
    }

    await _legacyPost(
      '/api/auth/reset-password',
      data: <String, dynamic>{
        'email': email.trim(),
        'kode': otp.trim(),
        'password_baru': newPassword,
      },
    );
  }

  Future<AuthFlowResult> signInWithGoogle({
    required String idToken,
    required String accessToken,
  }) async {
    if (_isSupabaseEnabled) {
      try {
        await Supabase.instance.client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        await _cacheSupabaseSession();
        final Map<String, dynamic>? profile =
            await syncProfileFromBackend(silent: true);
        await _syncPrivyWalletSilently();
        return AuthFlowResult(
          success: true,
          user: profile ?? user,
          message: 'Login Google berhasil',
        );
      } on AuthException catch (error) {
        throw Exception(_mapSupabaseError(error.message));
      } catch (_) {
        throw Exception('Login Google gagal');
      }
    }
    return _legacyGoogleLogin(idToken: idToken);
  }

  Future<AuthFlowResult> signInGuest() async {
    if (_isSupabaseEnabled) {
      try {
        await Supabase.instance.client.auth
            .signInAnonymously(
          data: const <String, dynamic>{
            'name': 'Pengguna Tamu',
            'role': 'guest',
          },
        )
            .timeout(const Duration(seconds: 20));
        await _cacheSupabaseSession();
        final Map<String, dynamic>? profile =
            await syncProfileFromBackend(silent: true);
        return AuthFlowResult(
          success: true,
          user: profile ?? user,
          message: 'Login tamu berhasil',
        );
      } on AuthException catch (error) {
        if (_shouldFallbackGuestAuth(error.message) &&
            !AppConfig.isSupabaseNativeEnabled) {
          return _legacyGuestLogin();
        }
        throw Exception(_mapSupabaseError(error.message));
      } on TimeoutException {
        throw Exception(
          AppConfig.isSupabaseNativeEnabled
              ? 'Login tamu timeout. Cek koneksi internet atau status Supabase Auth'
              : 'Login tamu timeout. Silakan coba lagi',
        );
      } catch (_) {
        if (AppConfig.isSupabaseNativeEnabled) {
          throw Exception(
            'Login tamu gagal. Pastikan Anonymous sign-ins aktif di Supabase Auth',
          );
        }
        return _legacyGuestLogin();
      }
    }
    return _legacyGuestLogin();
  }

  Future<Map<String, dynamic>?> syncProfileFromBackend(
      {bool silent = false}) async {
    if (_isSupabaseEnabled && SupabaseNativeService.isEnabled) {
      try {
        final Map<String, dynamic> profile =
            await SupabaseNativeService.ensureProfile();
        final Map<String, dynamic> shaped =
            SupabaseNativeService.toLegacyProfileShape(profile);
        final String? accessToken = token;
        if (accessToken != null && accessToken.isNotEmpty) {
          await simpanAuth(accessToken, shaped);
        } else {
          await simpanUser(shaped);
        }
        return shaped;
      } catch (_) {
        if (!silent) {
          rethrow;
        }
        return user;
      }
    }

    if (AppConfig.isSupabaseNativeEnabled) {
      if (!silent) {
        throw Exception(
          'Legacy auth backend dimatikan saat SUPABASE_NATIVE_ENABLED=true',
        );
      }
      return user;
    }

    final String? accessToken = token;
    if (accessToken == null || accessToken.isEmpty) {
      return user;
    }

    final Dio dio = Dio(
      BaseOptions(
        baseUrl: _authApiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    try {
      final Response<dynamic> response =
          await dio.get<dynamic>('/api/auth/sync');
      final Map<String, dynamic> payload =
          _extractSuccessPayload(response.data);
      final dynamic userData = payload['user'];
      if (userData is Map) {
        final Map<String, dynamic> typed = userData.cast<String, dynamic>();
        await simpanAuth(accessToken, typed);
        return typed;
      }
      await simpanToken(accessToken);
      return user;
    } catch (_) {
      if (!silent) {
        rethrow;
      }
      await simpanToken(accessToken);
      return user;
    }
  }

  Future<void> logout() async {
    if (_isSupabaseEnabled) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    await _box.remove(_tokenKey);
    await _box.remove(_userKey);
  }

  Future<void> _cacheSupabaseSession() async {
    if (!_isSupabaseEnabled) {
      return;
    }
    final Session? session = Supabase.instance.client.auth.currentSession;
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    if (session == null || currentUser == null) {
      await _box.remove(_tokenKey);
      await _box.remove(_userKey);
      return;
    }
    await simpanAuth(
      session.accessToken,
      _basicSupabaseUser(currentUser),
    );
  }

  Map<String, dynamic> _basicSupabaseUser(User currentUser) {
    final Map<String, dynamic> meta =
        currentUser.userMetadata ?? <String, dynamic>{};
    final bool isAnonymous = currentUser.isAnonymous;
    final String? email = currentUser.email;
    return <String, dynamic>{
      'id': currentUser.id,
      'email': email,
      'nama': (meta['full_name'] ??
              meta['name'] ??
              (isAnonymous ? 'Pengguna Tamu' : 'Pengguna'))
          .toString(),
      'role': (meta['role'] ?? (isAnonymous ? 'guest' : 'user')).toString(),
      'supabase_user_id': currentUser.id,
    };
  }

  Future<AuthFlowResult> _legacyEmailLogin({
    required String email,
    required String password,
  }) async {
    final Response<dynamic> response = await _legacyPost(
      '/api/auth/login',
      data: <String, dynamic>{
        'email': email.trim(),
        'password': password,
      },
    );
    return _consumeLegacyAuthResponse(response.data,
        fallbackMessage: 'Login berhasil');
  }

  Future<AuthFlowResult> _legacyRegister({
    required String nama,
    required String email,
    required String password,
  }) async {
    final Response<dynamic> response = await _legacyPost(
      '/api/auth/register',
      data: <String, dynamic>{
        'nama': nama.trim(),
        'email': email.trim(),
        'password': password,
      },
    );
    final Map<String, dynamic> payload = _extractSuccessPayload(response.data);
    return AuthFlowResult(
      success: true,
      requiresVerification: payload['requires_verification'] == true,
      message: _extractMessage(
        response.data,
        fallback: 'Registrasi berhasil. Kode OTP telah dikirim ke email Anda',
      ),
      user: payload['user'] is Map
          ? (payload['user'] as Map).cast<String, dynamic>()
          : null,
    );
  }

  Future<AuthFlowResult> _legacyVerifyOtp({
    required String email,
    required String otp,
    required String mode,
  }) async {
    final String endpoint = mode == 'register'
        ? '/api/auth/verifikasi-otp-register'
        : '/api/auth/verifikasi-otp';
    final Response<dynamic> response = await _legacyPost(
      endpoint,
      data: <String, dynamic>{'email': email.trim(), 'kode': otp.trim()},
    );
    if (mode == 'register') {
      return _consumeLegacyAuthResponse(
        response.data,
        fallbackMessage: 'Email berhasil diverifikasi',
      );
    }
    return AuthFlowResult(
      success: true,
      message: _extractMessage(response.data, fallback: 'Kode OTP valid'),
    );
  }

  Future<AuthFlowResult> _legacyGoogleLogin({
    required String idToken,
  }) async {
    final Response<dynamic> response = await _legacyPost(
      '/api/auth/google',
      data: <String, dynamic>{'id_token': idToken},
    );
    return _consumeLegacyAuthResponse(
      response.data,
      fallbackMessage: 'Login Google berhasil',
    );
  }

  Future<AuthFlowResult> _legacyGuestLogin() async {
    final Response<dynamic> response = await _legacyPost('/api/auth/guest');
    return _consumeLegacyAuthResponse(
      response.data,
      fallbackMessage: 'Login tamu berhasil',
    );
  }

  Future<Response<dynamic>> _legacyPost(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (AppConfig.isSupabaseNativeEnabled) {
      throw Exception(
        'Legacy auth backend dimatikan saat SUPABASE_NATIVE_ENABLED=true',
      );
    }

    final Dio dio = Dio(
      BaseOptions(
        baseUrl: _authApiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );
    try {
      return await dio.post<dynamic>(path, data: data);
    } on DioException catch (error) {
      throw Exception(
        _extractMessage(
          error.response?.data,
          fallback: 'Permintaan auth gagal',
        ),
      );
    }
  }

  Future<AuthFlowResult> _consumeLegacyAuthResponse(
    dynamic data, {
    required String fallbackMessage,
  }) async {
    final Map<String, dynamic> payload = _extractSuccessPayload(data);
    final String? accessToken = payload['token'] as String?;
    final Map<String, dynamic> userData = payload['user'] is Map
        ? (payload['user'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(
          _extractMessage(data, fallback: 'Respons auth tidak valid'));
    }
    await simpanAuth(accessToken, userData);
    return AuthFlowResult(
      success: true,
      user: userData,
      message: _extractMessage(data, fallback: fallbackMessage),
    );
  }

  Map<String, dynamic> _extractSuccessPayload(dynamic data) {
    if (data is Map<String, dynamic>) {
      final dynamic inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return inner;
      }
      if (inner is Map) {
        return inner.cast<String, dynamic>();
      }
    }
    throw Exception(
        _extractMessage(data, fallback: 'Respons auth tidak valid'));
  }

  String _extractMessage(dynamic data, {required String fallback}) {
    if (data is Map<String, dynamic>) {
      final String? pesan = data['pesan']?.toString();
      if (pesan != null && pesan.isNotEmpty) {
        return pesan;
      }
      final String? message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }

  String _mapSupabaseError(String message) {
    final String lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Email atau password salah';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Silakan cek OTP di email Anda';
    }
    if (lower.contains('user already registered')) {
      return 'Email sudah terdaftar';
    }
    if (lower.contains('otp') && lower.contains('expired')) {
      return 'Kode OTP sudah kedaluwarsa';
    }
    if (lower.contains('otp') && lower.contains('invalid')) {
      return 'Kode OTP tidak valid';
    }
    if (lower.contains('anonymous sign-ins are disabled')) {
      return 'Login tamu belum diaktifkan di Supabase';
    }
    if (lower.contains('signup') &&
        (lower.contains('disabled') || lower.contains('not allowed'))) {
      return 'Login tamu belum diaktifkan di Supabase';
    }
    if (lower.contains('anonymous') &&
        (lower.contains('disabled') ||
            lower.contains('not enabled') ||
            lower.contains('not allowed'))) {
      return 'Login tamu belum diaktifkan di Supabase';
    }
    return message;
  }

  bool _shouldFallbackGuestAuth(String message) {
    final String lower = message.toLowerCase();
    return lower.contains('anonymous sign-ins are disabled') ||
        lower.contains('anonymous sign-in') ||
        lower.contains('signup') && lower.contains('disabled') ||
        lower.contains('anonymous') && lower.contains('disabled') ||
        lower.contains('not allowed');
  }

  String _normalizeOtpMode(String mode) {
    final String normalized = mode.trim().toLowerCase();
    if (normalized == 'register' || normalized == 'signup') {
      return 'signup';
    }
    return 'recovery';
  }

  Future<Map<String, dynamic>> _invokeCustomOtpFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    try {
      final dynamic response = await Supabase.instance.client.functions.invoke(
        functionName,
        body: body,
      );
      final dynamic data = response.data;
      if (data is Map) {
        final Map<String, dynamic> payload = data.cast<String, dynamic>();
        if (payload['success'] == true) {
          return payload;
        }
        final String message =
            payload['message']?.toString() ?? 'Permintaan auth gagal';
        throw Exception(message);
      }
      throw Exception('Respons auth tidak valid');
    } catch (error) {
      final String raw = error.toString();
      throw Exception(raw.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _syncPrivyWalletSilently() async {
    if (!AppConfig.isPrivyConfigured || !adalahUserTerdaftar) {
      return;
    }
    await PrivyWalletService.instance.connectWithCurrentSessionSilently(
      ensureWallet: true,
    );
  }
}
