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
}
