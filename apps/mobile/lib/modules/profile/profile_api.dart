import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';
import '../../app/services/supabase_native_service.dart';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true' || v == '1' || v == 'yes') return true;
    if (v == 'false' || v == '0' || v == 'no') return false;
  }
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final s = value.toString().trim();
  return s.isEmpty ? fallback : s;
}

class ProfileUser {
  const ProfileUser({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String nama;
  final String? email;
  final String role;
  final String? createdAt;

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      id: _asString(json['id']),
      nama: (json['nama'] ?? json['Nama'] ?? 'Pengguna').toString(),
      email: (json['email'] as String?)?.trim().isEmpty == true
          ? null
          : (json['email'] as String?),
      role: (json['role'] ?? json['Role'] ?? 'user').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ProfileApi {
  Dio _dio() => ApiDio.create();

  Future<Response<dynamic>> _getWithFallback(String path) async {
    try {
      return await _dio().get(path);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && !path.startsWith('/api/')) {
        return _dio().get('/api$path');
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _putWithFallback(String path,
      {dynamic data}) async {
    try {
      return await _dio().put(path, data: data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && !path.startsWith('/api/')) {
        return _dio().put('/api$path', data: data);
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _deleteWithFallback(String path) async {
    try {
      return await _dio().delete(path);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && !path.startsWith('/api/')) {
        return _dio().delete('/api$path');
      }
      rethrow;
    }
  }

  Future<ProfileUser> fetchMe() async {
    if (SupabaseNativeService.isEnabled) {
      final Map<String, dynamic> user =
          await SupabaseNativeService.ensureProfile();
      final Map<String, dynamic> shaped =
          SupabaseNativeService.toLegacyProfileShape(user);
      await AuthService.instance.simpanUser(shaped);
      return ProfileUser.fromJson(shaped);
    }

    final rs = await _getWithFallback('/auth/me');
    final data = rs.data;
    final payload = data is Map ? data['data'] : null;
    final user = payload is Map ? payload['user'] : null;
    if (user is! Map) {
      throw Exception('Format profil tidak valid');
    }
    final parsed = ProfileUser.fromJson(user.cast<String, dynamic>());
    await AuthService.instance.simpanUser(user.cast<String, dynamic>());
    return parsed;
  }

  Future<ProfileUser> updateMe({
    required String nama,
    required String email,
  }) async {
    if (SupabaseNativeService.isEnabled) {
      final String authUserId = SupabaseNativeService.requireAuthUserId();
      final List<dynamic> rows = await Supabase.instance.client
          .from('profiles')
          .update(<String, dynamic>{
            'full_name': nama.trim(),
            'email': email.trim(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('auth_user_id', authUserId)
          .select();
      if (rows.isEmpty || rows.first is! Map) {
        throw Exception('Gagal memperbarui profil');
      }
      final Map<String, dynamic> shaped =
          SupabaseNativeService.toLegacyProfileShape(
        Map<String, dynamic>.from(rows.first as Map),
      );
      await AuthService.instance.simpanUser(shaped);
      return ProfileUser.fromJson(shaped);
    }

    final rs = await _putWithFallback(
      '/auth/me',
      data: <String, dynamic>{
        'nama': nama.trim(),
        'email': email.trim(),
      },
    );
    final data = rs.data;
    final payload = data is Map ? data['data'] : null;
    final user = payload is Map ? payload['user'] : null;
    if (user is! Map) {
      throw Exception('Format profil tidak valid');
    }
    final parsed = ProfileUser.fromJson(user.cast<String, dynamic>());
    await AuthService.instance.simpanUser(user.cast<String, dynamic>());
    return parsed;
  }

  Future<void> deleteAccount() async {
    if (SupabaseNativeService.isEnabled) {
      final dynamic response = await Supabase.instance.client.functions.invoke(
        'delete-account',
        body: const <String, dynamic>{},
      );
      final dynamic data = response.data;
      if (data is Map) {
        final Map<String, dynamic> payload = Map<String, dynamic>.from(data);
        if (payload['success'] == true) {
          return;
        }
        throw Exception(
          _asString(payload['message'], fallback: 'Gagal menghapus akun'),
        );
      }
      throw Exception('Respons hapus akun tidak valid');
    }

    await _deleteWithFallback('/auth/me');
  }

  Future<ProfileLearningSummary> fetchLearningSummary() async {
    if (SupabaseNativeService.isEnabled) {
      try {
        final Map<String, dynamic> lastMap = _extractSupabaseMap(
          await Supabase.instance.client.rpc('get_last_learning'),
        );
        final String kelasId = _asString(lastMap['kelas_id']);
        final String profileId = await SupabaseNativeService.ensureProfileId();

        Map<String, dynamic> progressMap = const <String, dynamic>{};
        if (kelasId.isNotEmpty) {
          progressMap = _extractSupabaseMap(
            await Supabase.instance.client.rpc(
              'get_class_progress',
              params: <String, dynamic>{'p_class_id': kelasId},
            ),
          );
        }

        final List<dynamic> certRows = await Supabase.instance.client
            .from('user_certificates')
            .select('id,certificate_name')
            .eq('user_id', profileId)
            .order('generated_at', ascending: false);

        String? latestCert;
        if (certRows.isNotEmpty && certRows.first is Map) {
          latestCert = (certRows.first as Map)['certificate_name']?.toString();
        }

        return ProfileLearningSummary(
          kelasId: kelasId,
          kelasJudul: _asString(lastMap['kelas_judul'], fallback: 'Kelas'),
          completedMateri: _asInt(progressMap['completed_materi']),
          totalMateri: _asInt(progressMap['total_materi']),
          progressMateriPercent: _asInt(progressMap['progress_materi_percent']),
          certificateEligible: _asBool(progressMap['is_eligible_certificate']),
          scorePercent: _asInt(progressMap['score_percent']),
          lastMateriJudul:
              _asString(lastMap['last_materi_judul'], fallback: ''),
          nextMateriIndex: _asInt(lastMap['next_materi_index'], fallback: 1),
          totalSertifikat: certRows.length,
          lastSertifikatJudul: latestCert,
        );
      } catch (_) {
        return const ProfileLearningSummary.empty();
      }
    }

    try {
      final kelasRs = await _getWithFallback('/api/kelas');
      final kelasData =
          kelasRs.data is Map ? (kelasRs.data as Map)['data'] : null;
      final kelasItems = kelasData is List ? kelasData : const [];
      if (kelasItems.isEmpty) {
        return const ProfileLearningSummary.empty();
      }

      final firstKelas = kelasItems.first;
      final kelasId = firstKelas is Map ? _asString(firstKelas['id']) : '';
      final kelasJudul = firstKelas is Map
          ? (firstKelas['judul'] ?? 'Kelas').toString()
          : 'Kelas';

      Map progressMap = const {};
      try {
        final progressRs =
            await _getWithFallback('/api/kelas/$kelasId/progress');
        final progressData =
            progressRs.data is Map ? (progressRs.data as Map)['data'] : null;
        progressMap = progressData is Map ? progressData : const {};
      } catch (_) {}

      Map lastMap = const {};
      try {
        final lastRs = await _getWithFallback('/api/kelas/last-learning');
        final lastData =
            lastRs.data is Map ? (lastRs.data as Map)['data'] : null;
        lastMap = lastData is Map ? lastData : const {};
      } catch (_) {}

      final completedMateri = _asInt(progressMap['completed_materi']);
      final totalMateri = _asInt(progressMap['total_materi']);
      final progressPercent = _asInt(progressMap['progress_materi_percent']);
      final isEligible = _asBool(progressMap['is_eligible_certificate']);
      final scorePercent = _asInt(progressMap['score_percent']);

      final lastTitleRaw = lastMap['last_materi_judul'];
      final lastTitle = lastTitleRaw is String ? lastTitleRaw.trim() : null;
      final nextIndex =
          _asInt(lastMap['next_materi_index'], fallback: completedMateri + 1);

      int certCount = 0;
      String? latestCert;
      try {
        final certRs = await _getWithFallback('/api/sertifikat/saya');
        final certData =
            certRs.data is Map ? (certRs.data as Map)['data'] : null;
        final certItems = certData is List ? certData : const [];
        certCount = certItems.length;
        if (certItems.isNotEmpty && certItems.first is Map) {
          final first = certItems.first as Map;
          latestCert =
              (first['nama_sertifikat'] ?? first['kelas'] ?? '').toString();
        }
      } catch (_) {}

      return ProfileLearningSummary(
        kelasId: kelasId,
        kelasJudul: kelasJudul,
        completedMateri: completedMateri,
        totalMateri: totalMateri,
        progressMateriPercent: progressPercent,
        certificateEligible: isEligible,
        scorePercent: scorePercent,
        lastMateriJudul:
            (lastTitle == null || lastTitle.isEmpty) ? null : lastTitle,
        nextMateriIndex: nextIndex,
        totalSertifikat: certCount,
        lastSertifikatJudul: latestCert,
      );
    } catch (_) {
      return const ProfileLearningSummary.empty();
    }
  }

  Map<String, dynamic> _extractSupabaseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }
}

class ProfileLearningSummary {
  const ProfileLearningSummary({
    required this.kelasId,
    required this.kelasJudul,
    required this.completedMateri,
    required this.totalMateri,
    required this.progressMateriPercent,
    required this.certificateEligible,
    required this.scorePercent,
    required this.lastMateriJudul,
    required this.nextMateriIndex,
    required this.totalSertifikat,
    required this.lastSertifikatJudul,
  });

  const ProfileLearningSummary.empty()
      : kelasId = '',
        kelasJudul = 'Kelas',
        completedMateri = 0,
        totalMateri = 0,
        progressMateriPercent = 0,
        certificateEligible = false,
        scorePercent = 0,
        lastMateriJudul = null,
        nextMateriIndex = 1,
        totalSertifikat = 0,
        lastSertifikatJudul = null;

  final String kelasId;
  final String kelasJudul;
  final int completedMateri;
  final int totalMateri;
  final int progressMateriPercent;
  final bool certificateEligible;
  final int scorePercent;
  final String? lastMateriJudul;
  final int nextMateriIndex;
  final int totalSertifikat;
  final String? lastSertifikatJudul;
}
