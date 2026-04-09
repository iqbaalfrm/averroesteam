import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/supabase_native_service.dart';

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

  bool get _isSupabaseNative => AppConfig.isSupabaseNativeEnabled;

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
    if (_isSupabaseNative) {
      final List<Map<String, dynamic>> rows =
          await _fetchSupabaseThreads(query: query, sort: sort);
      final int safePage = page < 1 ? 1 : page;
      final int start = (safePage - 1) * perPage;
      final List<DiskusiItem> items = rows
          .skip(start)
          .take(perPage)
          .map(DiskusiItem.fromJson)
          .toList();
      final int totalPages = rows.isEmpty ? 1 : (rows.length / perPage).ceil();
      return DiskusiListResult(
        items: items,
        page: safePage,
        totalPages: totalPages,
      );
    }

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
    if (_isSupabaseNative) {
      final client = SupabaseNativeService.client;
      final dynamic rootRaw = await client
          .from('discussion_posts')
          .select('id,user_id,parent_post_id,title,body,created_at')
          .eq('id', threadId)
          .maybeSingle();
      if (rootRaw is! Map) {
        throw Exception('Detail thread tidak valid');
      }

      final List<dynamic> repliesRaw = await client
          .from('discussion_posts')
          .select('id,user_id,parent_post_id,title,body,created_at')
          .eq('parent_post_id', threadId)
          .order('created_at');

      final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
        Map<String, dynamic>.from(rootRaw),
        ...repliesRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
      ];
      final Map<String, String> names = await _loadProfileNames(
        rows
            .map((Map<String, dynamic> row) => row['user_id']?.toString() ?? '')
            .where((String id) => id.isNotEmpty)
            .toSet()
            .toList(),
      );

      final DiskusiItem thread = _mapSupabaseDiskusiItem(
        Map<String, dynamic>.from(rootRaw),
        names: names,
        replyCount: repliesRaw.length,
      );
      final List<DiskusiItem> replies = repliesRaw
          .whereType<Map>()
          .map(
            (dynamic row) => _mapSupabaseDiskusiItem(
              Map<String, dynamic>.from(row as Map),
              names: names,
            ),
          )
          .toList();
      return DiskusiDetail(thread: thread, replies: replies);
    }

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
    if (_isSupabaseNative) {
      final client = SupabaseNativeService.client;
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final dynamic data = await client
          .from('discussion_posts')
          .insert(<String, dynamic>{
            'user_id': profileId,
            'title': judul.trim().isNotEmpty ? judul.trim() : 'Diskusi Baru',
            'body': isi.trim(),
          })
          .select('id,user_id,parent_post_id,title,body,created_at')
          .single();
      final Map<String, String> names = await _loadProfileNames(<String>[profileId]);
      return _mapSupabaseDiskusiItem(
        Map<String, dynamic>.from(data as Map),
        names: names,
      );
    }

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
    if (_isSupabaseNative) {
      final client = SupabaseNativeService.client;
      final String profileId = await SupabaseNativeService.ensureProfileId();
      await client.from('discussion_posts').insert(<String, dynamic>{
        'user_id': profileId,
        'parent_post_id': threadId,
        'body': isi.trim(),
      });
      return;
    }

    await _postWithFallback(
      '/diskusi/$threadId/balas',
      data: <String, dynamic>{
        'isi': isi.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchSupabaseThreads({
    String? query,
    required String sort,
  }) async {
    final client = SupabaseNativeService.client;
    final bool popular = sort.trim().toLowerCase() == 'terpopuler';
    final List<dynamic> rootRaw = await client
        .from('discussion_posts')
        .select('id,user_id,parent_post_id,title,body,created_at')
        .isFilter('parent_post_id', null)
        .order('created_at', ascending: false)
        .limit(popular ? 200 : 100);

    final List<Map<String, dynamic>> roots = rootRaw
        .whereType<Map>()
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .toList();
    final String q = (query ?? '').trim().toLowerCase();
    final List<String> threadIds =
        roots.map((Map<String, dynamic> row) => row['id'].toString()).toList();

    final Map<String, int> replyCounts = <String, int>{};
    if (threadIds.isNotEmpty) {
      final List<dynamic> repliesRaw = await client
          .from('discussion_posts')
          .select('id,parent_post_id')
          .inFilter('parent_post_id', threadIds);
      for (final dynamic row in repliesRaw) {
        if (row is! Map) {
          continue;
        }
        final String parentId = row['parent_post_id']?.toString() ?? '';
        if (parentId.isEmpty) {
          continue;
        }
        replyCounts[parentId] = (replyCounts[parentId] ?? 0) + 1;
      }
    }

    final Map<String, String> names = await _loadProfileNames(
      roots
          .map((Map<String, dynamic> row) => row['user_id']?.toString() ?? '')
          .where((String id) => id.isNotEmpty)
          .toSet()
          .toList(),
    );

    List<DiskusiItem> items = roots
        .map(
          (Map<String, dynamic> row) => _mapSupabaseDiskusiItem(
            row,
            names: names,
            replyCount: replyCounts[row['id']?.toString() ?? ''] ?? 0,
          ),
        )
        .toList();

    if (q.isNotEmpty) {
      items = items
          .where(
            (DiskusiItem item) =>
                item.judul.toLowerCase().contains(q) ||
                item.isi.toLowerCase().contains(q),
          )
          .toList();
    }

    if (popular) {
      items.sort((DiskusiItem a, DiskusiItem b) {
        final int countCompare = b.replyCount.compareTo(a.replyCount);
        if (countCompare != 0) {
          return countCompare;
        }
        final DateTime aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final DateTime bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
    }

    return items
        .map(
          (DiskusiItem item) => <String, dynamic>{
            'id': item.id,
            'user_id': item.userId,
            'parent_id': item.parentId,
            'judul': item.judul,
            'isi': item.isi,
            'created_at': item.createdAt?.toIso8601String(),
            'user': <String, dynamic>{'nama': item.namaUser},
            'reply_count': item.replyCount,
          },
        )
        .toList();
  }

  Future<Map<String, String>> _loadProfileNames(List<String> userIds) async {
    if (userIds.isEmpty) {
      return <String, String>{};
    }
    final List<dynamic> raw = await SupabaseNativeService.client
        .from('profiles')
        .select('id,full_name')
        .inFilter('id', userIds);
    final Map<String, String> result = <String, String>{};
    for (final dynamic row in raw) {
      if (row is! Map) {
        continue;
      }
      final String id = row['id']?.toString() ?? '';
      if (id.isEmpty) {
        continue;
      }
      result[id] = (row['full_name']?.toString().trim().isNotEmpty ?? false)
          ? row['full_name'].toString().trim()
          : 'Pengguna';
    }
    return result;
  }

  DiskusiItem _mapSupabaseDiskusiItem(
    Map<String, dynamic> row, {
    required Map<String, String> names,
    int replyCount = 0,
  }) {
    final String userId = row['user_id']?.toString() ?? '';
    return DiskusiItem(
      id: row['id']?.toString() ?? '',
      userId: userId,
      parentId: row['parent_post_id']?.toString(),
      judul: (row['title']?.toString().trim().isNotEmpty ?? false)
          ? row['title'].toString().trim()
          : 'Diskusi',
      isi: row['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      namaUser: names[userId] ?? 'Pengguna',
      replyCount: replyCount,
    );
  }
}
