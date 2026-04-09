import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:get/get.dart' hide Response;
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import '../../app/config/app_config.dart';

class HalamanPasar extends StatefulWidget {
  const HalamanPasar({super.key});
  @override
  State<HalamanPasar> createState() => _HalamanPasarState();
}

enum _Filter { all, gainers, losers, watchlist }

enum _Sort { cap, chg }

enum _ChartRange { h24, d7, m1, m3, ytd, y1 }

class _HalamanPasarState extends State<HalamanPasar> {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.isSupabaseNativeEnabled
          ? 'https://api.binance.com'
          : AppConfig.apiBaseUrl,
    ),
  );
  final ScrollController scroll = ScrollController();
  final TextEditingController search = TextEditingController();
  final GetStorage box = GetStorage();
  final List<_Coin> coins = <_Coin>[];
  final Set<String> fav = <String>{};
  bool loading = true, loadingMore = false, hasMore = true;
  int page = 1;
  int uiPage = 1;
  static const int _pageSize = 10;
  String? error;
  double? global24h;
  _Filter filter = _Filter.all;
  _Sort sort = _Sort.cap;
  String q = '';

  @override
  void initState() {
    super.initState();
    final dynamic raw = box.read('pasar_watchlist');
    if (raw is List) fav.addAll(raw.map((e) => '$e'));
    search.addListener(() => setState(() {
          q = search.text.trim().toLowerCase();
          uiPage = 1;
        }));
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.extentAfter < 600) {
        _loadMarkets();
      }
    });
    refresh();
  }

  @override
  void dispose() {
    dio.close();
    scroll.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
      page = 1;
      uiPage = 1;
      hasMore = true;
      coins.clear();
    });
    await Future.wait(<Future<void>>[_loadGlobal(), _loadMarkets(reset: true)]);
    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadGlobal() async {
    try {
      if (AppConfig.isSupabaseNativeEnabled) {
        final List<dynamic> rows =
            await _fetchBinanceTickerRows(dio: dio);
        final double usdtIdr = await _fetchUsdtIdrRate(dio: dio);
        final List<Map<String, dynamic>> items = rows
            .whereType<Map>()
            .map((Map row) => _normalizeBinanceMarketRow(
                  Map<String, dynamic>.from(row),
                  usdtIdr,
                ))
            .where((Map<String, dynamic> row) => row.isNotEmpty)
            .toList()
          ..sort((a, b) => (_d(b['market_cap']) ?? 0)
              .compareTo(_d(a['market_cap']) ?? 0));
        final List<Map<String, dynamic>> sample = items.take(120).toList();
        global24h = sample.isEmpty
            ? 0
            : sample
                    .map((Map<String, dynamic> row) =>
                        _d(row['price_change_percentage_24h']) ?? 0)
                    .reduce((a, b) => a + b) /
                sample.length;
      } else {
        final r = await dio.get('/api/pasar/global');
        final data = (r.data as Map?)?['data'] as Map?;
        global24h = _d(data?['market_cap_change_percentage_24h_usd']);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _loadMarkets({bool reset = false}) async {
    if (loadingMore || (!reset && !hasMore)) return;
    if (!reset && mounted) setState(() => loadingMore = true);
    final int p = reset ? 1 : page;
    try {
      late final List<_Coin> list;
      if (AppConfig.isSupabaseNativeEnabled) {
        final List<dynamic> rows = await _fetchBinanceTickerRows(dio: dio);
        final double usdtIdr = await _fetchUsdtIdrRate(dio: dio);
        final List<Map<String, dynamic>> items = rows
            .whereType<Map>()
            .map((Map row) => _normalizeBinanceMarketRow(
                  Map<String, dynamic>.from(row),
                  usdtIdr,
                ))
            .where((Map<String, dynamic> row) => row.isNotEmpty)
            .toList()
          ..sort((a, b) =>
              (_d(b['market_cap']) ?? 0).compareTo(_d(a['market_cap']) ?? 0));
        final int start = (p - 1) * 100;
        final int end = math.min(start + 100, items.length);
        final List<Map<String, dynamic>> pageItems =
            start >= items.length ? <Map<String, dynamic>>[] : items.sublist(start, end);
        list = pageItems.map(_Coin.fromJson).toList();
      } else {
        final r = await dio
            .get('/api/pasar/markets', queryParameters: <String, dynamic>{
          'vs_currency': 'idr',
          'order': 'market_cap_desc',
          'per_page': 100,
          'page': p,
        });
        final rows =
            ((r.data as Map?)?['data'] as List?)?.cast<dynamic>() ?? <dynamic>[];
        list = rows
            .whereType<Map>()
            .map((e) => _Coin.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        if (reset) {
          coins
            ..clear()
            ..addAll(list);
          page = 2;
        } else {
          coins.addAll(list);
          page = p + 1;
        }
        hasMore = list.length >= 100;
        error = null;
      });
    } on DioException catch (e) {
      if (mounted) {
        setState(() => error = e.response?.statusCode == 429
            ? 'market_rate_limit'.tr
            : 'market_load_failed'.tr);
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'market_load_failed'.tr);
      }
    } finally {
      if (mounted) {
        setState(() => loadingMore = false);
      }
    }
  }

  List<_Coin> get visible {
    Iterable<_Coin> out = coins;
    if (q.isNotEmpty) {
      out = out.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.symbol.toLowerCase().contains(q));
    }
    switch (filter) {
      case _Filter.all:
        break;
      case _Filter.gainers:
        out = out.where((c) => (c.chg24 ?? 0) > 0);
      case _Filter.losers:
        out = out.where((c) => (c.chg24 ?? 0) < 0);
      case _Filter.watchlist:
        out = out.where((c) => fav.contains(c.id));
    }
    final list = out.toList();
    if (sort == _Sort.cap) {
      list.sort((a, b) => (b.cap ?? 0).compareTo(a.cap ?? 0));
    } else {
      list.sort((a, b) => (b.chg24 ?? -999).compareTo(a.chg24 ?? -999));
    }
    return list;
  }

  void toggleFav(_Coin c) {
    setState(() {
      if (!fav.add(c.id)) fav.remove(c.id);
      box.write('pasar_watchlist', fav.toList());
    });
  }

  int _totalPagesFor(int itemCount) =>
      itemCount == 0 ? 1 : ((itemCount - 1) ~/ _pageSize) + 1;

  Future<void> _changeUiPage(int next, int totalPages) async {
    if (next < 1) return;
    if (next > totalPages) {
      if (hasMore && !loadingMore) {
        await _loadMarkets();
      }
      if (!mounted) return;
      final refreshedTotal = _totalPagesFor(visible.length);
      setState(() => uiPage = next.clamp(1, refreshedTotal).toInt());
      return;
    }
    setState(() => uiPage = next);
  }

  @override
  Widget build(BuildContext context) {
    final list = visible;
    final totalPages = _totalPagesFor(list.length);
    final currentUiPage = uiPage.clamp(1, totalPages).toInt();
    final start = list.isEmpty ? 0 : (currentUiPage - 1) * _pageSize;
    final end = math.min(start + _pageSize, list.length);
    final pageItems = list.sublist(start, end);
    return Scaffold(
      appBar: AppBar(
        title: Text('market_title'.tr),
        actions: <Widget>[
          PopupMenuButton<_Sort>(
            onSelected: (v) => setState(() {
              sort = v;
              uiPage = 1;
            }),
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: _Sort.cap, child: Text('market_sort_cap'.tr)),
              PopupMenuItem(
                  value: _Sort.chg, child: Text('market_sort_24h'.tr)),
            ],
          ),
          IconButton(onPressed: refresh, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          controller: scroll,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _GlobalCard(v: global24h),
                      const SizedBox(height: 12),
                      TextField(
                        controller: search,
                        decoration: InputDecoration(
                          hintText: 'market_search_hint'.tr,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: q.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: search.clear,
                                  icon: const Icon(Icons.close)),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: <Widget>[
                          _chip(
                              'market_filter_all'.tr,
                              filter == _Filter.all,
                              () => setState(() {
                                    filter = _Filter.all;
                                    uiPage = 1;
                                  })),
                          const SizedBox(width: 8),
                          _chip(
                              'market_filter_gainers'.tr,
                              filter == _Filter.gainers,
                              () => setState(() {
                                    filter = _Filter.gainers;
                                    sort = _Sort.chg;
                                    uiPage = 1;
                                  })),
                          const SizedBox(width: 8),
                          _chip(
                              'market_filter_losers'.tr,
                              filter == _Filter.losers,
                              () => setState(() {
                                    filter = _Filter.losers;
                                    sort = _Sort.chg;
                                    uiPage = 1;
                                  })),
                          const SizedBox(width: 8),
                          _chip(
                              'market_filter_watchlist'.tr,
                              filter == _Filter.watchlist,
                              () => setState(() {
                                    filter = _Filter.watchlist;
                                    uiPage = 1;
                                  })),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('market_binance_markets'.tr,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'market_showing_count'
                                    .trParams(<String, String>{
                                  'count': '${list.length}'
                                }),
                                style: const TextStyle(color: Colors.green)),
                          ]),
                      if (list.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'market_page_label'.trParams(<String, String>{
                                  'current': '$currentUiPage',
                                  'total': '$totalPages'
                                }),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                            Text(
                                'market_range_label'.trParams(<String, String>{
                                  'start': '${start + 1}',
                                  'end': '$end',
                                  'total': '${list.length}'
                                }),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ],
                      if (loading && coins.isEmpty)
                        ...List<Widget>.generate(
                            4,
                            (i) => const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: LinearProgressIndicator())),
                      if (error != null && coins.isEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _Err(message: error!, onRetry: refresh)),
                      if (!loading && error == null && list.isEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text('market_empty'.tr)))),
                    ]),
              ),
            ),
            if (pageItems.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: pageItems.length,
                  itemBuilder: (_, i) => _CoinTile(
                    c: pageItems[i],
                    favorite: fav.contains(pageItems[i].id),
                    onFav: () => toggleFav(pageItems[i]),
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => _CoinDetailPage(
                                coin: pageItems[i],
                                isFav: fav.contains(pageItems[i].id),
                                onFav: () => toggleFav(pageItems[i]))))
                        .then((_) => setState(() {})),
                  ),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                ),
              ),
            if (list.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: currentUiPage > 1
                            ? () => _changeUiPage(currentUiPage - 1, totalPages)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                        label: Text('market_prev'.tr),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (currentUiPage < totalPages) || hasMore
                            ? () => _changeUiPage(currentUiPage + 1, totalPages)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                        label: Text('market_next'.tr),
                      ),
                    ),
                  ]),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: <Widget>[
                  if (error != null && coins.isNotEmpty)
                    _Err(message: error!, onRetry: refresh),
                  if (loadingMore)
                    const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator()),
                  if (!hasMore && coins.isNotEmpty)
                    Text('market_all_loaded'.tr),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t, bool on, VoidCallback tap) =>
      ChoiceChip(label: Text(t), selected: on, onSelected: (_) => tap());
}

class _CoinTile extends StatelessWidget {
  const _CoinTile(
      {required this.c,
      required this.favorite,
      required this.onFav,
      required this.onTap});
  final _Coin c;
  final bool favorite;
  final VoidCallback onFav;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final up = (c.chg24 ?? 0) >= 0;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
            backgroundImage: c.image.isEmpty ? null : NetworkImage(c.image),
            child: c.image.isEmpty ? const Icon(Icons.token) : null),
        title: Row(children: [
          Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
          if (c.rank != null)
            Text('#${c.rank}',
                style: const TextStyle(fontSize: 11, color: Colors.grey))
        ]),
        subtitle: Text(c.symbol.toUpperCase()),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_idr(c.price),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(_pct(c.chg24),
                    style: TextStyle(
                        color: up ? Colors.green : Colors.red, fontSize: 12)),
              ]),
          IconButton(
              onPressed: onFav,
              icon: Icon(favorite ? Icons.star : Icons.star_border,
                  color: favorite ? Colors.amber : Colors.grey)),
        ]),
      ),
    );
  }
}

class _CoinDetailPage extends StatefulWidget {
  const _CoinDetailPage(
      {required this.coin, required this.isFav, required this.onFav});
  final _Coin coin;
  final bool isFav;
  final VoidCallback onFav;
  @override
  State<_CoinDetailPage> createState() => _CoinDetailPageState();
}

class _CoinDetailPageState extends State<_CoinDetailPage> {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.isSupabaseNativeEnabled
          ? 'https://api.binance.com'
          : AppConfig.apiBaseUrl,
    ),
  );
  bool loading = true;
  bool loadingChart = false;
  String? error;
  _Detail? d;
  List<double> chart = <double>[];
  _ChartRange chartRange = _ChartRange.d7;
  late bool fav = widget.isFav;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    dio.close();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (AppConfig.isSupabaseNativeEnabled) {
        final String symbol = widget.coin.symbol.toUpperCase();
        final double usdtIdr = await _fetchUsdtIdrRate(dio: dio);
        final rs = await Future.wait<Response<dynamic>>([
          dio.get('/api/v3/ticker/24hr', queryParameters: <String, dynamic>{
            'symbol': '${symbol}USDT',
          }),
          dio.get('/api/v3/klines', queryParameters: _buildBinanceChartParams(
            symbol: symbol,
            days: _chartDays(chartRange),
          )),
        ]);
        d = _Detail.fromJson(
          _buildBinanceDetailPayload(
            symbol: symbol,
            ticker: rs[0].data is Map<String, dynamic>
                ? rs[0].data as Map<String, dynamic>
                : Map<String, dynamic>.from(rs[0].data as Map),
            usdtIdr: usdtIdr,
          ),
        );
        chart = _extractBinanceChartPrices(rs[1].data, usdtIdr);
      } else {
        final rs = await Future.wait<Response<dynamic>>([
          dio.get('/api/pasar/detail', queryParameters: {
            'symbol': widget.coin.symbol.toUpperCase(),
          }),
          dio.get('/api/pasar/chart', queryParameters: {
            'symbol': widget.coin.symbol.toUpperCase(),
            'days': _chartDays(chartRange),
          }),
        ]);
        final detailRaw = (rs[0].data as Map?)?['data'];
        d = _Detail.fromJson(detailRaw is Map
            ? Map<String, dynamic>.from(detailRaw)
            : <String, dynamic>{});
        final raw = (rs[1].data as Map?)?['data'];
        chart = <double>[];
        if (raw is List) {
          for (final p in raw) {
            final v = _d(p);
            if (v != null) chart.add(v);
          }
        }
      }
    } on DioException catch (e) {
      error = e.response?.statusCode == 429
          ? 'market_rate_limit'.tr
          : 'market_detail_failed'.tr;
    } catch (_) {
      error = 'market_detail_failed'.tr;
    }
    if (mounted) {
      setState(() => loading = false);
    }
  }

  int _chartDays(_ChartRange r) {
    switch (r) {
      case _ChartRange.h24:
        return 1;
      case _ChartRange.d7:
        return 7;
      case _ChartRange.m1:
        return 30;
      case _ChartRange.m3:
        return 90;
      case _ChartRange.ytd:
        final now = DateTime.now();
        final jan1 = DateTime(now.year, 1, 1);
        return math.max(1, now.difference(jan1).inDays + 1);
      case _ChartRange.y1:
        return 365;
    }
  }

  String _chartLabel(_ChartRange r) {
    switch (r) {
      case _ChartRange.h24:
        return '24j';
      case _ChartRange.d7:
        return '7h';
      case _ChartRange.m1:
        return '1B';
      case _ChartRange.m3:
        return '3B';
      case _ChartRange.ytd:
        return 'YTD';
      case _ChartRange.y1:
        return '1T';
    }
  }

  String _chartTitle(_ChartRange r) {
    switch (r) {
      case _ChartRange.h24:
        return 'market_chart_24h'.tr;
      case _ChartRange.d7:
        return 'market_chart_7d'.tr;
      case _ChartRange.m1:
        return 'market_chart_1m'.tr;
      case _ChartRange.m3:
        return 'market_chart_3m'.tr;
      case _ChartRange.ytd:
        return 'market_chart_ytd'.tr;
      case _ChartRange.y1:
        return 'market_chart_1y'.tr;
    }
  }

  Future<void> _reloadChart() async {
    if (loadingChart) return;
    if (mounted) setState(() => loadingChart = true);
    try {
      late final List<double> next;
      if (AppConfig.isSupabaseNativeEnabled) {
        final double usdtIdr = await _fetchUsdtIdrRate(dio: dio);
        final rs = await dio.get(
          '/api/v3/klines',
          queryParameters: _buildBinanceChartParams(
            symbol: widget.coin.symbol.toUpperCase(),
            days: _chartDays(chartRange),
          ),
        );
        next = _extractBinanceChartPrices(rs.data, usdtIdr);
      } else {
        final rs = await dio.get('/api/pasar/chart', queryParameters: {
          'symbol': widget.coin.symbol.toUpperCase(),
          'days': _chartDays(chartRange),
        });
        final raw = (rs.data as Map?)?['data'];
        next = <double>[];
        if (raw is List) {
          for (final p in raw) {
            final v = _d(p);
            if (v != null) next.add(v);
          }
        }
      }
      if (!mounted) return;
      setState(() => chart = next);
    } catch (_) {
      if (!mounted) return;
      setState(() => chart = <double>[]);
    } finally {
      if (mounted) setState(() => loadingChart = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.coin.name), actions: [
        IconButton(
            onPressed: () {
              widget.onFav();
              setState(() => fav = !fav);
            },
            icon: Icon(fav ? Icons.star : Icons.star_border,
                color: fav ? Colors.amber : null))
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: _Err(message: error!, onRetry: load))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              CircleAvatar(
                                  radius: 22,
                                  backgroundImage: widget.coin.image.isEmpty
                                      ? null
                                      : NetworkImage(widget.coin.image),
                                  child: widget.coin.image.isEmpty
                                      ? const Icon(Icons.token)
                                      : null),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(widget.coin.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    Text(widget.coin.symbol.toUpperCase(),
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Text(_idr(d!.price),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22)),
                                    Text(_pct(d!.chg24),
                                        style: TextStyle(
                                            color: (d!.chg24 ?? 0) >= 0
                                                ? Colors.green
                                                : Colors.red)),
                                  ])),
                            ]))),
                    const SizedBox(height: 12),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_chartTitle(chartRange),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _ChartRange.values
                                          .map((r) => Padding(
                                                padding: const EdgeInsets.only(
                                                    right: 8),
                                                child: ChoiceChip(
                                                  label: Text(_chartLabel(r)),
                                                  selected: chartRange == r,
                                                  onSelected: (_) {
                                                    if (chartRange == r) return;
                                                    setState(
                                                        () => chartRange = r);
                                                    _reloadChart();
                                                  },
                                                ),
                                              ))
                                          .toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                      height: 180,
                                      child: loadingChart
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : chart.length < 2
                                              ? Center(
                                                  child: Text(
                                                      'market_chart_unavailable'
                                                          .tr))
                                              : ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade50,
                                                      border: Border.all(
                                                          color:
                                                              Colors.black12),
                                                    ),
                                                    child: CustomPaint(
                                                      painter: _Chart(chart),
                                                      child: const SizedBox
                                                          .expand(),
                                                    ),
                                                  ),
                                                )),
                                ]))),
                    const SizedBox(height: 12),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final itemWidth =
                                    math.max(140.0, (c.maxWidth - 24) / 2);
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    _kv('market_market_cap'.tr, _idr(d!.cap),
                                        width: itemWidth),
                                    _kv('market_volume_24h'.tr, _idr(d!.vol),
                                        width: itemWidth),
                                    _kv('market_high_24h'.tr, _idr(d!.h24),
                                        width: itemWidth),
                                    _kv('market_low_24h'.tr, _idr(d!.l24),
                                        width: itemWidth),
                                    _kv('market_ath'.tr, _idr(d!.ath),
                                        width: itemWidth),
                                    _kv('market_atl'.tr, _idr(d!.atl),
                                        width: itemWidth),
                                  ],
                                );
                              },
                            ))),
                    const SizedBox(height: 12),
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('market_about_coin'.tr,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  Text(d!.desc.isEmpty
                                      ? 'market_desc_unavailable'.tr
                                      : d!.desc),
                                  if (d!.home.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                        'market_website'.trParams(
                                            <String, String>{'url': d!.home}),
                                        style:
                                            const TextStyle(color: Colors.teal))
                                  ],
                                ]))),
                  ],
                ),
    );
  }

  Widget _kv(String k, String v, {double width = 150}) => Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade50),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(v, style: const TextStyle(fontWeight: FontWeight.bold))
        ]),
      );
}

class _Chart extends CustomPainter {
  _Chart(this.v);
  final List<double> v;
  @override
  void paint(Canvas c, Size s) {
    final min = v.reduce(math.min),
        max = v.reduce(math.max),
        range = (max - min).abs() < 1e-6 ? 1 : max - min;
    final up = v.last >= v.first;
    final col = up ? Colors.green : Colors.red;
    for (int i = 1; i <= 3; i++) {
      final y = s.height * i / 4;
      c.drawLine(
          Offset(0, y), Offset(s.width, y), Paint()..color = Colors.black12);
    }
    final line = Path(), fill = Path();
    for (int i = 0; i < v.length; i++) {
      final x = i * s.width / (v.length - 1);
      final y = s.height - (((v[i] - min) / range) * (s.height - 10)) - 5;
      if (i == 0) {
        line.moveTo(x, y);
        fill.moveTo(x, s.height);
        fill.lineTo(x, y);
      } else {
        line.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(s.width, s.height);
    fill.close();
    c.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(colors: [
            col.withValues(alpha: 0.2),
            col.withValues(alpha: 0.02)
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              .createShader(Offset.zero & s));
    c.drawPath(
        line,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _Chart old) => old.v != v;
}

class _GlobalCard extends StatelessWidget {
  const _GlobalCard({required this.v});
  final double? v;
  @override
  Widget build(BuildContext context) {
    final up = (v ?? 0) >= 0;
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('market_sentiment'.tr,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(
                v == null
                    ? 'market_loading'.tr
                    : (up ? 'market_bullish'.tr : 'market_bearish'.tr),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('market_24h_mcap'.tr,
                style: const TextStyle(fontSize: 11, color: Colors.black54)),
            const SizedBox(height: 4),
            Text(v == null ? '--' : _pct(v),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: up ? Colors.green.shade700 : Colors.red.shade700)),
          ]),
        ]),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: Text('try_again'.tr))
      ]);
}

class _Coin {
  const _Coin(
      {required this.id,
      required this.name,
      required this.symbol,
      required this.image,
      required this.price,
      required this.chg24,
      required this.rank,
      required this.cap});
  factory _Coin.fromJson(Map<String, dynamic> j) => _Coin(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '-').toString(),
        symbol: (j['symbol'] ?? '-').toString(),
        image: (j['image'] ?? '').toString(),
        price: _d(j['current_price']) ?? 0,
        chg24: _d(j['price_change_percentage_24h']),
        rank: (j['market_cap_rank'] as num?)?.toInt(),
        cap: _d(j['market_cap']),
      );
  final String id, name, symbol, image;
  final double price;
  final double? chg24;
  final int? rank;
  final double? cap;
}

class _Detail {
  const _Detail(
      {required this.price,
      required this.chg24,
      required this.cap,
      required this.vol,
      required this.h24,
      required this.l24,
      required this.ath,
      required this.atl,
      required this.desc,
      required this.home});
  factory _Detail.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('price') ||
        j.containsKey('cap') ||
        j.containsKey('vol')) {
      return _Detail(
        price: _d(j['price']) ?? 0,
        chg24: _d(j['chg24']),
        cap: _d(j['cap']) ?? 0,
        vol: _d(j['vol']) ?? 0,
        h24: _d(j['h24']) ?? 0,
        l24: _d(j['l24']) ?? 0,
        ath: _d(j['ath']) ?? 0,
        atl: _d(j['atl']) ?? 0,
        desc: (j['desc'] ?? '').toString(),
        home: (j['home'] ?? '').toString(),
      );
    }

    final m = j['market_data'] is Map
        ? Map<String, dynamic>.from(j['market_data'] as Map)
        : <String, dynamic>{};
    Map<String, dynamic> map(String k) => m[k] is Map
        ? Map<String, dynamic>.from(m[k] as Map)
        : <String, dynamic>{};
    String desc = '';
    final rawDesc =
        (j['description'] is Map) ? (j['description'] as Map)['en'] : null;
    if (rawDesc is String) {
      desc = _strip(rawDesc);
      if (desc.length > 600) desc = '${desc.substring(0, 600)}...';
    }
    String home = '';
    final hp = (j['links'] is Map) ? (j['links'] as Map)['homepage'] : null;
    if (hp is List) {
      for (final x in hp) {
        if (x is String && x.trim().isNotEmpty) {
          home = x.trim();
          break;
        }
      }
    }
    return _Detail(
      price: _d(map('current_price')['idr']) ?? 0,
      chg24: _d(m['price_change_percentage_24h']),
      cap: _d(map('market_cap')['idr']) ?? 0,
      vol: _d(map('total_volume')['idr']) ?? 0,
      h24: _d(map('high_24h')['idr']) ?? 0,
      l24: _d(map('low_24h')['idr']) ?? 0,
      ath: _d(map('ath')['idr']) ?? 0,
      atl: _d(map('atl')['idr']) ?? 0,
      desc: desc,
      home: home,
    );
  }
  final double price, cap, vol, h24, l24, ath, atl;
  final double? chg24;
  final String desc, home;
}

double? _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
String _pct(double? v) {
  final x = v ?? 0;
  return '${x >= 0 ? '+' : ''}${x.toStringAsFixed(2)}%';
}

String _idr(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final parts = abs.toStringAsFixed(2).split('.');
  final whole = _groupThousandsDot(parts[0]);
  final frac = parts.length > 1 ? parts[1] : '00';
  return 'Rp ${neg ? '-' : ''}$whole.$frac';
}

String _groupThousandsDot(String digits) {
  if (digits.length <= 3) return digits;
  final out = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    out.write(digits[i]);
    final remain = digits.length - i - 1;
    if (remain > 0 && remain % 3 == 0) out.write('.');
  }
  return out.toString();
}

String _strip(String s) => s
    .replaceAll(RegExp(r'<[^>]+>'), ' ')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\\s+'), ' ')
    .trim();

Future<List<dynamic>> _fetchBinanceTickerRows({required Dio dio}) async {
  final Response<dynamic> response = await dio.get<dynamic>('/api/v3/ticker/24hr');
  final dynamic data = response.data;
  return data is List ? data : const <dynamic>[];
}

Future<double> _fetchUsdtIdrRate({required Dio dio}) async {
  final Response<dynamic> response = await dio.get<dynamic>(
    '/api/v3/ticker/price',
    queryParameters: const <String, dynamic>{'symbol': 'USDTIDR'},
  );
  final dynamic raw = response.data;
  if (raw is Map) {
    final double value = _d(raw['price']) ?? 0;
    if (value > 0) {
      return value;
    }
  }
  return 16000;
}

Map<String, dynamic> _normalizeBinanceMarketRow(
  Map<String, dynamic> row,
  double usdtIdr,
) {
  final String pair = (row['symbol'] ?? '').toString().trim().toUpperCase();
  if (!pair.endsWith('USDT')) {
    return const <String, dynamic>{};
  }
  final String base = pair.substring(0, pair.length - 4);
  if (base.isEmpty ||
      base.contains('UP') ||
      base.contains('DOWN') ||
      base.contains('BULL') ||
      base.contains('BEAR')) {
    return const <String, dynamic>{};
  }

  final double last = (_d(row['lastPrice']) ?? 0) * usdtIdr;
  final double high = (_d(row['highPrice']) ?? 0) * usdtIdr;
  final double low = (_d(row['lowPrice']) ?? 0) * usdtIdr;
  final double quoteVolume = (_d(row['quoteVolume']) ?? 0) * usdtIdr;

  return <String, dynamic>{
    'id': base.toLowerCase(),
    'name': base,
    'symbol': base.toLowerCase(),
    'image':
        'https://raw.githubusercontent.com/spothq/cryptocurrency-icons/master/128/color/${base.toLowerCase()}.png',
    'current_price': last,
    'price_change_percentage_24h': _d(row['priceChangePercent']),
    'market_cap_rank': null,
    'market_cap': quoteVolume,
    'total_volume': _d(row['volume']),
    'high_24h': high,
    'low_24h': low,
  };
}

Map<String, dynamic> _buildBinanceDetailPayload({
  required String symbol,
  required Map<String, dynamic> ticker,
  required double usdtIdr,
}) {
  final double last = (_d(ticker['lastPrice']) ?? 0) * usdtIdr;
  final double high = (_d(ticker['highPrice']) ?? 0) * usdtIdr;
  final double low = (_d(ticker['lowPrice']) ?? 0) * usdtIdr;
  final double quoteVolume = (_d(ticker['quoteVolume']) ?? 0) * usdtIdr;
  return <String, dynamic>{
    'price': last,
    'chg24': _d(ticker['priceChangePercent']),
    'cap': quoteVolume,
    'vol': quoteVolume,
    'h24': high,
    'l24': low,
    'ath': high,
    'atl': low,
    'desc': '$symbol diperdagangkan di Binance spot pair ${symbol}USDT.',
    'home': 'https://www.binance.com/en/markets',
  };
}

Map<String, dynamic> _buildBinanceChartParams({
  required String symbol,
  required int days,
}) {
  late final String interval;
  late final int limit;
  if (days <= 1) {
    interval = '5m';
    limit = 288;
  } else if (days <= 7) {
    interval = '1h';
    limit = math.min(24 * days, 1000);
  } else if (days <= 31) {
    interval = '4h';
    limit = math.min(6 * days, 1000);
  } else {
    interval = '1d';
    limit = math.min(days, 1000);
  }
  return <String, dynamic>{
    'symbol': '${symbol.toUpperCase()}USDT',
    'interval': interval,
    'limit': limit,
  };
}

List<double> _extractBinanceChartPrices(dynamic raw, double usdtIdr) {
  if (raw is! List) {
    return const <double>[];
  }
  final List<double> prices = <double>[];
  for (final dynamic item in raw) {
    if (item is! List || item.length < 5) {
      continue;
    }
    final double close = (_d(item[4]) ?? 0) * usdtIdr;
    if (close > 0) {
      prices.add(close);
    }
  }
  return prices;
}
