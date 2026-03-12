import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../presentation/common/content_ui.dart';
import 'edukasi_api.dart';
import 'kelas_detail_page.dart';

class HalamanEdukasi extends StatefulWidget {
  const HalamanEdukasi({super.key});

  @override
  State<HalamanEdukasi> createState() => _HalamanEdukasiState();
}

class _HalamanEdukasiState extends State<HalamanEdukasi> {
  final EdukasiApi _api = EdukasiApi();

  final TextEditingController _searchController = TextEditingController();
  List<KelasEdukasi> _kelas = <KelasEdukasi>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadKelas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadKelas() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<KelasEdukasi> items = await _api.fetchKelas();
      setState(() {
        _kelas = items;
      });
    } catch (_) {
      setState(() {
        _error = 'edu_load_error'.tr;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<KelasEdukasi> filtered = _kelas
        .where(
          (KelasEdukasi item) =>
              item.judul.toLowerCase().contains(query) ||
              item.deskripsi.toLowerCase().contains(query),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF8FAFC).withValues(alpha: 0.96),
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            toolbarHeight: 72,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'edu_title'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'edu_subtitle'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _IconCircleButton(
                    icon: Symbols.refresh,
                    onTap: _isLoading ? null : _loadKelas,
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _SearchBox(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  AppSectionHeader(
                    title: 'edu_recommended'.tr,
                    actionText: 'edu_classes_count'.trParams(
                      <String, String>{'count': '${filtered.length}'},
                    ),
                    leadingIcon: Symbols.auto_awesome,
                  ),
                  const SizedBox(height: 12),
                  _RekomendasiCarousel(
                    items: filtered.take(3).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'edu_all_classes'.tr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    AppErrorStateCard(
                      message: _error!,
                      onRetry: () => _loadKelas(),
                    )
                  else if (filtered.isEmpty)
                    AppEmptyStateCard(
                      text: 'edu_class_not_found'.tr,
                      icon: Symbols.search_off,
                    )
                  else
                    ...filtered
                        .map((KelasEdukasi item) => _KelasCard(item: item)),
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
  const _IconCircleButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 18, color: AppColors.slate),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      onChanged: onChanged,
      hint: 'edu_search_hint'.tr,
      prefixIcon: const Icon(
        Symbols.search,
        size: 20,
        color: AppColors.muted,
      ),
    );
  }
}

class _RekomendasiCarousel extends StatelessWidget {
  const _RekomendasiCarousel({required this.items});

  final List<KelasEdukasi> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppEmptyStateCard(
        text: 'edu_empty_recommendation'.tr,
        icon: Symbols.menu_book,
      );
    }

    return SizedBox(
      height: 276,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final KelasEdukasi item = items[index];
          return _KelasRekomendasiCard(item: item);
        },
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemCount: items.length,
      ),
    );
  }
}

class _KelasRekomendasiCard extends StatelessWidget {
  const _KelasRekomendasiCard({required this.item});

  final KelasEdukasi item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: CustomCard(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => HalamanDetailKelas(kelas: item),
            ),
          );
        },
        padding: EdgeInsets.zero,
        hasShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _KelasCover(item: item, width: 270, height: 112, borderRadius: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'edu_recommended'.tr.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.judul,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.deskripsi,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        const Icon(Symbols.play_circle,
                            size: 18, color: AppColors.emerald),
                        const SizedBox(width: 6),
                        Text(
                          'edu_view_material'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emeraldDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KelasCard extends StatelessWidget {
  const _KelasCard({required this.item});

  final KelasEdukasi item;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HalamanDetailKelas(kelas: item),
          ),
        );
      },
      padding: const EdgeInsets.all(16),
      hasShadow: false,
      child: Row(
        children: <Widget>[
          _KelasCover(item: item, width: 64, height: 64, borderRadius: 12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.judul,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.deskripsi,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Symbols.chevron_right,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _KelasCover extends StatelessWidget {
  const _KelasCover({
    required this.item,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final KelasEdukasi item;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final String assetImage = _resolveKelasAsset(item);
    final String? networkUrl = item.gambarUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: (networkUrl != null && networkUrl.isNotEmpty)
          ? Image.network(
              networkUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                assetImage,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            )
          : Image.asset(
              assetImage,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: width,
                height: height,
                color: const Color(0xFFDCF4EE),
                alignment: Alignment.center,
                child: const Icon(Symbols.menu_book,
                    color: AppColors.emerald, size: 26),
              ),
            ),
    );
  }
}

String _resolveKelasAsset(KelasEdukasi item) {
  final String haystack = '${item.judul} ${item.deskripsi}'.toLowerCase();
  if (haystack.contains('zakat')) {
    return 'assets/images/kelas/zakat_1.jpg';
  }
  if (haystack.contains('blockchain')) {
    return 'assets/images/kelas/blockchain_1.jpg';
  }
  if (haystack.contains('kripto') || haystack.contains('crypto')) {
    if (haystack.contains('fundamental') ||
        haystack.contains('muamalah') ||
        haystack.contains('syariah')) {
      return 'assets/images/kelas/crypto_syariah_1.jpg';
    }
    return 'assets/images/kelas/crypto_chart_1.jpg';
  }
  if (haystack.contains('fiqh') ||
      haystack.contains('muamalah') ||
      haystack.contains('syariah')) {
    return 'assets/images/kelas/finance_halal_1.jpg';
  }
  if (haystack.contains('investasi') ||
      haystack.contains('pasar') ||
      haystack.contains('portofolio')) {
    return 'assets/images/kelas/finance_halal_1.jpg';
  }
  return 'assets/images/kelas/education_1.jpg';
}
