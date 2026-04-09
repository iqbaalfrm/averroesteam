import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseNativeService {
  const SupabaseNativeService._();

  static bool get isEnabled =>
      AppConfig.isSupabaseAuthEnabled && AppConfig.isSupabaseNativeEnabled;

  static SupabaseClient get client => Supabase.instance.client;

  static String requireAuthUserId() {
    final String? userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('Session Supabase tidak ditemukan');
    }
    return userId;
  }

  static Future<Map<String, dynamic>> ensureProfile() async {
    requireAuthUserId();
    final dynamic raw = await client.rpc('ensure_profile');
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    throw Exception('Profil Supabase tidak valid');
  }

  static Future<String> ensureProfileId() async {
    final Map<String, dynamic> profile = await ensureProfile();
    final String id = (profile['id'] ?? '').toString();
    if (id.isEmpty) {
      throw Exception('Profile id tidak ditemukan');
    }
    return id;
  }

  static Map<String, dynamic> toLegacyProfileShape(Map<String, dynamic> profile) {
    return <String, dynamic>{
      'id': (profile['id'] ?? '').toString(),
      'nama': (profile['full_name'] ?? profile['nama'] ?? 'Pengguna').toString(),
      'Nama': (profile['full_name'] ?? profile['nama'] ?? 'Pengguna').toString(),
      'email': profile['email']?.toString(),
      'role': (profile['role'] ?? 'user').toString(),
      'Role': (profile['role'] ?? 'user').toString(),
      'foto_url': profile['avatar_url']?.toString(),
      'supabase_user_id':
          (profile['auth_user_id'] ?? profile['id'] ?? '').toString(),
      'created_at': profile['created_at']?.toString(),
    };
  }
}
