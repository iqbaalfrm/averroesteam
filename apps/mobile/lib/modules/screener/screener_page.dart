import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';

class HalamanScreener extends StatefulWidget {
  const HalamanScreener({super.key});

  @override
  State<HalamanScreener> createState() => _HalamanScreenerState();
}

class _HalamanScreenerState extends State<HalamanScreener> {
  final Dio _dio = ApiDio.create();
  final TextEditingController _searchController = TextEditingController();

  bool _popupSudahTampil = false;
  bool _isLoading = true;
  String? _error;
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchScreener() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Map<String, dynamic> query = <String, dynamic>{};
      final String q = _searchController.text.trim();
      if (q.isNotEmpty) {
        query['q'] = q;
      }
      if (_statusFilter != 'all') {
        query['status'] = _statusFilter;
      }

      final Response<dynamic> response = await _dio.get<dynamic>(
        '${AppConfig.apiBaseUrl}/api/screener',
        queryParameters: query,
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

      setState(() {
        _items = parsed;
      });
    } catch (_) {
      setState(() {
        _error = 'Gagal memuat data screener.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                        'Screener Syariah',
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
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 32),
                      child: CircularProgressIndicator(),
                    )
                  else if (_error != null)
                    _ErrorCard(message: _error!, onRetry: _fetchScreener)
                  else if (_items.isEmpty)
                    const _EmptyCard()
                  else
                    ..._items.map(
                      (_ScreenerItem item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _KartuStatus(
                          item: item,
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
          hintText: 'Cari nama koin atau ticker...',
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
      const _FilterItem(value: 'all', label: 'Semua'),
      const _FilterItem(value: 'halal', label: 'Halal'),
      const _FilterItem(value: 'proses', label: 'Proses'),
      const _FilterItem(value: 'haram', label: 'Haram'),
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
  const _KartuStatus({required this.item, this.onTap});

  final _ScreenerItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final _StatusStyle statusStyle =
        _StatusStyle.fromStatus(item.statusSyariah);

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusStyle.badgeColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusStyle.icon,
                      size: 20,
                      color: statusStyle.iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.namaKoin,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusStyle.badgeColor,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: statusStyle.badgeColor.withValues(alpha: 0.7)),
              ),
              child: Text(
                statusStyle.label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: statusStyle.textColor,
                ),
              ),
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
      return const _StatusStyle(
        label: 'Halal',
        icon: Symbols.verified,
        iconColor: Color(0xFF059669),
        badgeColor: Color(0xFFECFDF5),
        textColor: Color(0xFF059669),
      );
    }
    if (status == 'haram') {
      return const _StatusStyle(
        label: 'Haram',
        icon: Symbols.block,
        iconColor: Color(0xFFF43F5E),
        badgeColor: Color(0xFFFFE4E6),
        textColor: Color(0xFFF43F5E),
      );
    }
    return const _StatusStyle(
      label: 'Proses',
      icon: Symbols.pending,
      iconColor: Color(0xFF64748B),
      badgeColor: Color(0xFFF1F5F9),
      textColor: Color(0xFF64748B),
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
  });

  final int id;
  final String namaKoin;
  final String simbol;
  final String statusSyariah;
  final String penjelasanFiqh;
  final String referensiUlama;

  factory _ScreenerItem.fromJson(Map<String, dynamic> json) {
    return _ScreenerItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      namaKoin: (json['nama_koin'] as String?)?.trim() ?? '-',
      simbol: (json['simbol'] as String?)?.trim() ?? '-',
      statusSyariah: (json['status_syariah'] as String?)?.trim() ?? 'proses',
      penjelasanFiqh: (json['penjelasan_fiqh'] as String?)?.trim() ?? '-',
      referensiUlama: (json['referensi_ulama'] as String?)?.trim() ?? '-',
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        children: <Widget>[
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Coba lagi'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'Data screener tidak ditemukan.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

void _showMetodologi(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return const _SheetMetodologi();
    },
  );
}

void _showDetailItem(BuildContext context, _ScreenerItem item) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Wrap(
          children: <Widget>[
            Text(
              '${item.namaKoin} (${item.simbol})',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Status: ${_StatusStyle.fromStatus(item.statusSyariah).label}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF059669),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.penjelasanFiqh,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.referensiUlama,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _SheetMetodologi extends StatelessWidget {
  const _SheetMetodologi();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            children: <Widget>[
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Symbols.gavel,
                      size: 20,
                      color: Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Metodologi & Catatan Analisis',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Standar Dewan Pengawas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Data screener bersumber dari CSV Averroes yang dimasukkan ke database, dengan mapping status halal/proses/haram sesuai kolom sharia.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
