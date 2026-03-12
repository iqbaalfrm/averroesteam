import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pustaka_api.dart';

class HalamanPustaka extends StatefulWidget {
  const HalamanPustaka({super.key});

  @override
  State<HalamanPustaka> createState() => _HalamanPustakaState();
}

class _HalamanPustakaState extends State<HalamanPustaka> {
  final PustakaApi _api = PustakaApi();
  final ScrollController _scrollController = ScrollController();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  List<PustakaKategori> _kategori = const <PustakaKategori>[];
  List<PustakaBuku> _buku = const <PustakaBuku>[];
  int _total = 0;
  int _page = 1;
  int _totalPages = 1;
  String? _selectedKategoriSlug;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 300) {
      _loadMore();
    }
  }

  Future<void> _load({String? kategoriSlug, bool resetKategori = false}) async {
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      _page = 1;
      _totalPages = 1;
      if (resetKategori) {
        _selectedKategoriSlug = kategoriSlug;
      } else if (kategoriSlug != null) {
        _selectedKategoriSlug = kategoriSlug;
      }
    });
    try {
      final kategori = await _api.fetchKategori();
      final buku = await _api.fetchBuku(
        page: 1,
        perPage: 10,
        kategoriSlug: _selectedKategoriSlug,
      );
      if (!mounted) return;
      setState(() {
        _kategori = kategori;
        _buku = buku.items;
        _total = buku.total;
        _page = buku.page;
        _totalPages = buku.totalPages;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'pustaka_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore) return;
    if (_page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final buku = await _api.fetchBuku(
        page: _page + 1,
        perPage: 10,
        kategoriSlug: _selectedKategoriSlug,
      );
      if (!mounted) return;
      setState(() {
        _buku = <PustakaBuku>[..._buku, ...buku.items];
        _total = buku.total;
        _page = buku.page;
        _totalPages = buku.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _openDetail(PustakaBuku buku) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PustakaDetailPage(
          bukuId: buku.id,
          initialData: buku,
          api: _api,
        ),
      ),
    );
  }

  Future<void> _openBukuAccess(PustakaBuku buku, String action) async {
    try {
      final access = await _api.requestAccessUrl(
        bukuId: buku.id,
        action: action,
      );
      final uri = Uri.tryParse(access.url);
      if (uri == null || access.url.isEmpty) {
        throw Exception('pustaka_invalid_url'.tr);
      }
      if (action == 'read' && (buku.formatFile ?? 'pdf').toLowerCase() == 'pdf'
          && !uri.host.contains('drive.google.com')) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _PdfReaderPage(
              title: buku.judul,
              pdfUrl: access.url,
            ),
          ),
        );
        return;
      }
      final mode = action == 'download'
          ? LaunchMode.externalApplication
          : LaunchMode.inAppWebView;
      await launchUrl(uri, mode: mode);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'download'
            ? 'pustaka_download_failed'.tr
            : 'pustaka_open_failed'.tr)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Row(
                      children: <Widget>[
                        _IconButtonCard(
                          icon: Symbols.arrow_back_ios_new_rounded,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'pustaka_title'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _IconButtonCard(
                    icon: Symbols.search_rounded,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _KategoriPustaka(
                    kategori: _kategori,
                    loading: _loading,
                    selectedSlug: _selectedKategoriSlug,
                    onSelect: (String? slug) =>
                        _load(kategoriSlug: slug, resetKategori: true),
                  ),
                  const SizedBox(height: 24),
                  _BannerUnggulan(),
                  const SizedBox(height: 24),
                  _JudulBagian(
                    judul: 'pustaka_newest_col'.tr,
                    aksi: 'pustaka_see_all'.tr,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    _PustakaError(
                      message: _error!,
                      onRetry: () => _load(),
                    )
                  else if (_loading)
                    const _PustakaLoadingList()
                  else if (_buku.isEmpty)
                    const _PustakaEmpty()
                  else
                    ..._buku.asMap().entries.map((entry) {
                      final int i = entry.key;
                      final PustakaBuku buku = entry.value;
                      final _DokumenUiStyle style = _mapBukuStyle(buku);
                      return Padding(
                        padding: EdgeInsets.only(bottom: i == _buku.length - 1 ? 0 : 16),
                        child: _KartuDokumen(
                          judul: buku.judul,
                          tag: style.tag,
                          info: style.info,
                          icon: style.icon,
                          warnaIcon: style.warnaIcon,
                          warnaTag: style.warnaTag,
                          coverUrl: buku.coverUrl,
                          nonAktif: buku.akses == 'internal',
                          onTap: () => _openDetail(buku),
                          onReadTap: buku.hasFile
                              ? () => _openBukuAccess(buku, 'read')
                              : () => _openDetail(buku),
                          onDownloadTap: buku.hasFile
                              ? () => _openBukuAccess(buku, 'download')
                              : () => _openDetail(buku),
                        ),
                      );
                    }),
                  if (!_loading && _error == null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _total > 0 ? 'pustaka_showing_books'.trParams({'count': '${_buku.length}', 'total': '$_total'}) : 'pustaka_no_books'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    if (_loadingMore) ...[
                      const SizedBox(height: 10),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_page < _totalPages) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: GestureDetector(
                          onTap: _loadMore,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0)),
                            ),
                            child: Text(
                              'pustaka_load_more'.tr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF065F46),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  _KartuPermintaan(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _DokumenUiStyle _mapBukuStyle(PustakaBuku buku) {
    final String kategori = buku.kategoriNama.toLowerCase();
    if (kategori.contains('fatwa')) {
      return _DokumenUiStyle(
        tag: buku.kategoriNama,
        info: _formatBookInfo(buku),
        icon: Symbols.description,
        warnaIcon: const Color(0xFFE0F2FE),
        warnaTag: const Color(0xFF0EA5E9),
      );
    }
    if (kategori.contains('regulasi')) {
      return _DokumenUiStyle(
        tag: buku.kategoriNama,
        info: _formatBookInfo(buku),
        icon: Symbols.verified_user,
        warnaIcon: const Color(0xFFD1FAE5),
        warnaTag: const Color(0xFF059669),
      );
    }
    return _DokumenUiStyle(
      tag: buku.kategoriNama,
      info: _formatBookInfo(buku),
      icon: (buku.formatFile ?? 'pdf') == 'epub' ? Symbols.auto_stories : Symbols.menu_book,
      warnaIcon: const Color(0xFFFEF3C7),
      warnaTag: const Color(0xFFF59E0B),
    );
  }

  String _formatBookInfo(PustakaBuku buku) {
    final String size = _formatBytes(buku.ukuranFileBytes);
    final String access = buku.akses == 'premium'
        ? 'Premium'
        : buku.akses == 'internal'
            ? 'Internal'
            : 'Gratis';
    if (size.isEmpty) return access;
    return '$size · $access';
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}

class _IconButtonCard extends StatelessWidget {
  const _IconButtonCard({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF64748B)),
      ),
    );
  }
}

class _KategoriPustaka extends StatelessWidget {
  const _KategoriPustaka({
    required this.kategori,
    required this.loading,
    required this.selectedSlug,
    required this.onSelect,
  });

  final List<PustakaKategori> kategori;
  final bool loading;
  final String? selectedSlug;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<_ChipKategori> items = <_ChipKategori>[
      _ChipKategori(
        label: 'pustaka_all'.tr,
        icon: Symbols.grid_view,
        aktif: true,
        onTap: loading ? null : () => onSelect(null),
      ),
      ...kategori.map(
        (k) => _ChipKategori(
          label: k.nama,
          icon: _iconForKategori(k.nama),
          warnaIcon: _colorForKategori(k.nama),
          aktif: selectedSlug == k.slug,
          onTap: loading ? null : () => onSelect(k.slug),
        ),
      ),
    ];
    final List<_ChipKategori> normalized = items
        .asMap()
        .entries
        .map((e) => e.value.copyWith(aktif: e.key == 0 ? selectedSlug == null : e.value.aktif))
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: normalized
            .map(
              (_ChipKategori item) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ChipKategoriWidget(item: item),
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _iconForKategori(String nama) {
    final v = nama.toLowerCase();
    if (v.contains('fatwa')) return Symbols.account_balance;
    if (v.contains('regulasi')) return Symbols.gavel;
    if (v.contains('ebook') || v.contains('e-book') || v.contains('buku')) {
      return Symbols.auto_stories;
    }
    return Symbols.local_library;
  }

  Color _colorForKategori(String nama) {
    final v = nama.toLowerCase();
    if (v.contains('fatwa')) return const Color(0xFFF59E0B);
    if (v.contains('regulasi')) return const Color(0xFF10B981);
    if (v.contains('ebook') || v.contains('e-book') || v.contains('buku')) {
      return const Color(0xFF0EA5E9);
    }
    return const Color(0xFF64748B);
  }
}

class _ChipKategoriWidget extends StatelessWidget {
  const _ChipKategoriWidget({required this.item});

  final _ChipKategori item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: item.aktif ? const Color(0xFF065F46) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: item.aktif
              ? const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x33064E3B),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              item.icon,
              size: 16,
              color: item.aktif ? Colors.white : (item.warnaIcon ?? const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: item.aktif ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerUnggulan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF065F46),
            Color(0xFF059669),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33064E3B),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
            ),
          ),
          Positioned(
            left: -40,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white30),
                ),
                child: Text(
                  'pustaka_featured'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Al-Ahkam Al-Fiqhiyyah Al-Muta‘alliqa bil-‘Umalaat al-Iliktirūniyyah',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kajian fiqih muamalah terkait transaksi elektronik.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  _AksiBanner(
                    label: 'pustaka_read'.tr,
                    icon: Symbols.chrome_reader_mode,
                    warna: Colors.white,
                    warnaText: const Color(0xFF065F46),
                  ),
                  const SizedBox(width: 10),
                  _AksiBanner(
                    label: '',
                    icon: Symbols.download,
                    warna: Colors.white24,
                    warnaText: Colors.white,
                    ukuran: 48,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AksiBanner extends StatelessWidget {
  const _AksiBanner({
    required this.label,
    required this.icon,
    required this.warna,
    required this.warnaText,
    this.ukuran,
  });

  final String label;
  final IconData icon;
  final Color warna;
  final Color warnaText;
  final double? ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 0 : 18, vertical: 12),
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: warna.withValues(alpha: 0.4)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 18, color: warnaText),
          if (label.isNotEmpty) ...<Widget>[
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: warnaText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JudulBagian extends StatelessWidget {
  const _JudulBagian({required this.judul, required this.aksi});

  final String judul;
  final String aksi;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          judul,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
        Text(
          aksi,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }
}

class _KartuDokumen extends StatelessWidget {
  const _KartuDokumen({
    required this.judul,
    required this.tag,
    required this.info,
    required this.icon,
    required this.warnaIcon,
    required this.warnaTag,
    this.coverUrl,
    this.nonAktif = false,
    this.onTap,
    this.onReadTap,
    this.onDownloadTap,
  });

  final String judul;
  final String tag;
  final String info;
  final IconData icon;
  final Color warnaIcon;
  final Color warnaTag;
  final String? coverUrl;
  final bool nonAktif;
  final VoidCallback? onTap;
  final VoidCallback? onReadTap;
  final VoidCallback? onDownloadTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: nonAktif ? 0.6 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _KartuDokumenCover(
                  coverUrl: coverUrl,
                  icon: icon,
                  warnaIcon: warnaIcon,
                  warnaTag: warnaTag,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        judul,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: warnaTag.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: warnaTag,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              info,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (nonAktif)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              'BELUM TERSEDIA',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        )
                      else
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: GestureDetector(
                                onTap: onReadTap ?? onTap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'BACA',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onDownloadTap ?? onTap,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: const Icon(
                                  Symbols.download_rounded,
                                  size: 18,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KartuDokumenCover extends StatelessWidget {
  const _KartuDokumenCover({
    required this.coverUrl,
    required this.icon,
    required this.warnaIcon,
    required this.warnaTag,
  });

  final String? coverUrl;
  final IconData icon;
  final Color warnaIcon;
  final Color warnaTag;

  @override
  Widget build(BuildContext context) {
    final hasCover = (coverUrl ?? '').trim().isNotEmpty;
    return Container(
      width: 96,
      height: 132,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasCover
          ? Image.network(
              coverUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(icon, size: 36, color: warnaTag),
            )
          : Icon(icon, size: 36, color: warnaTag),
    );
  }
}

class _KartuPermintaan extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -6,
            bottom: -6,
            child: Icon(
              Symbols.contact_support,
              size: 80,
              color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Request Dokumen?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF92400E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Belum menemukan fatwa yang Anda cari? Beritahu kami dan tim ahli akan segera mencarikannya untuk Anda.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB45309),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Hubungi Support',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Symbols.arrow_forward,
                      size: 16,
                      color: Color(0xFFB45309),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PustakaDetailPage extends StatefulWidget {
  const _PustakaDetailPage({
    required this.bukuId,
    required this.initialData,
    required this.api,
  });

  final String bukuId;
  final PustakaBuku initialData;
  final PustakaApi api;

  @override
  State<_PustakaDetailPage> createState() => _PustakaDetailPageState();
}

class _PustakaDetailPageState extends State<_PustakaDetailPage> {
  late PustakaBuku _buku = widget.initialData;
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.fetchBukuDetail(widget.bukuId);
      if (!mounted) return;
      setState(() {
        _buku = detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat detail buku';
        _loading = false;
      });
    }
  }

  Future<void> _openAccess(String action) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final access = await widget.api.requestAccessUrl(
        bukuId: widget.bukuId,
        action: action,
      );
      final uri = Uri.tryParse(access.url);
      if (uri == null || access.url.isEmpty) {
        throw Exception('pustaka_invalid_url'.tr);
      }
      final bool isDrive = uri.host.contains('drive.google.com');
      if (action == 'read' && isDrive) {
        final launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak bisa membuka preview Drive')),
          );
        }
        return;
      }
      if (action == 'read' && (_buku.formatFile ?? 'pdf').toLowerCase() == 'pdf') {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _PdfReaderPage(
              title: _buku.judul,
              pdfUrl: access.url,
            ),
          ),
        );
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak bisa membuka file buku')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka akses buku')),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  String _aksesLabel(String akses) {
    switch (akses) {
      case 'premium':
        return 'Premium';
      case 'internal':
        return 'Internal';
      default:
        return 'Gratis';
    }
  }

  String _formatLabel(String? formatFile) {
    if ((formatFile ?? '').isEmpty) return '-';
    return (formatFile ?? '').toUpperCase();
  }

  String _ukuranLabel(int? bytes) {
    if (bytes == null || bytes <= 0) return '-';
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFCF8),
        elevation: 0,
        title: Text(
          'Detail Buku',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1F2937),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: _PustakaError(
                    message: _error!,
                    onRetry: _loadDetail,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if ((_buku.coverUrl ?? '').isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                _buku.coverUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _DetailCoverFallback(
                                  judul: _buku.judul,
                                ),
                              ),
                            )
                          else
                            _DetailCoverFallback(judul: _buku.judul),
                          const SizedBox(height: 14),
                          Text(
                            _buku.judul,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _buku.penulis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _DetailPill(_buku.kategoriNama),
                              _DetailPill(_aksesLabel(_buku.akses)),
                              _DetailPill(_formatLabel(_buku.formatFile)),
                              _DetailPill(_ukuranLabel(_buku.ukuranFileBytes)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _buku.deskripsi.isEmpty
                                ? 'Deskripsi belum tersedia.'
                                : _buku.deskripsi,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                              color: const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_opening || !_buku.hasFile)
                                ? null
                                : () => _openAccess('read'),
                            icon: const Icon(Symbols.chrome_reader_mode, size: 18),
                            label: Text(
                              _opening ? 'Memuat...' : 'pustaka_read'.tr,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF065F46),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (_opening || !_buku.hasFile)
                                ? null
                                : () => _openAccess('download'),
                            icon: const Icon(Symbols.download_rounded, size: 18),
                            label: Text(
                              'Download',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!_buku.hasFile) ...[
                      const SizedBox(height: 10),
                      Text(
                        'File ebook belum tersedia untuk buku ini.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _PdfReaderPage extends StatefulWidget {
  const _PdfReaderPage({
    required this.title,
    required this.pdfUrl,
  });

  final String title;
  final String pdfUrl;

  @override
  State<_PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<_PdfReaderPage> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;
  int _pageNumber = 1;
  int _pageCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPdf();
  }

  Future<void> _fetchPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Dio dio = Dio();
      final response = await dio.get<List<int>>(
        widget.pdfUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('File PDF kosong');
      }
      if (!mounted) return;
      setState(() {
        _pdfBytes = Uint8List.fromList(bytes);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      // Fallback for local dev servers that may close streamed responses early.
      final uri = Uri.tryParse(widget.pdfUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFCF8),
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: <Widget>[
          if (_pdfBytes != null)
            SfPdfViewer.memory(
              _pdfBytes!,
              controller: _pdfController,
              onPageChanged: (PdfPageChangedDetails details) {
                if (!mounted) return;
                setState(() => _pageNumber = details.newPageNumber);
              },
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                if (!mounted) return;
                setState(() => _pageCount = details.document.pages.count);
              },
              onDocumentLoadFailed: (details) {
                if (!mounted) return;
                setState(() {
                  _error = details.error;
                });
              },
            ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.picture_as_pdf_outlined, size: 40),
                    const SizedBox(height: 10),
                    Text(
                      'Gagal memuat PDF',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error == null)
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _PdfNavBtn(
                    icon: Icons.chevron_left,
                    onTap: _pageNumber > 1
                        ? () => _pdfController.previousPage()
                        : null,
                  ),
                  const SizedBox(width: 8),
                  _PdfNavBtn(
                    icon: Icons.chevron_right,
                    onTap: (_pageCount > 0 && _pageNumber < _pageCount)
                        ? () => _pdfController.nextPage()
                        : null,
                  ),
                ],
              ),
            ),
          if (_error == null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Halaman $_pageNumber${_pageCount > 0 ? ' / $_pageCount' : ''}',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PdfNavBtn extends StatelessWidget {
  const _PdfNavBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: onTap == null ? 0.25 : 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _DetailCoverFallback extends StatelessWidget {
  const _DetailCoverFallback({required this.judul});

  final String judul;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF065F46), Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          judul,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill(this.text);

  final String text;

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
        text,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }
}

class _ChipKategori {
  const _ChipKategori({
    required this.label,
    required this.icon,
    this.warnaIcon,
    this.aktif = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color? warnaIcon;
  final bool aktif;
  final VoidCallback? onTap;

  _ChipKategori copyWith({
    String? label,
    IconData? icon,
    Color? warnaIcon,
    bool? aktif,
    VoidCallback? onTap,
  }) {
    return _ChipKategori(
      label: label ?? this.label,
      icon: icon ?? this.icon,
      warnaIcon: warnaIcon ?? this.warnaIcon,
      aktif: aktif ?? this.aktif,
      onTap: onTap ?? this.onTap,
    );
  }
}

class _DokumenUiStyle {
  const _DokumenUiStyle({
    required this.tag,
    required this.info,
    required this.icon,
    required this.warnaIcon,
    required this.warnaTag,
  });

  final String tag;
  final String info;
  final IconData icon;
  final Color warnaIcon;
  final Color warnaTag;
}

class _PustakaLoadingList extends StatelessWidget {
  const _PustakaLoadingList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List<Widget>.generate(
        3,
        (int i) => Padding(
          padding: EdgeInsets.only(bottom: i == 2 ? 0 : 16),
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ),
    );
  }
}

class _PustakaEmpty extends StatelessWidget {
  const _PustakaEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Text(
        'Belum ada buku yang dipublikasikan.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
        ),
      ),
    );
  }
}

class _PustakaError extends StatelessWidget {
  const _PustakaError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onRetry(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Coba Lagi',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF065F46),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
