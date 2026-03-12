import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';

class EdukasiApi {
  EdukasiApi({Dio? dio}) : _dio = dio ?? ApiDio.create();

  final Dio _dio;

  Options _authOptions() {
    final String? token = AuthService.instance.token;
    if (token == null || token.isEmpty) {
      return Options();
    }
    return Options(
        headers: <String, dynamic>{'Authorization': 'Bearer $token'});
  }

  Future<List<KelasEdukasi>> fetchKelas() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/kelas',
    );

    final List<dynamic> rows = _extractList(response.data);
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) => KelasEdukasi.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList();
  }

  Future<KelasDetailEdukasi> fetchKelasDetail(String kelasId) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/kelas/$kelasId',
    );
    final Map<String, dynamic> data = _extractMapData(response.data);
    return KelasDetailEdukasi.fromJson(data);
  }

  Future<KelasProgressEdukasi> fetchKelasProgress(String kelasId) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/kelas/$kelasId/progress',
      options: _authOptions(),
    );
    final Map<String, dynamic> data = _extractMapData(response.data);
    return KelasProgressEdukasi.fromJson(data);
  }

  Future<LastLearningEdukasi> fetchLastLearning() async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/kelas/last-learning',
      options: _authOptions(),
    );
    final Map<String, dynamic> data = _extractMapData(response.data);
    return LastLearningEdukasi.fromJson(data);
  }

  Future<void> completeMateri(String materiId) async {
    await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/materi/complete',
      data: <String, dynamic>{'materi_id': materiId},
      options: _authOptions(),
    );
  }

  Future<QuizSubmitResult> submitQuiz({
    required String quizId,
    required String jawaban,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/quiz/submit',
      data: <String, dynamic>{'quiz_id': quizId, 'jawaban': jawaban},
      options: _authOptions(),
    );
    return QuizSubmitResult.fromJson(_extractMapData(response.data));
  }

  Future<SertifikatResult> generateSertifikat(String kelasId) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/sertifikat/generate',
      data: <String, dynamic>{'kelas_id': kelasId},
      options: _authOptions(),
    );
    return SertifikatResult.fromJson(_extractMapData(response.data));
  }

  List<dynamic> _extractList(dynamic rawResponse) {
    if (rawResponse is Map<String, dynamic>) {
      final dynamic data = rawResponse['data'];
      if (data is List<dynamic>) {
        return data;
      }
    }
    return <dynamic>[];
  }

  Map<String, dynamic> _extractMapData(dynamic rawResponse) {
    if (rawResponse is Map<String, dynamic>) {
      final dynamic data = rawResponse['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    }
    return <String, dynamic>{};
  }
}

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

class KelasEdukasi {
  KelasEdukasi({
    required this.id,
    required this.judul,
    required this.deskripsi,
    this.gambarUrl,
  });

  final String id;
  final String judul;
  final String deskripsi;
  final String? gambarUrl;

  factory KelasEdukasi.fromJson(Map<String, dynamic> json) {
    return KelasEdukasi(
      id: _asString(json['id']),
      judul: (json['judul'] as String?)?.trim() ?? '-',
      deskripsi: (json['deskripsi'] as String?)?.trim() ?? '-',
      gambarUrl: _asNullableString(
        json['gambar_url'] ??
            json['thumbnail'] ??
            json['image_url'] ??
            json['cover_url'] ??
            json['cover'] ??
            json['image'],
      ),
    );
  }
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

class KelasDetailEdukasi {
  KelasDetailEdukasi({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.modul,
    required this.kuis,
  });

  final String id;
  final String judul;
  final String deskripsi;
  final List<ModulEdukasi> modul;
  final List<KuisEdukasi> kuis;

  factory KelasDetailEdukasi.fromJson(Map<String, dynamic> json) {
    final List<dynamic> modulRaw =
        (json['modul'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> kuisRaw =
        (json['quiz'] as List<dynamic>?) ?? <dynamic>[];
    return KelasDetailEdukasi(
      id: _asString(json['id']),
      judul: (json['judul'] as String?)?.trim() ?? '-',
      deskripsi: (json['deskripsi'] as String?)?.trim() ?? '-',
      modul: modulRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) =>
              ModulEdukasi.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      kuis: kuisRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) =>
              KuisEdukasi.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }
}

class ModulEdukasi {
  ModulEdukasi({
    required this.id,
    required this.kelasId,
    required this.judul,
    required this.deskripsi,
    required this.urutan,
    required this.materi,
  });

  final String id;
  final String kelasId;
  final String judul;
  final String deskripsi;
  final int urutan;
  final List<MateriEdukasi> materi;

  factory ModulEdukasi.fromJson(Map<String, dynamic> json) {
    final List<dynamic> materiRaw =
        (json['materi'] as List<dynamic>?) ?? <dynamic>[];
    return ModulEdukasi(
      id: _asString(json['id']),
      kelasId: _asString(json['kelas_id']),
      judul: (json['judul'] as String?)?.trim() ?? '-',
      deskripsi: (json['deskripsi'] as String?)?.trim() ?? '-',
      urutan: _asInt(json['urutan']),
      materi: materiRaw
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) =>
              MateriEdukasi.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }
}

class MateriEdukasi {
  MateriEdukasi({
    required this.id,
    required this.modulId,
    required this.judul,
    required this.konten,
    required this.urutan,
  });

  final String id;
  final String modulId;
  final String judul;
  final String konten;
  final int urutan;

  factory MateriEdukasi.fromJson(Map<String, dynamic> json) {
    return MateriEdukasi(
      id: _asString(json['id']),
      modulId: _asString(json['modul_id']),
      judul: (json['judul'] as String?)?.trim() ?? '-',
      konten: (json['konten'] as String?)?.trim() ?? '-',
      urutan: _asInt(json['urutan']),
    );
  }
}

class KuisEdukasi {
  KuisEdukasi({
    required this.id,
    required this.kelasId,
    required this.pertanyaan,
    required this.pilihan,
  });

  final String id;
  final String kelasId;
  final String pertanyaan;
  final Map<String, String> pilihan;

  factory KuisEdukasi.fromJson(Map<String, dynamic> json) {
    final Map<String, String> pilihanMap = <String, String>{};
    final dynamic pilihanRaw = json['pilihan'];
    if (pilihanRaw is Map) {
      for (final MapEntry<dynamic, dynamic> entry in pilihanRaw.entries) {
        pilihanMap[entry.key.toString()] = (entry.value ?? '').toString();
      }
    }
    return KuisEdukasi(
      id: _asString(json['id']),
      kelasId: _asString(json['kelas_id']),
      pertanyaan: (json['pertanyaan'] as String?)?.trim() ?? '-',
      pilihan: pilihanMap,
    );
  }
}

class KelasProgressEdukasi {
  KelasProgressEdukasi({
    required this.totalMateri,
    required this.completedMateri,
    required this.completedMateriIds,
    required this.progressMateriPercent,
    required this.totalQuiz,
    required this.answeredQuiz,
    required this.correctQuiz,
    required this.scorePercent,
    required this.isMateriComplete,
    required this.isQuizComplete,
    required this.isEligibleCertificate,
  });

  final int totalMateri;
  final int completedMateri;
  final List<String> completedMateriIds;
  final int progressMateriPercent;
  final int totalQuiz;
  final int answeredQuiz;
  final int correctQuiz;
  final int scorePercent;
  final bool isMateriComplete;
  final bool isQuizComplete;
  final bool isEligibleCertificate;

  factory KelasProgressEdukasi.fromJson(Map<String, dynamic> json) {
    return KelasProgressEdukasi(
      totalMateri: _asInt(json['total_materi']),
      completedMateri: _asInt(json['completed_materi']),
      completedMateriIds:
          ((json['completed_materi_ids'] as List<dynamic>?) ?? <dynamic>[])
              .map((dynamic raw) => _asString(raw))
              .where((String id) => id.isNotEmpty)
              .toList(),
      progressMateriPercent:
          _asInt(json['progress_materi_percent']),
      totalQuiz: _asInt(json['total_quiz']),
      answeredQuiz: _asInt(json['answered_quiz']),
      correctQuiz: _asInt(json['correct_quiz']),
      scorePercent: _asInt(json['score_percent']),
      isMateriComplete: _asBool(json['is_materi_complete']),
      isQuizComplete: _asBool(json['is_quiz_complete']),
      isEligibleCertificate:
          _asBool(json['is_eligible_certificate']),
    );
  }
}

class QuizSubmitResult {
  QuizSubmitResult({
    required this.quizId,
    required this.jawabanPengguna,
    required this.jawabanBenar,
    required this.benar,
  });

  final String quizId;
  final String jawabanPengguna;
  final String jawabanBenar;
  final bool benar;

  factory QuizSubmitResult.fromJson(Map<String, dynamic> json) {
    return QuizSubmitResult(
      quizId: _asString(json['quiz_id']),
      jawabanPengguna: (json['jawaban_pengguna'] as String?) ?? '',
      jawabanBenar: (json['jawaban_benar'] as String?) ?? '',
      benar: _asBool(json['benar']),
    );
  }
}

class LastLearningEdukasi {
  LastLearningEdukasi({
    required this.kelasId,
    required this.kelasJudul,
    required this.completedMateri,
    required this.totalMateri,
    required this.progressMateriPercent,
    required this.nextMateriIndex,
    this.lastMateriId,
    this.lastMateriJudul,
  });

  final String kelasId;
  final String kelasJudul;
  final int completedMateri;
  final int totalMateri;
  final int progressMateriPercent;
  final int nextMateriIndex;
  final String? lastMateriId;
  final String? lastMateriJudul;

  factory LastLearningEdukasi.fromJson(Map<String, dynamic> json) {
    return LastLearningEdukasi(
      kelasId: _asString(json['kelas_id']),
      kelasJudul: (json['kelas_judul'] as String?)?.trim() ?? 'Kelas',
      completedMateri: _asInt(json['completed_materi']),
      totalMateri: _asInt(json['total_materi']),
      progressMateriPercent:
          _asInt(json['progress_materi_percent']),
      nextMateriIndex: _asInt(json['next_materi_index'], fallback: 1),
      lastMateriId: _asString(json['last_materi_id'], fallback: ''),
      lastMateriJudul: (json['last_materi_judul'] as String?)?.trim(),
    );
  }
}

class SertifikatResult {
  SertifikatResult({
    required this.kelasId,
    required this.kelas,
    required this.namaSertifikat,
    required this.nomor,
    required this.scorePercent,
    this.generatedAt,
    this.downloadUrl,
  });

  final String kelasId;
  final String kelas;
  final String namaSertifikat;
  final String nomor;
  final int scorePercent;
  final String? generatedAt;
  final String? downloadUrl;

  factory SertifikatResult.fromJson(Map<String, dynamic> json) {
    return SertifikatResult(
      kelasId: _asString(json['kelas_id']),
      kelas: (json['kelas'] as String?) ?? '-',
      namaSertifikat: (json['nama_sertifikat'] as String?) ?? '-',
      nomor: (json['nomor'] as String?) ?? '-',
      scorePercent: _asInt(json['score_percent']),
      generatedAt: _asNullableString(json['generated_at']),
      downloadUrl: _asNullableString(json['download_url']),
    );
  }
}
