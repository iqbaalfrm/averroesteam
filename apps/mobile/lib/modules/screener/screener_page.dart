import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';
import '../../presentation/common/content_ui.dart';

class HalamanScreener extends StatefulWidget {
  const HalamanScreener({super.key});

  @override
  State<HalamanScreener> createState() => _HalamanScreenerState();
}

class _HalamanScreenerState extends State<HalamanScreener> {
  final Dio _dio = ApiDio.create();
  final Dio _marketDio = Dio(
    BaseOptions(
      baseUrl: 'https://api.coingecko.com/api/v3',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: const <String, dynamic>{'Accept': 'application/json'},
    ),
  );
  final TextEditingController _searchController = TextEditingController();
  final GetStorage _box = GetStorage();
  static const String _cacheTopKey = 'screener_cache_top100_v1';

  bool _popupSudahTampil = false;
  bool _isLoading = true;
  String? _error;
  bool _usingCache = false;
  String _statusFilter = 'all';
  List<_ScreenerItem> _items = <_ScreenerItem>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_popupSudahTampil) {
      _popupSudahTampil = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMetodologi(context);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchScreener();
  }

  @override
  void dispose() {
    _marketDio.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchScreener() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _usingCache = false;
    });

    final Map<String, dynamic> query = <String, dynamic>{};
    final String q = _searchController.text.trim();
    if (q.isNotEmpty) {
      query['q'] = q;
    }
    if (_statusFilter != 'all') {
      query['status'] = _statusFilter;
    }
    query['top'] = 100;

    if (AppConfig.isSupabaseNativeEnabled) {
      try {
        final List<Map<String, dynamic>> rows = await _fetchSupabaseScreener(
          query: query,
        );
        final List<_ScreenerItem> parsed = rows
            .map((Map<String, dynamic> row) => _ScreenerItem.fromJson(row))
            .toList();
        _box.write(_cacheTopKey, rows);
        if (!mounted) return;
        setState(() {
          _items = parsed;
          _usingCache = false;
          _error = null;
          _isLoading = false;
        });
        return;
      } catch (_) {
        final List<_ScreenerItem> fallback = _readTopCachedItems();
        if (!mounted) return;
        setState(() {
          _items = fallback;
          _usingCache = fallback.isNotEmpty;
          _error = fallback.isEmpty ? 'screener_error_load'.tr : null;
          _isLoading = false;
        });
        return;
      }
    }

    for (int attempt = 1; attempt <= 2; attempt++) {
      try {
        final Response<dynamic> response = await _dio.get<dynamic>(
          '/api/screener',
          queryParameters: query,
          options: Options(receiveTimeout: const Duration(seconds: 35)),
        );

        final List<dynamic> rows = _extractList(response.data);
        final List<_ScreenerItem> parsed = rows
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (Map<dynamic, dynamic> row) => _ScreenerItem.fromJson(
                Map<String, dynamic>.from(row),
              ),
            )
            .toList();

        final List<Map<String, dynamic>> cacheRows = rows
            .whereType<Map<dynamic, dynamic>>()
            .map((Map<dynamic, dynamic> row) => Map<String, dynamic>.from(row))
            .toList();
        _box.write(_cacheTopKey, cacheRows);

        if (!mounted) return;
        setState(() {
          _items = parsed;
          _usingCache = false;
          _error = null;
          _isLoading = false;
        });
        return;
      } catch (e) {
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
        }
      }
    }

    final List<_ScreenerItem> fallback = _readTopCachedItems();
    if (fallback.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _items = fallback;
        _usingCache = true;
        _error = null;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _error = 'screener_error_load'.tr;
      });
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<_ScreenerItem> _readTopCachedItems() {
    final dynamic raw = _box.read(_cacheTopKey);
    if (raw is! List) return <_ScreenerItem>[];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> row) =>
            _ScreenerItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  String _logoForItem(_ScreenerItem item) {
    // Prioritaskan logo CoinGecko dari API
    if (item.logoUrl.isNotEmpty) return item.logoUrl;
    // Fallback ke Binance logo
    final String clean =
        item.simbol.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.isEmpty || clean == '-') return '';
    return 'https://bin.bnbstatic.com/static/assets/logos/$clean.png';
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final dynamic data = raw['data'];
      if (data is List<dynamic>) {
        return data;
      }
    }
    return <dynamic>[];
  }

  Future<List<Map<String, dynamic>>> _fetchSupabaseScreener({
    required Map<String, dynamic> query,
  }) async {
    final int top = (query['top'] as int?) ?? 100;
    final String q = (query['q'] as String?)?.trim() ?? '';
    final String status =
        (query['status'] as String?)?.trim().toLowerCase() ?? '';

    PostgrestFilterBuilder<dynamic> screenerQuery =
        Supabase.instance.client.from('screeners').select(
              'id,coin_name,symbol,status,sharia_status,fiqh_explanation,scholar_reference,extra_data',
            );

    if (q.isNotEmpty) {
      final String escaped = q.replaceAll(',', '').replaceAll('%', '');
      screenerQuery = screenerQuery.or(
        'coin_name.ilike.%$escaped%,symbol.ilike.%$escaped%',
      );
    }
    if (status.isNotEmpty) {
      screenerQuery = screenerQuery.eq('sharia_status', status);
    }

    final List<dynamic> screenerRows = await screenerQuery.order('coin_name');
    final List<Map<String, dynamic>> baseRows = screenerRows
        .whereType<Map>()
        .map((Map row) => _ScreenerItem.fromSupabase(
              Map<String, dynamic>.from(row),
            ).toJson())
        .toList();
    if (baseRows.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    final bool needsMarketFallback = baseRows.any((Map<String, dynamic> row) {
      final String logoUrl = (row['logo_url'] as String?)?.trim() ?? '';
      return logoUrl.isEmpty || row['peringkat_market_cap'] == null;
    });
    if (!needsMarketFallback) {
      _sortScreenerRows(baseRows);
      return baseRows;
    }

    final List<dynamic> marketRows = await _fetchCoinGeckoMarkets(top);
    final Map<String, Map<String, dynamic>> symbolMap =
        _buildCoinGeckoSymbolMap(marketRows);

    final List<Map<String, dynamic>> enriched =
        baseRows.map((Map<String, dynamic> row) {
      final String symbol =
          (row['simbol'] as String?)?.trim().toUpperCase() ?? '';
      final Map<String, dynamic>? market = symbolMap[symbol];
      if (market == null) {
        return row;
      }
      return <String, dynamic>{
        ...row,
        'harga_usd': market['current_price'],
        'market_cap': market['market_cap'],
        'perubahan_24j': market['price_change_percentage_24h'],
        'logo_url': market['image']?.toString() ?? row['logo_url'],
        'peringkat_market_cap': (market['market_cap_rank'] as num?)?.toInt(),
        'coingecko_id': market['id']?.toString() ?? '',
      };
    }).toList();

    _sortScreenerRows(enriched);
    return enriched;
  }

  Future<List<dynamic>> _fetchCoinGeckoMarkets(int top) async {
    final Response<dynamic> response = await _marketDio.get<dynamic>(
      '/coins/markets',
      queryParameters: <String, dynamic>{
        'vs_currency': 'usd',
        'order': 'market_cap_desc',
        'per_page': top.clamp(1, 250),
        'page': 1,
        'sparkline': false,
        'locale': 'id',
      },
    );
    final dynamic data = response.data;
    return data is List ? data : const <dynamic>[];
  }

  Map<String, Map<String, dynamic>> _buildCoinGeckoSymbolMap(
      List<dynamic> rows) {
    final Map<String, Map<String, dynamic>> out =
        <String, Map<String, dynamic>>{};
    for (final dynamic row in rows) {
      if (row is! Map) {
        continue;
      }
      final Map<String, dynamic> item = Map<String, dynamic>.from(row);
      final String symbol =
          (item['symbol'] as String?)?.trim().toUpperCase() ?? '';
      if (symbol.isEmpty) {
        continue;
      }
      final Map<String, dynamic>? existing = out[symbol];
      if (existing == null) {
        out[symbol] = item;
        continue;
      }
      final int currentRank =
          (item['market_cap_rank'] as num?)?.toInt() ?? 999999;
      final int existingRank =
          (existing['market_cap_rank'] as num?)?.toInt() ?? 999999;
      if (currentRank < existingRank) {
        out[symbol] = item;
      }
    }
    return out;
  }

  void _sortScreenerRows(List<Map<String, dynamic>> rows) {
    rows.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      final int rankA = (a['peringkat_market_cap'] as int?) ?? 999999;
      final int rankB = (b['peringkat_market_cap'] as int?) ?? 999999;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      final String nameA = (a['nama_koin'] as String?)?.toLowerCase() ?? '';
      final String nameB = (b['nama_koin'] as String?)?.toLowerCase() ?? '';
      return nameA.compareTo(nameB);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCFB),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFFDFCFB).withValues(alpha: 0.9),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _IconCircleButton(
                        icon: Symbols.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'screener_title'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      _IconCircleButton(
                        icon: Symbols.refresh,
                        color: const Color(0xFF059669),
                        onTap: _isLoading ? null : _fetchScreener,
                      ),
                      const SizedBox(width: 8),
                      _IconCircleButton(
                        icon: Symbols.info,
                        color: const Color(0xFF059669),
                        onTap: () => _showMetodologi(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: <Widget>[
                  _SearchField(
                    controller: _searchController,
                    onSubmit: (_) => _fetchScreener(),
                    onClear: () {
                      _searchController.clear();
                      _fetchScreener();
                    },
                  ),
                  const SizedBox(height: 12),
                  _FilterBar(
                    selected: _statusFilter,
                    onChanged: (String next) {
                      setState(() {
                        _statusFilter = next;
                      });
                      _fetchScreener();
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_usingCache)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        'screener_cache_notice'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: AppLoadingStateCard(
                        title: 'Memuat Screener',
                        message:
                            'Data aset kripto syariah sedang disiapkan untuk kamu cek.',
                      ),
                    )
                  else if (_error != null)
                    AppErrorStateCard(
                      message: _error!,
                      onRetry: () => _fetchScreener(),
                    )
                  else if (_items.isEmpty)
                    const AppEmptyStateCard(
                      text:
                          'Belum ada aset yang cocok dengan filter yang kamu pilih.',
                    )
                  else
                    ..._items.map(
                      (_ScreenerItem item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _KartuStatus(
                          item: item,
                          logoUrl: _logoForItem(item),
                          onTap: () => _showDetailItem(context, item),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  const _IconCircleButton({required this.icon, this.onTap, this.color});

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: color ?? const Color(0xFF64748B)),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmit,
        decoration: InputDecoration(
          icon: const Icon(
            Symbols.search,
            size: 20,
            color: Color(0xFF94A3B8),
          ),
          hintText: 'screener_search_hint'.tr,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(Symbols.close, size: 18),
                ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<_FilterItem> filters = <_FilterItem>[
      _FilterItem(value: 'all', label: 'screener_filter_all'.tr),
      _FilterItem(value: 'halal', label: 'screener_filter_halal'.tr),
      _FilterItem(value: 'proses', label: 'screener_filter_process'.tr),
      _FilterItem(value: 'haram', label: 'screener_filter_haram'.tr),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((_FilterItem filter) {
          final bool active = selected == filter.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: active,
              onSelected: (_) => onChanged(filter.value),
              selectedColor: const Color(0xFFECFDF5),
              backgroundColor: Colors.white,
              side: BorderSide(
                color:
                    active ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
              ),
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    active ? const Color(0xFF047857) : const Color(0xFF64748B),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterItem {
  const _FilterItem({required this.value, required this.label});

  final String value;
  final String label;
}

class _KartuStatus extends StatelessWidget {
  const _KartuStatus({required this.item, this.logoUrl, this.onTap});

  final _ScreenerItem item;
  final String? logoUrl;
  final VoidCallback? onTap;

  String _formatHarga(double? harga) {
    if (harga == null) return '-';
    if (harga >= 1) {
      return '\$${harga.toStringAsFixed(2)}';
    } else if (harga >= 0.01) {
      return '\$${harga.toStringAsFixed(4)}';
    } else {
      return '\$${harga.toStringAsFixed(6)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final _StatusStyle statusStyle =
        _StatusStyle.fromStatus(item.statusSyariah);

    final double? perubahan = item.perubahan24j;
    final bool isPositive = (perubahan ?? 0) >= 0;
    final Color perubahanColor =
        isPositive ? const Color(0xFF059669) : const Color(0xFFF43F5E);
    final String perubahanText = perubahan != null
        ? '${isPositive ? "+" : ""}${perubahan.toStringAsFixed(2)}%'
        : '-';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF8FAFC)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            // Logo koin
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusStyle.badgeColor,
                shape: BoxShape.circle,
              ),
              child: (logoUrl ?? '').isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        logoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          statusStyle.icon,
                          size: 20,
                          color: statusStyle.iconColor,
                        ),
                      ),
                    )
                  : Icon(
                      statusStyle.icon,
                      size: 20,
                      color: statusStyle.iconColor,
                    ),
            ),
            const SizedBox(width: 12),
            // Nama koin + simbol + rank
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          item.namaKoin,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.peringkatMarketCap != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${item.peringkatMarketCap}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.simbol,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Harga + perubahan 24j + status badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (item.hargaUsd != null)
                  Text(
                    _formatHarga(item.hargaUsd),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                if (perubahan != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      perubahanText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: perubahanColor,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusStyle.badgeColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: statusStyle.badgeColor.withValues(alpha: 0.7)),
                  ),
                  child: Text(
                    statusStyle.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusStyle.textColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusStyle {
  const _StatusStyle({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.badgeColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;
  final Color textColor;

  factory _StatusStyle.fromStatus(String raw) {
    final String status = raw.toLowerCase();
    if (status == 'halal') {
      return _StatusStyle(
        label: 'screener_filter_halal'.tr,
        icon: Symbols.verified,
        iconColor: const Color(0xFF059669),
        badgeColor: const Color(0xFFECFDF5),
        textColor: const Color(0xFF059669),
      );
    }
    if (status == 'haram') {
      return _StatusStyle(
        label: 'screener_filter_haram'.tr,
        icon: Symbols.block,
        iconColor: const Color(0xFFF43F5E),
        badgeColor: const Color(0xFFFFE4E6),
        textColor: const Color(0xFFF43F5E),
      );
    }
    return _StatusStyle(
      label: 'screener_filter_process'.tr,
      icon: Symbols.pending,
      iconColor: const Color(0xFF64748B),
      badgeColor: const Color(0xFFF1F5F9),
      textColor: const Color(0xFF64748B),
    );
  }
}

class _ScreenerItem {
  const _ScreenerItem({
    required this.id,
    required this.namaKoin,
    required this.simbol,
    required this.statusSyariah,
    required this.penjelasanFiqh,
    required this.referensiUlama,
    this.hargaUsd,
    this.marketCap,
    this.perubahan24j,
    this.logoUrl = '',
    this.peringkatMarketCap,
    this.coingeckoId = '',
  });

  final String id;
  final String namaKoin;
  final String simbol;
  final String statusSyariah;
  final String penjelasanFiqh;
  final String referensiUlama;
  final double? hargaUsd;
  final double? marketCap;
  final double? perubahan24j;
  final String logoUrl;
  final int? peringkatMarketCap;
  final String coingeckoId;

  factory _ScreenerItem.fromJson(Map<String, dynamic> json) {
    return _ScreenerItem(
      id: (json['id'] ?? '').toString(),
      namaKoin: (json['nama_koin'] as String?)?.trim() ?? '-',
      simbol: (json['simbol'] as String?)?.trim() ?? '-',
      statusSyariah: (json['status_syariah'] as String?)?.trim() ?? 'proses',
      penjelasanFiqh: (json['penjelasan_fiqh'] as String?)?.trim() ?? '-',
      referensiUlama: (json['referensi_ulama'] as String?)?.trim() ?? '-',
      hargaUsd: (json['harga_usd'] is num)
          ? (json['harga_usd'] as num).toDouble()
          : null,
      marketCap: (json['market_cap'] is num)
          ? (json['market_cap'] as num).toDouble()
          : null,
      perubahan24j: (json['perubahan_24j'] is num)
          ? (json['perubahan_24j'] as num).toDouble()
          : null,
      logoUrl: (json['logo_url'] as String?)?.trim() ?? '',
      peringkatMarketCap: (json['peringkat_market_cap'] is int)
          ? json['peringkat_market_cap'] as int
          : null,
      coingeckoId: (json['coingecko_id'] as String?)?.trim() ?? '',
    );
  }

  factory _ScreenerItem.fromSupabase(Map<String, dynamic> json) {
    final Map<String, dynamic> extraData = json['extra_data'] is Map
        ? Map<String, dynamic>.from(json['extra_data'] as Map)
        : <String, dynamic>{};
    return _ScreenerItem(
      id: (json['id'] ?? '').toString(),
      namaKoin: (json['coin_name'] as String?)?.trim() ?? '-',
      simbol: (json['symbol'] as String?)?.trim() ?? '-',
      statusSyariah: ((json['sharia_status'] ?? json['status']) as String?)
              ?.trim()
              .toLowerCase() ??
          'proses',
      penjelasanFiqh: (json['fiqh_explanation'] as String?)?.trim() ??
          (extraData['penjelasan_fiqh'] as String?)?.trim() ??
          '-',
      referensiUlama: (json['scholar_reference'] as String?)?.trim() ?? '-',
      hargaUsd: (extraData['harga_usd'] as num?)?.toDouble(),
      marketCap: (extraData['market_cap'] as num?)?.toDouble(),
      perubahan24j: (extraData['perubahan_24j'] as num?)?.toDouble(),
      logoUrl: (extraData['logo_url'] as String?)?.trim() ?? '',
      peringkatMarketCap: (extraData['peringkat_market_cap'] as num?)?.toInt(),
      coingeckoId: (extraData['coingecko_id'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'nama_koin': namaKoin,
      'simbol': simbol,
      'status_syariah': statusSyariah,
      'penjelasan_fiqh': penjelasanFiqh,
      'referensi_ulama': referensiUlama,
      'harga_usd': hargaUsd,
      'market_cap': marketCap,
      'perubahan_24j': perubahan24j,
      'logo_url': logoUrl,
      'peringkat_market_cap': peringkatMarketCap,
      'coingecko_id': coingeckoId,
    };
  }
}

void _showMetodologi(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return const _MetodologiDialog();
    },
  );
}

void _showDetailItem(BuildContext context, _ScreenerItem item) {
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      final _StatusStyle style = _StatusStyle.fromStatus(item.statusSyariah);
      final Map<String, String> fiqh = _parseFiqhSummary(item.penjelasanFiqh);
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.namaKoin,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.simbol,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Symbols.close, size: 18),
                      color: const Color(0xFF64748B),
                      splashRadius: 18,
                      tooltip: 'common_close'.tr,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: style.badgeColor,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: style.badgeColor.withValues(alpha: 0.75)),
                  ),
                  child: Text(
                    'screener_status'
                        .trParams(<String, String>{'status': style.label}),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: style.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'screener_fiqh_analysis'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _FiqhLine(
                                  label: 'screener_underlying'.tr,
                                  value: fiqh['underlying'] ?? '-'),
                              const SizedBox(height: 4),
                              _FiqhLine(
                                  label: 'screener_value'.tr,
                                  value: fiqh['nilai'] ?? '-'),
                              const SizedBox(height: 4),
                              _FiqhLine(
                                  label: 'screener_delivery'.tr,
                                  value: fiqh['serah_terima'] ?? '-'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'screener_source'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'screener_source_text'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'common_close'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Map<String, String> _parseFiqhSummary(String raw) {
  final Map<String, String> out = <String, String>{};
  final List<String> parts =
      raw.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  for (final p in parts) {
    final int idx = p.indexOf(':');
    if (idx <= 0) continue;
    final String key = p.substring(0, idx).trim().toLowerCase();
    final String value = p.substring(idx + 1).trim();
    if (key.startsWith('underlying')) {
      out['underlying'] = value;
    } else if (key.startsWith('nilai')) {
      out['nilai'] = value;
    } else if (key.startsWith('serah-terima') || key.startsWith('serah')) {
      out['serah_terima'] = value;
    }
  }
  return out;
}

class _FiqhLine extends StatelessWidget {
  const _FiqhLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF334155),
          height: 1.4,
        ),
        children: <TextSpan>[
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _MetodologiDialog extends StatelessWidget {
  const _MetodologiDialog();

  @override
  Widget build(BuildContext context) {
    final TextStyle bodyStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF475569),
      height: 1.45,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Symbols.gavel,
                      size: 18,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'screener_method_title'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Symbols.close, size: 18),
                    color: const Color(0xFF64748B),
                    splashRadius: 18,
                    tooltip: 'common_close'.tr,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'screener_method_data'.tr,
                          style: bodyStyle,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'screener_method_rules'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _MethodItem(
                        text: 'screener_method_rule_1'.tr,
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 8),
                      _MethodItem(
                        text: 'screener_method_rule_2'.tr,
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 8),
                      _MethodItem(
                        text: 'screener_method_rule_3'.tr,
                        style: bodyStyle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'screener_status_legend'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          _StatusPill(label: 'screener_filter_halal'.tr),
                          _StatusPill(label: 'screener_filter_process'.tr),
                          _StatusPill(label: 'screener_status_grey'.tr),
                          _StatusPill(label: 'screener_filter_haram'.tr),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          'screener_status_note'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'common_close'.tr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodItem extends StatelessWidget {
  const _MethodItem({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 6, right: 8),
          decoration: const BoxDecoration(
            color: Color(0xFF0F766E),
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}
