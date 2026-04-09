import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';

class PustakaApi {
  PustakaApi({Dio? dio}) : _dio = dio ?? ApiDio.create();

  final Dio _dio;

  Future<List<PustakaKategori>> fetchKategori() async {
    if (AppConfig.isSupabaseNativeEnabled) {
      final List<dynamic> rows = await Supabase.instance.client
          .from('book_categories')
          .select('id,name,slug,is_active,sort_order')
          .eq('is_active', true)
          .order('sort_order')
          .order('name');
      return rows
          .whereType<Map>()
          .map((e) => PustakaKategori.fromSupabase(Map<String, dynamic>.from(e)))
          .toList();
    }

    final Response<dynamic> r = await _dio.get<dynamic>('/api/buku/kategori');
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
    if (AppConfig.isSupabaseNativeEnabled) {
      return _fetchBukuFromSupabase(
        page: page,
        perPage: perPage,
        kategoriSlug: kategoriSlug,
        sort: sort,
      );
    }

    final Response<dynamic> r = await _dio.get<dynamic>(
      '/api/buku',
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

  Future<PustakaBuku> fetchBukuDetail(String id) async {
    if (AppConfig.isSupabaseNativeEnabled) {
      final Map<String, Map<String, String>> categories =
          await _fetchCategoryLookup();
      final dynamic row = await Supabase.instance.client
          .from('books')
          .select(_bookSelect)
          .eq('id', id)
          .maybeSingle();
      if (row is! Map) {
        throw Exception('Buku tidak ditemukan');
      }
      final Map<String, dynamic> shaped = Map<String, dynamic>.from(row);
      if (!_isPublishedBook(shaped)) {
        throw Exception('Buku tidak ditemukan');
      }
      return _hydrateSupabaseBookUrls(
        PustakaBuku.fromSupabase(
          shaped,
          categories: categories,
        ),
      );
    }

    final Response<dynamic> r = await _dio.get<dynamic>('/api/buku/$id');
    final Map<String, dynamic> data = _extractMap(r.data);
    return PustakaBuku.fromJson(data);
  }

  Future<PustakaAccessUrl> requestAccessUrl({
    required String bukuId,
    String action = 'read',
  }) async {
    if (AppConfig.isSupabaseNativeEnabled) {
      final PustakaBuku buku = await fetchBukuDetail(bukuId);
      final String normalizedAction =
          action.trim().toLowerCase() == 'download' ? 'download' : 'read';
      final String? url = await _resolveSupabaseAccessUrl(
        buku: buku,
        action: normalizedAction,
      );
      if (url == null || url.isEmpty) {
        throw Exception('URL buku tidak tersedia');
      }
      return PustakaAccessUrl(
        url: url,
        filename: buku.fileName ?? buku.judul,
        expiresIn: 600,
      );
    }

    final Response<dynamic> r = await _dio.post<dynamic>(
      '/api/buku/$bukuId/access',
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

  Future<PustakaListResult> _fetchBukuFromSupabase({
    required int page,
    required int perPage,
    required String? kategoriSlug,
    required String sort,
  }) async {
    final SupabaseClient client = Supabase.instance.client;
    final Map<String, Map<String, String>> categories =
        await _fetchCategoryLookup();
    String? categoryId;
    if (kategoriSlug != null && kategoriSlug.isNotEmpty) {
      final MapEntry<String, Map<String, String>>? matchedCategory =
          categories.entries.where((entry) {
        return entry.value['slug'] == kategoriSlug;
      }).cast<MapEntry<String, Map<String, String>>?>().firstOrNull;
      if (matchedCategory == null) {
        return PustakaListResult(
          items: const <PustakaBuku>[],
          page: page,
          perPage: perPage,
          total: 0,
          totalPages: 1,
        );
      }
      categoryId = matchedCategory.key;
    }

    dynamic query = client.from('books').select(_bookSelect);

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    if (sort == 'terlama') {
      query = query.order('published_at', ascending: true, nullsFirst: false);
    } else {
      query = query.order('published_at', ascending: false, nullsFirst: false);
    }

    final List<dynamic> rows = await query;
    final List<PustakaBuku> allItems = await Future.wait<PustakaBuku>(
      rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where(_isPublishedBook)
          .map(
            (e) => _hydrateSupabaseBookUrls(
              PustakaBuku.fromSupabase(e, categories: categories),
            ),
          ),
    );
    final int total = allItems.length;
    final int safePage = total == 0 ? 1 : page.clamp(1, (total / perPage).ceil());
    final int from = (safePage - 1) * perPage;
    final List<PustakaBuku> pagedItems = allItems.skip(from).take(perPage).toList();
    return PustakaListResult(
      items: pagedItems,
      page: safePage,
      perPage: perPage,
      total: total,
      totalPages: total == 0 ? 1 : (total / perPage).ceil(),
    );
  }

  Future<Map<String, Map<String, String>>> _fetchCategoryLookup() async {
    final List<dynamic> rows = await Supabase.instance.client
        .from('book_categories')
        .select('id,name,slug,is_active')
        .eq('is_active', true)
        .order('sort_order')
        .order('name');

    final Map<String, Map<String, String>> result =
        <String, Map<String, String>>{};
    for (final dynamic row in rows) {
      if (row is! Map) {
        continue;
      }
      final String id = (row['id'] ?? '').toString();
      if (id.isEmpty) {
        continue;
      }
      result[id] = <String, String>{
        'name': (row['name'] as String?)?.trim() ?? 'Dokumen',
        'slug': (row['slug'] as String?)?.trim() ?? '',
      };
    }
    return result;
  }

  bool _isPublishedBook(Map<String, dynamic> row) {
    final String status = (row['status'] as String?)?.trim().toLowerCase() ?? '';
    if (status == 'published' ||
        status == 'publish' ||
        status == 'active' ||
        status == 'aktif') {
      return true;
    }
    if (row['published_at'] != null) {
      return true;
    }
    final Map<String, dynamic> extraData = row['extra_data'] is Map
        ? Map<String, dynamic>.from(row['extra_data'] as Map)
        : <String, dynamic>{};
    final String extraStatus =
        (extraData['status'] as String?)?.trim().toLowerCase() ?? '';
    return extraStatus == 'published' ||
        extraStatus == 'publish' ||
        extraStatus == 'active' ||
        extraStatus == 'aktif';
  }

  Future<String?> _resolveSupabaseAccessUrl({
    required PustakaBuku buku,
    required String action,
  }) async {
    final String? directUrl = action == 'download'
        ? buku.downloadUrl ?? buku.fileUrl
        : buku.previewUrl ?? buku.fileUrl ?? buku.downloadUrl;
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    final String driveId = buku.driveFileId?.trim() ?? '';
    if (driveId.isNotEmpty) {
      if (action == 'download') {
        return 'https://drive.google.com/uc?export=download&id=$driveId';
      }
      return 'https://drive.google.com/file/d/$driveId/preview';
    }

    final String? storageUrl = await _resolveSupabaseStorageAssetUrl(
      directUrl: action == 'download' ? buku.downloadUrl : buku.previewUrl,
      storagePath: action == 'download'
          ? (buku.downloadStoragePath ?? buku.fileStoragePath)
          : (buku.previewStoragePath ?? buku.fileStoragePath),
      bucket: buku.fileStorageBucket,
      defaultBucket: AppConfig.supabasePustakaFilesBucket,
      isPublic: buku.isFilePublic,
    );
    if (storageUrl != null && storageUrl.isNotEmpty) {
      return storageUrl;
    }

    return null;
  }

  Future<PustakaBuku> _hydrateSupabaseBookUrls(PustakaBuku buku) async {
    final String? coverUrl = await _resolveSupabaseStorageAssetUrl(
      directUrl: buku.coverUrl,
      storagePath: buku.coverStoragePath,
      bucket: buku.coverStorageBucket,
      defaultBucket: AppConfig.supabasePustakaCoversBucket,
      isPublic: buku.isCoverPublic,
    );
    final String? previewUrl = await _resolveSupabaseStorageAssetUrl(
      directUrl: buku.previewUrl,
      storagePath: buku.previewStoragePath,
      bucket: buku.fileStorageBucket,
      defaultBucket: AppConfig.supabasePustakaFilesBucket,
      isPublic: buku.isFilePublic,
    );
    final String? downloadUrl = await _resolveSupabaseStorageAssetUrl(
      directUrl: buku.downloadUrl,
      storagePath: buku.downloadStoragePath,
      bucket: buku.fileStorageBucket,
      defaultBucket: AppConfig.supabasePustakaFilesBucket,
      isPublic: buku.isFilePublic,
    );
    final String? fileUrl = await _resolveSupabaseStorageAssetUrl(
      directUrl: buku.fileUrl,
      storagePath: buku.fileStoragePath,
      bucket: buku.fileStorageBucket,
      defaultBucket: AppConfig.supabasePustakaFilesBucket,
      isPublic: buku.isFilePublic,
    );
    return buku.copyWith(
      coverUrl: coverUrl ?? buku.coverUrl,
      previewUrl: previewUrl ?? buku.previewUrl,
      downloadUrl: downloadUrl ?? buku.downloadUrl,
      fileUrl: fileUrl ?? buku.fileUrl,
    );
  }

  Future<String?> _resolveSupabaseStorageAssetUrl({
    required String? directUrl,
    required String? storagePath,
    required String? bucket,
    required String defaultBucket,
    required bool isPublic,
  }) async {
    final String normalizedDirectUrl = directUrl?.trim() ?? '';
    if (PustakaBuku._looksLikeUrl(normalizedDirectUrl)) {
      return normalizedDirectUrl;
    }

    final String normalizedPath = storagePath?.trim() ?? '';
    if (normalizedPath.isEmpty) {
      return null;
    }

    final _SupabaseStorageRef storageRef = _parseStorageRef(
      normalizedPath,
      fallbackBucket: bucket?.trim().isNotEmpty == true
          ? bucket!.trim()
          : defaultBucket,
    );
    if (storageRef.path.isEmpty) {
      return null;
    }

    final StorageFileApi storage = Supabase.instance.client.storage.from(
      storageRef.bucket,
    );
    if (isPublic) {
      return storage.getPublicUrl(storageRef.path);
    }
    return storage.createSignedUrl(
      storageRef.path,
      AppConfig.supabaseStorageSignedUrlTtlSeconds,
    );
  }

  _SupabaseStorageRef _parseStorageRef(
    String raw, {
    required String fallbackBucket,
  }) {
    final String normalized = raw.trim().replaceFirst(RegExp(r'^/+'), '');
    final RegExpMatch? bucketMatch =
        RegExp(r'^([a-z0-9][a-z0-9._-]*):(.*)$', caseSensitive: false)
            .firstMatch(normalized);
    if (bucketMatch != null) {
      final String bucket = bucketMatch.group(1)?.trim() ?? fallbackBucket;
      final String path =
          (bucketMatch.group(2) ?? '').trim().replaceFirst(RegExp(r'^/+'), '');
      return _SupabaseStorageRef(bucket: bucket, path: path);
    }
    return _SupabaseStorageRef(bucket: fallbackBucket, path: normalized);
  }

  static const String _bookSelect =
      'id,title,author,description,access,format_file,file_size_bytes,drive_file_id,'
      'published_at,file_name,cover_key,file_key,file_pdf,extra_data,category_id,status';
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

  final String id;
  final String nama;
  final String slug;
  final bool isActive;

  factory PustakaKategori.fromJson(Map<String, dynamic> json) => PustakaKategori(
        id: (json['id'] ?? '').toString(),
        nama: (json['nama'] as String?)?.trim() ?? '-',
        slug: (json['slug'] as String?)?.trim() ?? '',
        isActive: (json['is_active'] as bool?) ?? true,
      );

  factory PustakaKategori.fromSupabase(Map<String, dynamic> json) =>
      PustakaKategori(
        id: (json['id'] ?? '').toString(),
        nama: (json['name'] as String?)?.trim() ?? '-',
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
    required this.isFilePublic,
    required this.isCoverPublic,
    this.fileUrl,
    this.previewUrl,
    this.downloadUrl,
    this.fileName,
    this.fileStoragePath,
    this.previewStoragePath,
    this.downloadStoragePath,
    this.coverStoragePath,
    this.fileStorageBucket,
    this.coverStorageBucket,
  });

  final String id;
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
  final bool isFilePublic;
  final bool isCoverPublic;
  final String? fileUrl;
  final String? previewUrl;
  final String? downloadUrl;
  final String? fileName;
  final String? fileStoragePath;
  final String? previewStoragePath;
  final String? downloadStoragePath;
  final String? coverStoragePath;
  final String? fileStorageBucket;
  final String? coverStorageBucket;

  factory PustakaBuku.fromJson(Map<String, dynamic> json) {
    final dynamic kategori = json['kategori'];
    final String kategoriNama = kategori is Map
        ? ((kategori['nama'] as String?)?.trim() ?? 'Dokumen')
        : 'Dokumen';
    final String? kategoriSlug =
        kategori is Map ? (kategori['slug'] as String?)?.trim() : null;
    return PustakaBuku(
      id: (json['id'] ?? '').toString(),
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
      hasFile:
          (json['can_download'] as bool?) ??
          ((json['has_file'] as bool?) ?? ((json['drive_file_id'] ?? '').toString().isNotEmpty)),
      isFilePublic: true,
      isCoverPublic: true,
      fileUrl: (json['file_url'] as String?)?.trim(),
      previewUrl: (json['preview_url'] as String?)?.trim(),
      downloadUrl: (json['download_url'] as String?)?.trim(),
      fileName: (json['file_name'] as String?)?.trim(),
    );
  }

  factory PustakaBuku.fromSupabase(
    Map<String, dynamic> json, {
    Map<String, Map<String, String>>? categories,
  }) {
    final Map<String, dynamic> extraData = json['extra_data'] is Map
        ? Map<String, dynamic>.from(json['extra_data'] as Map)
        : <String, dynamic>{};
    final String categoryId = (json['category_id'] ?? '').toString();
    final Map<String, String>? category =
        categories == null ? null : categories[categoryId];
    final String storageProvider = _firstNonEmpty(<dynamic>[
          json['storage_provider'],
          extraData['storage_provider'],
        ])?.toLowerCase() ??
        '';
    final bool usesSupabaseStorage = storageProvider == 'supabase';
    final String? driveFileId =
        _firstNonEmpty(<dynamic>[json['drive_file_id'], extraData['drive_file_id']]);
    final String? fileUrl = _firstNonEmpty(<dynamic>[
      extraData['file_url'],
      extraData['public_url'],
      extraData['download_url'],
      json['file_pdf'],
      json['file_key'],
    ]);
    final String? previewUrl = _firstNonEmpty(<dynamic>[
      extraData['preview_url'],
      extraData['reader_url'],
      extraData['read_url'],
    ]);
    final String? downloadUrl = _firstNonEmpty(<dynamic>[
      extraData['download_url'],
      extraData['file_download_url'],
      extraData['public_url'],
      json['file_pdf'],
      json['file_key'],
    ]);

    final String defaultFileBucket = _firstNonEmpty(<dynamic>[
          extraData['file_bucket'],
          extraData['storage_bucket'],
        ]) ??
        AppConfig.supabasePustakaFilesBucket;
    final String defaultCoverBucket = _firstNonEmpty(<dynamic>[
          extraData['cover_bucket'],
          extraData['storage_bucket'],
        ]) ??
        AppConfig.supabasePustakaCoversBucket;

    final String? fileStoragePath = usesSupabaseStorage
        ? _firstRelativeStoragePath(<dynamic>[
            extraData['file_path'],
            extraData['storage_path'],
            json['file_key'],
            json['file_pdf'],
          ])
        : null;
    final String? previewStoragePath = usesSupabaseStorage
        ? _firstRelativeStoragePath(<dynamic>[
            extraData['preview_path'],
            extraData['reader_path'],
            extraData['read_path'],
          ])
        : null;
    final String? downloadStoragePath = usesSupabaseStorage
        ? _firstRelativeStoragePath(<dynamic>[
            extraData['download_path'],
            extraData['file_download_path'],
            extraData['file_path'],
            extraData['storage_path'],
            json['file_key'],
            json['file_pdf'],
          ])
        : null;
    final String? coverStoragePath = usesSupabaseStorage
        ? _firstRelativeStoragePath(<dynamic>[
            extraData['cover_path'],
            extraData['cover_storage_path'],
            extraData['thumbnail_path'],
            json['cover_key'],
          ])
        : null;

    final bool isFilePublic =
        _asBool(extraData['file_is_public'], fallback: false) ||
            _asBool(extraData['storage_public'], fallback: false);
    final bool isCoverPublic =
        _asBool(extraData['cover_is_public'], fallback: true);

    final bool hasDirectFile = _looksLikeUrl(fileUrl) ||
        _looksLikeUrl(previewUrl) ||
        _looksLikeUrl(downloadUrl);

    return PustakaBuku(
      id: (json['id'] ?? '').toString(),
      judul: (json['title'] as String?)?.trim() ?? '-',
      penulis: (json['author'] as String?)?.trim() ?? '-',
      deskripsi: (json['description'] as String?)?.trim() ?? '',
      kategoriNama: category?['name']?.trim().isNotEmpty == true
          ? category!['name']!
          : 'Dokumen',
      kategoriSlug: category?['slug'],
      akses: (json['access'] as String?)?.trim() ?? 'gratis',
      formatFile: (json['format_file'] as String?)?.trim(),
      ukuranFileBytes: (json['file_size_bytes'] as num?)?.toInt(),
      coverUrl: _firstNonEmpty(<dynamic>[
        extraData['cover_url'],
        extraData['thumbnail_url'],
        json['cover_key'],
      ]),
      driveFileId: driveFileId,
      hasFile: (driveFileId != null && driveFileId.isNotEmpty) ||
          hasDirectFile ||
          (fileStoragePath?.isNotEmpty ?? false) ||
          (downloadStoragePath?.isNotEmpty ?? false),
      isFilePublic: isFilePublic,
      isCoverPublic: isCoverPublic,
      fileUrl: fileUrl,
      previewUrl: previewUrl,
      downloadUrl: downloadUrl,
      fileName: _firstNonEmpty(<dynamic>[json['file_name'], extraData['file_name']]),
      fileStoragePath: fileStoragePath,
      previewStoragePath: previewStoragePath,
      downloadStoragePath: downloadStoragePath,
      coverStoragePath: coverStoragePath,
      fileStorageBucket: defaultFileBucket,
      coverStorageBucket: defaultCoverBucket,
    );
  }

  PustakaBuku copyWith({
    String? coverUrl,
    String? fileUrl,
    String? previewUrl,
    String? downloadUrl,
  }) {
    return PustakaBuku(
      id: id,
      judul: judul,
      penulis: penulis,
      deskripsi: deskripsi,
      kategoriNama: kategoriNama,
      kategoriSlug: kategoriSlug,
      akses: akses,
      formatFile: formatFile,
      ukuranFileBytes: ukuranFileBytes,
      coverUrl: coverUrl ?? this.coverUrl,
      driveFileId: driveFileId,
      hasFile: hasFile,
      isFilePublic: isFilePublic,
      isCoverPublic: isCoverPublic,
      fileUrl: fileUrl ?? this.fileUrl,
      previewUrl: previewUrl ?? this.previewUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      fileName: fileName,
      fileStoragePath: fileStoragePath,
      previewStoragePath: previewStoragePath,
      downloadStoragePath: downloadStoragePath,
      coverStoragePath: coverStoragePath,
      fileStorageBucket: fileStorageBucket,
      coverStorageBucket: coverStorageBucket,
    );
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static bool _looksLikeUrl(String? value) {
    if (value == null || value.isEmpty) {
      return false;
    }
    final Uri? uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }

  static String? _firstRelativeStoragePath(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isEmpty || _looksLikeUrl(text)) {
        continue;
      }
      return text;
    }
    return null;
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final String normalized = value?.toString().trim().toLowerCase() ?? '';
    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'on') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no' ||
        normalized == 'off') {
      return false;
    }
    return fallback;
  }
}

class _SupabaseStorageRef {
  const _SupabaseStorageRef({
    required this.bucket,
    required this.path,
  });

  final String bucket;
  final String path;
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
