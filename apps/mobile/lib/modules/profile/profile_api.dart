import 'package:dio/dio.dart';

import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';

class ProfileUser {
  const ProfileUser({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    this.createdAt,
  });

  final int id;
  final String nama;
  final String? email;
  final String role;
  final String? createdAt;

  factory ProfileUser.fromJson(Map<String, dynamic> json) {
    return ProfileUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      nama: (json['nama'] ?? json['Nama'] ?? 'Pengguna').toString(),
      email: (json['email'] as String?)?.trim().isEmpty == true
          ? null
          : (json['email'] as String?),
      role: (json['role'] ?? json['Role'] ?? 'user').toString(),
      createdAt: json['created_at'] as String?,
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

  Future<Response<dynamic>> _putWithFallback(String path, {dynamic data}) async {
    try {
      return await _dio().put(path, data: data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && !path.startsWith('/api/')) {
        return _dio().put('/api$path', data: data);
      }
      rethrow;
    }
  }

  Future<ProfileUser> fetchMe() async {
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

  Future<ProfileLearningSummary> fetchLearningSummary() async {
    final kelasRs = await _getWithFallback('/api/kelas');
    final kelasData = kelasRs.data is Map ? (kelasRs.data as Map)['data'] : null;
    final kelasItems = kelasData is List ? kelasData : const [];
    if (kelasItems.isEmpty) {
      return const ProfileLearningSummary.empty();
    }

    final firstKelas = kelasItems.first;
    final kelasId = firstKelas is Map ? ((firstKelas['id'] as num?)?.toInt() ?? 0) : 0;
    final kelasJudul = firstKelas is Map ? (firstKelas['judul'] ?? 'Kelas').toString() : 'Kelas';

    final progressRs = await _getWithFallback('/api/kelas/$kelasId/progress');
    final progressData = progressRs.data is Map ? (progressRs.data as Map)['data'] : null;
    final progress = progressData is Map ? progressData : const {};

    final lastRs = await _getWithFallback('/api/kelas/last-learning');
    final lastData = lastRs.data is Map ? (lastRs.data as Map)['data'] : null;
    final last = lastData is Map ? lastData : const {};

    final completedMateri = (progress['completed_materi'] as num?)?.toInt() ?? 0;
    final totalMateri = (progress['total_materi'] as num?)?.toInt() ?? 0;
    final progressPercent = (progress['progress_materi_percent'] as num?)?.toInt() ?? 0;
    final isEligible = (progress['is_eligible_certificate'] as bool?) ?? false;
    final scorePercent = (progress['score_percent'] as num?)?.toInt() ?? 0;

    final lastTitle = (last['last_materi_judul'] as String?)?.trim();
    final nextIndex = (last['next_materi_index'] as num?)?.toInt() ?? (completedMateri + 1);

    return ProfileLearningSummary(
      kelasId: kelasId,
      kelasJudul: kelasJudul,
      completedMateri: completedMateri,
      totalMateri: totalMateri,
      progressMateriPercent: progressPercent,
      certificateEligible: isEligible,
      scorePercent: scorePercent,
      lastMateriJudul: (lastTitle == null || lastTitle.isEmpty) ? null : lastTitle,
      nextMateriIndex: nextIndex,
    );
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
  });

  const ProfileLearningSummary.empty()
      : kelasId = 0,
        kelasJudul = 'Kelas',
        completedMateri = 0,
        totalMateri = 0,
        progressMateriPercent = 0,
        certificateEligible = false,
        scorePercent = 0,
        lastMateriJudul = null,
        nextMateriIndex = 1;

  final int kelasId;
  final String kelasJudul;
  final int completedMateri;
  final int totalMateri;
  final int progressMateriPercent;
  final bool certificateEligible;
  final int scorePercent;
  final String? lastMateriJudul;
  final int nextMateriIndex;
}
