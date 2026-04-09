import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/supabase_native_service.dart';

class PortofolioApi {
  PortofolioApi({Dio? dio}) : _dio = dio ?? ApiDio.create();

  final Dio _dio;

  Future<PortofolioListResult> fetchPortofolio() async {
    if (SupabaseNativeService.isEnabled) {
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final List<dynamic> rows = await Supabase.instance.client
          .from('portfolio_items')
          .select('id,asset_name,symbol,quantity,purchase_price')
          .eq('user_id', profileId)
          .order('created_at', ascending: false);
      final List<PortofolioItem> items = rows
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> row) => PortofolioItem.fromJson(
                <String, dynamic>{
                  'id': row['id'],
                  'nama_aset': row['asset_name'],
                  'simbol': row['symbol'],
                  'jumlah': row['quantity'],
                  'harga_beli': row['purchase_price'],
                  'nilai': ((row['quantity'] as num?)?.toDouble() ?? 0) *
                      ((row['purchase_price'] as num?)?.toDouble() ?? 0),
                },
              ))
          .toList();
      final double totalNilai =
          items.fold<double>(0, (double sum, PortofolioItem item) => sum + item.nilai);
      return PortofolioListResult(items: items, totalNilai: totalNilai);
    }

    final Response<dynamic> r =
        await _dio.get<dynamic>('${AppConfig.apiBaseUrl}/api/portofolio');
    final Map<String, dynamic> data = _extractMap(r.data);
    final List<dynamic> rows = (data['items'] as List<dynamic>?) ?? <dynamic>[];
    return PortofolioListResult(
      items: rows
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => PortofolioItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalNilai: (data['total_nilai'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<List<CryptoSearchItem>> searchCrypto(String q) async {
    if (SupabaseNativeService.isEnabled) {
      final Dio coinDio = Dio(
        BaseOptions(
          baseUrl: 'https://api.coingecko.com/api/v3',
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      final Response<dynamic> r = await coinDio.get<dynamic>(
        '/search',
        queryParameters: <String, dynamic>{'query': q},
      );
      final dynamic coins = r.data is Map<String, dynamic>
          ? (r.data as Map<String, dynamic>)['coins']
          : null;
      final List<dynamic> rows = coins is List<dynamic> ? coins : <dynamic>[];
      return rows
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => CryptoSearchItem.fromJson(<String, dynamic>{
                'id': e['id'],
                'nama': e['name'],
                'simbol': e['symbol'],
                'thumb': e['thumb'],
                'market_cap_rank': e['market_cap_rank'],
              }))
          .toList();
    }

    final Response<dynamic> r = await _dio.get<dynamic>(
      '${AppConfig.apiBaseUrl}/api/portofolio/crypto/search',
      queryParameters: <String, dynamic>{'q': q},
    );
    final dynamic root = r.data;
    final dynamic data = root is Map<String, dynamic> ? root['data'] : null;
    final List<dynamic> rows = data is List<dynamic> ? data : <dynamic>[];
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => CryptoSearchItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<PortofolioRiwayatItem>> fetchRiwayat() async {
    if (SupabaseNativeService.isEnabled) {
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final List<dynamic> rows = await Supabase.instance.client
          .from('portfolio_history')
          .select(
            'id,action,asset_name,symbol,quantity,purchase_price,total_value,created_at',
          )
          .eq('user_id', profileId)
          .order('created_at', ascending: false);
      return rows
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => PortofolioRiwayatItem.fromJson(<String, dynamic>{
                'id': e['id'],
                'aksi': e['action'],
                'nama_aset': e['asset_name'],
                'simbol': e['symbol'],
                'jumlah': e['quantity'],
                'harga_beli': e['purchase_price'],
                'nilai': e['total_value'],
                'created_at': e['created_at'],
              }))
          .toList();
    }

    final Response<dynamic> r =
        await _dio.get<dynamic>('${AppConfig.apiBaseUrl}/api/portofolio/riwayat');
    final dynamic root = r.data;
    final dynamic data = root is Map<String, dynamic> ? root['data'] : null;
    final List<dynamic> rows = data is List<dynamic> ? data : <dynamic>[];
    return rows
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => PortofolioRiwayatItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<PortofolioItem> createPortofolio({
    required String namaAset,
    required String simbol,
    required double jumlah,
    required double hargaBeli,
  }) async {
    if (SupabaseNativeService.isEnabled) {
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final List<dynamic> rows = await Supabase.instance.client
          .from('portfolio_items')
          .insert(<String, dynamic>{
            'user_id': profileId,
            'asset_name': namaAset,
            'symbol': simbol.toUpperCase(),
            'quantity': jumlah,
            'purchase_price': hargaBeli,
          })
          .select();
      await Supabase.instance.client.from('portfolio_history').insert(
        <String, dynamic>{
          'user_id': profileId,
          'portfolio_item_id': (rows.first as Map)['id'],
          'action': 'create',
          'asset_name': namaAset,
          'symbol': simbol.toUpperCase(),
          'quantity': jumlah,
          'purchase_price': hargaBeli,
          'total_value': jumlah * hargaBeli,
        },
      );
      return PortofolioItem.fromJson(<String, dynamic>{
        'id': (rows.first as Map)['id'],
        'nama_aset': namaAset,
        'simbol': simbol.toUpperCase(),
        'jumlah': jumlah,
        'harga_beli': hargaBeli,
        'nilai': jumlah * hargaBeli,
      });
    }

    final Response<dynamic> r = await _dio.post<dynamic>(
      '${AppConfig.apiBaseUrl}/api/portofolio',
      data: <String, dynamic>{
        'nama_aset': namaAset,
        'simbol': simbol,
        'jumlah': jumlah,
        'harga_beli': hargaBeli,
      },
    );
    return PortofolioItem.fromJson(_extractMap(r.data));
  }

  Future<PortofolioItem> updatePortofolio({
    required String id,
    required String namaAset,
    required String simbol,
    required double jumlah,
    required double hargaBeli,
  }) async {
    if (SupabaseNativeService.isEnabled) {
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final List<dynamic> rows = await Supabase.instance.client
          .from('portfolio_items')
          .update(<String, dynamic>{
            'asset_name': namaAset,
            'symbol': simbol.toUpperCase(),
            'quantity': jumlah,
            'purchase_price': hargaBeli,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('user_id', profileId)
          .select();
      await Supabase.instance.client.from('portfolio_history').insert(
        <String, dynamic>{
          'user_id': profileId,
          'portfolio_item_id': id,
          'action': 'update',
          'asset_name': namaAset,
          'symbol': simbol.toUpperCase(),
          'quantity': jumlah,
          'purchase_price': hargaBeli,
          'total_value': jumlah * hargaBeli,
        },
      );
      return PortofolioItem.fromJson(<String, dynamic>{
        'id': (rows.first as Map)['id'],
        'nama_aset': namaAset,
        'simbol': simbol.toUpperCase(),
        'jumlah': jumlah,
        'harga_beli': hargaBeli,
        'nilai': jumlah * hargaBeli,
      });
    }

    final Response<dynamic> r = await _dio.put<dynamic>(
      '${AppConfig.apiBaseUrl}/api/portofolio/$id',
      data: <String, dynamic>{
        'nama_aset': namaAset,
        'simbol': simbol,
        'jumlah': jumlah,
        'harga_beli': hargaBeli,
      },
    );
    return PortofolioItem.fromJson(_extractMap(r.data));
  }

  Future<void> deletePortofolio(String id) async {
    if (SupabaseNativeService.isEnabled) {
      final String profileId = await SupabaseNativeService.ensureProfileId();
      final List<dynamic> existing = await Supabase.instance.client
          .from('portfolio_items')
          .select('asset_name,symbol,quantity,purchase_price')
          .eq('id', id)
          .eq('user_id', profileId)
          .limit(1);
      if (existing.isNotEmpty && existing.first is Map) {
        final Map row = existing.first as Map;
        await Supabase.instance.client.from('portfolio_history').insert(
          <String, dynamic>{
            'user_id': profileId,
            'portfolio_item_id': id,
            'action': 'delete',
            'asset_name': row['asset_name'],
            'symbol': row['symbol'],
            'quantity': row['quantity'],
            'purchase_price': row['purchase_price'],
            'total_value': ((row['quantity'] as num?)?.toDouble() ?? 0) *
                ((row['purchase_price'] as num?)?.toDouble() ?? 0),
          },
        );
      }
      await Supabase.instance.client
          .from('portfolio_items')
          .delete()
          .eq('id', id)
          .eq('user_id', profileId);
      return;
    }

    await _dio.delete<dynamic>('${AppConfig.apiBaseUrl}/api/portofolio/$id');
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

class PortofolioListResult {
  const PortofolioListResult({required this.items, required this.totalNilai});
  final List<PortofolioItem> items;
  final double totalNilai;
}

class PortofolioItem {
  const PortofolioItem({
    required this.id,
    required this.namaAset,
    required this.simbol,
    required this.jumlah,
    required this.hargaBeli,
    required this.nilai,
  });

  final String id;
  final String namaAset;
  final String simbol;
  final double jumlah;
  final double hargaBeli;
  final double nilai;

  factory PortofolioItem.fromJson(Map<String, dynamic> json) => PortofolioItem(
        id: (json['id'] ?? '').toString(),
        namaAset: (json['nama_aset'] as String?)?.trim() ?? '-',
        simbol: (json['simbol'] as String?)?.trim().toUpperCase() ?? '-',
        jumlah: (json['jumlah'] as num?)?.toDouble() ?? 0,
        hargaBeli: (json['harga_beli'] as num?)?.toDouble() ?? 0,
        nilai: (json['nilai'] as num?)?.toDouble() ?? 0,
      );
}

class CryptoSearchItem {
  const CryptoSearchItem({
    required this.id,
    required this.nama,
    required this.simbol,
    required this.thumb,
    this.marketCapRank,
  });

  final String id;
  final String nama;
  final String simbol;
  final String thumb;
  final int? marketCapRank;

  factory CryptoSearchItem.fromJson(Map<String, dynamic> json) => CryptoSearchItem(
        id: (json['id'] as String?)?.trim() ?? '',
        nama: (json['nama'] as String?)?.trim() ?? '-',
        simbol: (json['simbol'] as String?)?.trim().toUpperCase() ?? '-',
        thumb: (json['thumb'] as String?)?.trim() ?? '',
        marketCapRank: (json['market_cap_rank'] as num?)?.toInt(),
      );
}

class PortofolioRiwayatItem {
  const PortofolioRiwayatItem({
    required this.id,
    required this.aksi,
    required this.namaAset,
    required this.simbol,
    required this.jumlah,
    required this.hargaBeli,
    required this.nilai,
    required this.createdAt,
  });

  final String id;
  final String aksi;
  final String namaAset;
  final String simbol;
  final double jumlah;
  final double hargaBeli;
  final double nilai;
  final DateTime? createdAt;

  factory PortofolioRiwayatItem.fromJson(Map<String, dynamic> json) =>
      PortofolioRiwayatItem(
        id: (json['id'] ?? '').toString(),
        aksi: (json['aksi'] as String?)?.trim() ?? '-',
        namaAset: (json['nama_aset'] as String?)?.trim() ?? '-',
        simbol: (json['simbol'] as String?)?.trim().toUpperCase() ?? '-',
        jumlah: (json['jumlah'] as num?)?.toDouble() ?? 0,
        hargaBeli: (json['harga_beli'] as num?)?.toDouble() ?? 0,
        nilai: (json['nilai'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );
}
