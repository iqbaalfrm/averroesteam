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
}
