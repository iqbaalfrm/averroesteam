import 'package:dio/dio.dart';

import '../../app/services/api_dio.dart';

class DiskusiItem {
  const DiskusiItem({
    required this.id,
    required this.userId,
    required this.parentId,
    required this.judul,
    required this.isi,
    required this.createdAt,
    required this.namaUser,
    required this.replyCount,
  });

  final String id;
  final String userId;
  final String? parentId;
  final String judul;
  final String isi;
  final DateTime? createdAt;
  final String namaUser;
  final int replyCount;

  factory DiskusiItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return DiskusiItem(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      judul: (json['judul'] ?? 'Diskusi').toString(),
      isi: (json['isi'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      namaUser: user is Map ? (user['nama'] ?? 'Pengguna').toString() : 'Pengguna',
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DiskusiDetail {
  const DiskusiDetail({
    required this.thread,
    required this.replies,
  });

  final DiskusiItem thread;
  final List<DiskusiItem> replies;
}

class DiskusiListResult {
  const DiskusiListResult({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<DiskusiItem> items;
  final int page;
  final int totalPages;
}

class DiskusiApi {
  Dio _dio() => ApiDio.create();

  Future<Response<dynamic>> _getWithFallback(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio().get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && !path.startsWith('/api/')) {
        return _dio().get('/api$path', queryParameters: queryParameters);
      }
      rethrow;
    }
  }

  Future<Response<dynamic>> _postWithFallback(
    String path, {
    dynamic data,
  }) async {
    try {
      return await _dio().post(path, data: data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 && !path.startsWith('/api/')) {
        return _dio().post('/api$path', data: data);
      }
      rethrow;
    }
  }

  Future<DiskusiListResult> fetchThreads({
    int page = 1,
    int perPage = 20,
    String? query,
    String sort = 'terbaru',
  }) async {
    final rs = await _getWithFallback(
      '/diskusi',
      queryParameters: <String, dynamic>{
        'page': page,
        'per_page': perPage,
        'sort': sort,
        if ((query ?? '').trim().isNotEmpty) 'q': query!.trim(),
      },
    );
    final root = rs.data;
    final data = root is Map ? root['data'] : null;
    final itemsRaw = data is Map ? data['items'] : null;
    final pagination = data is Map ? data['pagination'] : null;
    final items = itemsRaw is List
        ? itemsRaw.whereType<Map>().map((e) => DiskusiItem.fromJson(e.cast<String, dynamic>())).toList()
        : <DiskusiItem>[];
    return DiskusiListResult(
      items: items,
      page: pagination is Map ? ((pagination['page'] as num?)?.toInt() ?? page) : page,
      totalPages: pagination is Map ? ((pagination['total_pages'] as num?)?.toInt() ?? 1) : 1,
    );
  }

  Future<DiskusiDetail> fetchThreadDetail(String threadId) async {
    final rs = await _getWithFallback('/diskusi/$threadId');
    final root = rs.data;
    final data = root is Map ? root['data'] : null;
    if (data is! Map) {
      throw Exception('Detail thread tidak valid');
    }
    final thread = DiskusiItem.fromJson(data.cast<String, dynamic>());
    final repliesRaw = data['balasan'];
    final replies = repliesRaw is List
        ? repliesRaw.whereType<Map>().map((e) => DiskusiItem.fromJson(e.cast<String, dynamic>())).toList()
        : <DiskusiItem>[];
    return DiskusiDetail(thread: thread, replies: replies);
  }

  Future<DiskusiItem> createThread({
    required String judul,
    required String isi,
    String? lampiranUrl,
  }) async {
    final rs = await _postWithFallback(
      '/diskusi',
      data: <String, dynamic>{
        'judul': judul.trim(),
        'isi': isi.trim(),
        if ((lampiranUrl ?? '').trim().isNotEmpty) 'lampiran_url': lampiranUrl!.trim(),
      },
    );
    final root = rs.data;
    final data = root is Map ? root['data'] : null;
    if (data is! Map) {
      throw Exception('Gagal membuat thread');
    }
    return DiskusiItem.fromJson(data.cast<String, dynamic>());
  }

  Future<void> replyThread({
    required String threadId,
    required String isi,
  }) async {
    await _postWithFallback(
      '/diskusi/$threadId/balas',
      data: <String, dynamic>{
        'isi': isi.trim(),
      },
    );
  }
}
