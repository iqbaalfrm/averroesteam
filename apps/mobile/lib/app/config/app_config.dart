import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  /// Base URL API backend.
  /// Di .env, set API_BASE_URL ke URL Zeabur production.
  /// Default (emulator Android): http://10.0.2.2:8080
  static String get apiBaseUrl {
    final String raw = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8080';
    return raw.trim().replaceAll(RegExp(r'/$'), '');
  }

  /// Base URL khusus endpoint auth backend saat transisi Supabase.
  /// Jika kosong, akan fallback ke API_BASE_URL.
  static String get authApiBaseUrl {
    final String raw = dotenv.env['AUTH_API_BASE_URL']?.trim() ?? '';
    if (raw.isNotEmpty) {
      return raw.replaceAll(RegExp(r'/$'), '');
    }
    return apiBaseUrl;
  }

  static String get groqApiKey {
    final String fromEnv = dotenv.env['GROQ_API_KEY']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return const String.fromEnvironment('GROQ_API_KEY').trim();
  }

  static String get groqModel =>
      dotenv.env['GROQ_MODEL'] ?? 'llama-3.1-8b-instant';

  static bool get isGroqConfigured => groqApiKey.isNotEmpty;

  /// OAuth web client ID untuk verifikasi id_token di backend.
  /// Isi lewat .env dengan GOOGLE_WEB_CLIENT_ID.
  static String? get googleWebClientId {
    final String fromEnv = dotenv.env['GOOGLE_WEB_CLIENT_ID']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static bool get isGoogleLoginConfigured =>
      (googleWebClientId?.trim().isNotEmpty ?? false);

  static String? get googleIosClientId {
    final String fromEnv = dotenv.env['GOOGLE_IOS_CLIENT_ID']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static String? get supabaseUrl {
    final String fromEnv = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_URL').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static String? get supabaseAnonKey {
    final String fromEnv = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_ANON_KEY').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static bool get isSupabaseAuthEnabled =>
      (supabaseUrl?.isNotEmpty ?? false) &&
      (supabaseAnonKey?.isNotEmpty ?? false);

  static bool get isSupabaseNativeEnabled {
    final String fromEnv =
        (dotenv.env['SUPABASE_NATIVE_ENABLED'] ?? '').trim().toLowerCase();
    if (fromEnv.isNotEmpty) {
      return fromEnv == 'true' ||
          fromEnv == '1' ||
          fromEnv == 'yes' ||
          fromEnv == 'on';
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_NATIVE_ENABLED')
            .trim()
            .toLowerCase();
    if (fromConst.isNotEmpty) {
      return fromConst == 'true' ||
          fromConst == '1' ||
          fromConst == 'yes' ||
          fromConst == 'on';
    }
    return false;
  }

  static bool get isSupabaseCustomOtpEnabled {
    final String fromEnv =
        (dotenv.env['SUPABASE_CUSTOM_OTP_ENABLED'] ?? '').trim().toLowerCase();
    if (fromEnv.isNotEmpty) {
      return fromEnv == 'true' ||
          fromEnv == '1' ||
          fromEnv == 'yes' ||
          fromEnv == 'on';
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_CUSTOM_OTP_ENABLED')
            .trim()
            .toLowerCase();
    if (fromConst.isNotEmpty) {
      return fromConst == 'true' ||
          fromConst == '1' ||
          fromConst == 'yes' ||
          fromConst == 'on';
    }
    return false;
  }

  static int get supabaseCustomOtpLength {
    final String fromEnv =
        (dotenv.env['SUPABASE_CUSTOM_OTP_LENGTH'] ?? '').trim();
    final int? envValue = int.tryParse(fromEnv);
    if (envValue != null && envValue > 0) {
      return envValue;
    }
    final int constValue = int.fromEnvironment(
      'SUPABASE_CUSTOM_OTP_LENGTH',
      defaultValue: 0,
    );
    if (constValue > 0) {
      return constValue;
    }
    return 4;
  }

  static int get otpLength =>
      isSupabaseCustomOtpEnabled ? supabaseCustomOtpLength : 6;

  static String? get supabaseRedirectUrl {
    final String fromEnv = dotenv.env['SUPABASE_REDIRECT_URL']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_REDIRECT_URL').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static String? get privyAppId {
    final String fromEnv = dotenv.env['PRIVY_APP_ID']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('PRIVY_APP_ID').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static String? get privyClientId {
    final String fromEnv = dotenv.env['PRIVY_CLIENT_ID']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('PRIVY_CLIENT_ID').trim();
    return fromConst.isNotEmpty ? fromConst : null;
  }

  static bool get isPrivyConfigured =>
      (privyAppId?.isNotEmpty ?? false) &&
      (privyClientId?.isNotEmpty ?? false);

  static String get supabasePustakaFilesBucket {
    final String fromEnv =
        dotenv.env['SUPABASE_PUSTAKA_FILES_BUCKET']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_PUSTAKA_FILES_BUCKET').trim();
    if (fromConst.isNotEmpty) {
      return fromConst;
    }
    return 'pustaka-files';
  }

  static String get supabasePustakaCoversBucket {
    final String fromEnv =
        dotenv.env['SUPABASE_PUSTAKA_COVERS_BUCKET']?.trim() ?? '';
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    final String fromConst =
        const String.fromEnvironment('SUPABASE_PUSTAKA_COVERS_BUCKET').trim();
    if (fromConst.isNotEmpty) {
      return fromConst;
    }
    return 'pustaka-covers';
  }

  static int get supabaseStorageSignedUrlTtlSeconds {
    final String fromEnv =
        dotenv.env['SUPABASE_STORAGE_SIGNED_URL_TTL']?.trim() ?? '';
    final int? envValue = int.tryParse(fromEnv);
    if (envValue != null && envValue > 0) {
      return envValue;
    }
    final int constValue = int.fromEnvironment(
      'SUPABASE_STORAGE_SIGNED_URL_TTL',
      defaultValue: 0,
    );
    if (constValue > 0) {
      return constValue;
    }
    return 3600;
  }
}
