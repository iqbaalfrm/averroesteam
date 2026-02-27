import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';

class PustakaApi {
  PustakaApi({Dio? dio}) : _dio = dio ?? ApiDio.create();

  final Dio _dio;

  Future<List<PustakaKategori>> fetchKategori() async {
    final Response<dynamic> r = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/buku/kategori',
    );
    final List<dynamic> rows = _extractList(r.data);
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => PustakaKategori.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PustakaListResult> fetchBuku({
    int page = 1,
    int perPage = 10,
    String? kategoriSlug,
    String sort = 'terbaru',
  }) async {
    final Response<dynamic> r = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/buku',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'sort': sort,
        if (kategoriSlug != null && kategoriSlug.isNotEmpty)
          'kategori_slug': kategoriSlug,
      },
    );
    final Map<String, dynamic> data = _extractMap(r.data);
    final List<dynamic> rows = (data['items'] as List<dynamic>?) ?? <dynamic>[];
    return PustakaListResult(
      items: rows
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => PustakaBuku.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      page: ((data['pagination'] as Map?)?['page'] as num?)?.toInt() ?? page,
      perPage:
          ((data['pagination'] as Map?)?['per_page'] as num?)?.toInt() ?? perPage,
      total: ((data['pagination'] as Map?)?['total'] as num?)?.toInt() ?? 0,
      totalPages:
          ((data['pagination'] as Map?)?['total_pages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<PustakaBuku> fetchBukuDetail(int id) async {
    final Response<dynamic> r = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/buku/$id',
    );
    final Map<String, dynamic> data = _extractMap(r.data);
    return PustakaBuku.fromJson(data);
  }

  Future<PustakaAccessUrl> requestAccessUrl({
    required int bukuId,
    String action = 'read',
  }) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/buku/$bukuId/access',
      data: <String, dynamic>{'action': action},
    );
    final Map<String, dynamic> data = _extractMap(r.data);
    return PustakaAccessUrl(
      url: (data['url'] as String?)?.trim() ?? '',
      filename: (data['filename'] as String?)?.trim(),
      expiresIn: (data['expires_in'] as num?)?.toInt(),
    );
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'];
      if (data is List<dynamic>) return data;
    }
    return <dynamic>[];
  }

  Map<String, dynamic> _extractMap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{};
  }
}

class PustakaListResult {
  const PustakaListResult({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });

  final List<PustakaBuku> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
}

class PustakaKategori {
  const PustakaKategori({
    required this.id,
    required this.nama,
    required this.slug,
    required this.isActive,
  });

  final int id;
  final String nama;
  final String slug;
  final bool isActive;

  factory PustakaKategori.fromJson(Map<String, dynamic> json) => PustakaKategori(
        id: (json['id'] as num?)?.toInt() ?? 0,
        nama: (json['nama'] as String?)?.trim() ?? '-',
        slug: (json['slug'] as String?)?.trim() ?? '',
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

class PustakaBuku {
  const PustakaBuku({
    required this.id,
    required this.judul,
    required this.penulis,
    required this.deskripsi,
    required this.kategoriNama,
    required this.kategoriSlug,
    required this.akses,
    required this.formatFile,
    required this.ukuranFileBytes,
    required this.coverUrl,
    required this.driveFileId,
    required this.hasFile,
  });

  final int id;
  final String judul;
  final String penulis;
  final String deskripsi;
  final String kategoriNama;
  final String? kategoriSlug;
  final String akses;
  final String? formatFile;
  final int? ukuranFileBytes;
  final String? coverUrl;
  final String? driveFileId;
  final bool hasFile;

  factory PustakaBuku.fromJson(Map<String, dynamic> json) {
    final dynamic kategori = json['kategori'];
    final String kategoriNama = kategori is Map
        ? ((kategori['nama'] as String?)?.trim() ?? 'Dokumen')
        : 'Dokumen';
    final String? kategoriSlug =
        kategori is Map ? (kategori['slug'] as String?)?.trim() : null;
    return PustakaBuku(
      id: (json['id'] as num?)?.toInt() ?? 0,
      judul: (json['judul'] as String?)?.trim() ?? '-',
      penulis: (json['penulis'] as String?)?.trim() ?? '-',
      deskripsi: (json['deskripsi'] as String?)?.trim() ?? '',
      kategoriNama: kategoriNama,
      kategoriSlug: kategoriSlug,
      akses: (json['akses'] as String?)?.trim() ?? 'gratis',
      formatFile: (json['format_file'] as String?)?.trim(),
      ukuranFileBytes: (json['ukuran_file_bytes'] as num?)?.toInt(),
      coverUrl: (json['cover_url'] as String?)?.trim(),
      driveFileId: (json['drive_file_id'] as String?)?.trim(),
      hasFile: (json['has_file'] as bool?) ?? false,
    );
  }
}

class PustakaAccessUrl {
  const PustakaAccessUrl({
    required this.url,
    this.filename,
    this.expiresIn,
  });

  final String url;
  final String? filename;
  final int? expiresIn;
}
