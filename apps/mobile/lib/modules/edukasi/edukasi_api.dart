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

  Future<KelasDetailEdukasi> fetchKelasDetail(int kelasId) async {
    final Response<dynamic> response = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/kelas/$kelasId',
    );
    final Map<String, dynamic> data = _extractMapData(response.data);
    return KelasDetailEdukasi.fromJson(data);
  }

  Future<KelasProgressEdukasi> fetchKelasProgress(int kelasId) async {
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

  Future<void> completeMateri(int materiId) async {
    await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/materi/complete',
      data: <String, dynamic>{'materi_id': materiId},
      options: _authOptions(),
    );
  }

  Future<QuizSubmitResult> submitQuiz({
    required int quizId,
    required String jawaban,
  }) async {
    final Response<dynamic> response = await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/quiz/submit',
      data: <String, dynamic>{'quiz_id': quizId, 'jawaban': jawaban},
      options: _authOptions(),
    );
    return QuizSubmitResult.fromJson(_extractMapData(response.data));
  }

  Future<SertifikatResult> generateSertifikat(int kelasId) async {
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

class KelasEdukasi {
  KelasEdukasi({
    required this.id,
    required this.judul,
    required this.deskripsi,
  });

  final int id;
  final String judul;
  final String deskripsi;

  factory KelasEdukasi.fromJson(Map<String, dynamic> json) {
    return KelasEdukasi(
      id: (json['id'] as num?)?.toInt() ?? 0,
      judul: (json['judul'] as String?)?.trim() ?? '-',
      deskripsi: (json['deskripsi'] as String?)?.trim() ?? '-',
    );
  }
}

class KelasDetailEdukasi {
  KelasDetailEdukasi({
    required this.id,
    required this.judul,
    required this.deskripsi,
    required this.modul,
    required this.kuis,
  });

  final int id;
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
      id: (json['id'] as num?)?.toInt() ?? 0,
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

  final int id;
  final int kelasId;
  final String judul;
  final String deskripsi;
  final int urutan;
  final List<MateriEdukasi> materi;

  factory ModulEdukasi.fromJson(Map<String, dynamic> json) {
    final List<dynamic> materiRaw =
        (json['materi'] as List<dynamic>?) ?? <dynamic>[];
    return ModulEdukasi(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kelasId: (json['kelas_id'] as num?)?.toInt() ?? 0,
      judul: (json['judul'] as String?)?.trim() ?? '-',
      deskripsi: (json['deskripsi'] as String?)?.trim() ?? '-',
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
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

  final int id;
  final int modulId;
  final String judul;
  final String konten;
  final int urutan;

  factory MateriEdukasi.fromJson(Map<String, dynamic> json) {
    return MateriEdukasi(
      id: (json['id'] as num?)?.toInt() ?? 0,
      modulId: (json['modul_id'] as num?)?.toInt() ?? 0,
      judul: (json['judul'] as String?)?.trim() ?? '-',
      konten: (json['konten'] as String?)?.trim() ?? '-',
      urutan: (json['urutan'] as num?)?.toInt() ?? 0,
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

  final int id;
  final int kelasId;
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      kelasId: (json['kelas_id'] as num?)?.toInt() ?? 0,
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
  final List<int> completedMateriIds;
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
      totalMateri: (json['total_materi'] as num?)?.toInt() ?? 0,
      completedMateri: (json['completed_materi'] as num?)?.toInt() ?? 0,
      completedMateriIds:
          ((json['completed_materi_ids'] as List<dynamic>?) ?? <dynamic>[])
              .whereType<num>()
              .map((num n) => n.toInt())
              .toList(),
      progressMateriPercent:
          (json['progress_materi_percent'] as num?)?.toInt() ?? 0,
      totalQuiz: (json['total_quiz'] as num?)?.toInt() ?? 0,
      answeredQuiz: (json['answered_quiz'] as num?)?.toInt() ?? 0,
      correctQuiz: (json['correct_quiz'] as num?)?.toInt() ?? 0,
      scorePercent: (json['score_percent'] as num?)?.toInt() ?? 0,
      isMateriComplete: (json['is_materi_complete'] as bool?) ?? false,
      isQuizComplete: (json['is_quiz_complete'] as bool?) ?? false,
      isEligibleCertificate:
          (json['is_eligible_certificate'] as bool?) ?? false,
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

  final int quizId;
  final String jawabanPengguna;
  final String jawabanBenar;
  final bool benar;

  factory QuizSubmitResult.fromJson(Map<String, dynamic> json) {
    return QuizSubmitResult(
      quizId: (json['quiz_id'] as num?)?.toInt() ?? 0,
      jawabanPengguna: (json['jawaban_pengguna'] as String?) ?? '',
      jawabanBenar: (json['jawaban_benar'] as String?) ?? '',
      benar: (json['benar'] as bool?) ?? false,
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

  final int kelasId;
  final String kelasJudul;
  final int completedMateri;
  final int totalMateri;
  final int progressMateriPercent;
  final int nextMateriIndex;
  final int? lastMateriId;
  final String? lastMateriJudul;

  factory LastLearningEdukasi.fromJson(Map<String, dynamic> json) {
    return LastLearningEdukasi(
      kelasId: (json['kelas_id'] as num?)?.toInt() ?? 0,
      kelasJudul: (json['kelas_judul'] as String?)?.trim() ?? 'Kelas',
      completedMateri: (json['completed_materi'] as num?)?.toInt() ?? 0,
      totalMateri: (json['total_materi'] as num?)?.toInt() ?? 0,
      progressMateriPercent:
          (json['progress_materi_percent'] as num?)?.toInt() ?? 0,
      nextMateriIndex: (json['next_materi_index'] as num?)?.toInt() ?? 1,
      lastMateriId: (json['last_materi_id'] as num?)?.toInt(),
      lastMateriJudul: (json['last_materi_judul'] as String?)?.trim(),
    );
  }
}

class SertifikatResult {
  SertifikatResult({
    required this.kelas,
    required this.namaSertifikat,
    required this.nomor,
    required this.scorePercent,
  });

  final String kelas;
  final String namaSertifikat;
  final String nomor;
  final int scorePercent;

  factory SertifikatResult.fromJson(Map<String, dynamic> json) {
    return SertifikatResult(
      kelas: (json['kelas'] as String?) ?? '-',
      namaSertifikat: (json['nama_sertifikat'] as String?) ?? '-',
      nomor: (json['nomor'] as String?) ?? '-',
      scorePercent: (json['score_percent'] as num?)?.toInt() ?? 0,
    );
  }
}
