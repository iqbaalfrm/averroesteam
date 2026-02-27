import 'package:dio/dio.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';

class PortofolioApi {
  PortofolioApi({Dio? dio}) : _dio = dio ?? ApiDio.create();

  final Dio _dio;

  Future<PortofolioListResult> fetchPortofolio() async {
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
    required int id,
    required String namaAset,
    required String simbol,
    required double jumlah,
    required double hargaBeli,
  }) async {
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

  Future<void> deletePortofolio(int id) async {
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

  final int id;
  final String namaAset;
  final String simbol;
  final double jumlah;
  final double hargaBeli;
  final double nilai;

  factory PortofolioItem.fromJson(Map<String, dynamic> json) => PortofolioItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
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

  final int id;
  final String aksi;
  final String namaAset;
  final String simbol;
  final double jumlah;
  final double hargaBeli;
  final double nilai;
  final DateTime? createdAt;

  factory PortofolioRiwayatItem.fromJson(Map<String, dynamic> json) =>
      PortofolioRiwayatItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        aksi: (json['aksi'] as String?)?.trim() ?? '-',
        namaAset: (json['nama_aset'] as String?)?.trim() ?? '-',
        simbol: (json['simbol'] as String?)?.trim().toUpperCase() ?? '-',
        jumlah: (json['jumlah'] as num?)?.toDouble() ?? 0,
        hargaBeli: (json['harga_beli'] as num?)?.toDouble() ?? 0,
        nilai: (json['nilai'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? ''),
      );
}
