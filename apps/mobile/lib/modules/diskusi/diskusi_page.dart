import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../app/services/auth_service.dart';
import 'diskusi_api.dart';

class HalamanDiskusi extends StatefulWidget {
  const HalamanDiskusi({super.key});

  @override
  State<HalamanDiskusi> createState() => _HalamanDiskusiState();
}

class _HalamanDiskusiState extends State<HalamanDiskusi> {
  final DiskusiApi _api = DiskusiApi();
  final TextEditingController _searchC = TextEditingController();
  final ScrollController _scrollC = ScrollController();

  final List<DiskusiItem> _items = <DiskusiItem>[];
  Timer? _debounce;
  bool _loading = false;
  bool _loadingMore = false;
  int _page = 1;
  int _totalPages = 1;
  String _sort = 'terbaru';
  String _kanal = 'umum';

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scrollC.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollC.position.pixels >= _scrollC.position.maxScrollExtent - 120) {
      _fetchMore();
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (_kanal == 'vip') return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await _api.fetchThreads(
        page: reset ? 1 : _page,
        perPage: 20,
        query: _searchC.text,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchMore() async {
    if (_kanal == 'vip') return;
    if (_loadingMore || _loading || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await _api.fetchThreads(
        page: nextPage,
        perPage: 20,
        query: _searchC.text,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    if (_kanal == 'vip') return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetch(reset: true);
    });
  }

  Future<void> _openCreateSheet() async {
    if (_kanal == 'vip' && !_isVipMember) {
      _showVipUpsell();
      return;
    }
    if (_kanal == 'vip' && _isVipMember) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('diskusi_vip_post_unavailable'.tr)),
      );
      return;
    }
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x66000000),
      builder: (context) => _CreateThreadSheet(api: _api),
    );
    if (created == true) {
      await _fetch(reset: true);
    }
  }

  bool get _isVipMember {
    final role = AuthService.instance.role ?? '';
    return role == 'vip' || role == 'admin';
  }

  void _showVipUpsell() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                const Icon(Symbols.verified, color: Color(0xFFF59E0B), size: 32),
                const SizedBox(width: 12),
                Text(
                  'diskusi_vip_exclusive'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'diskusi_vip_upsell_desc'.tr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF475569),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'diskusi_monthly_sub'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rp 150.000',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDE68A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'diskusi_best_value'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('diskusi_open_pg'.tr),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'diskusi_pay_now'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'diskusi_maybe_later'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F8),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollC,
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: const Color(0xFFF6F8F8).withValues(alpha: 0.92),
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 0,
                toolbarHeight: 74,
                title: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (canPop)
                            _IconCircleButton(
                              icon: Symbols.arrow_back,
                              onTap: () => Navigator.of(context).maybePop(),
                            )
                          else
                            const SizedBox(width: 40, height: 40),
                          const SizedBox(width: 10),
                          Text(
                            'diskusi_title'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D3D33),
                            ),
                          ),
                        ],
                      ),
                      const _IconCircleButton(icon: Symbols.notifications),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(146),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchC,
                          onChanged: _onSearchChanged,
                          decoration: InputDecoration(
                            hintText: 'diskusi_search_hint'.tr,
                            prefixIcon: const Icon(Symbols.search, size: 20),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _SwitchFilter(
                          selected: _sort,
                          onChanged: (value) {
                            if (_kanal == 'vip') return;
                            if (_sort == value) return;
                            setState(() => _sort = value);
                            _fetch(reset: true);
                          },
                        ),
                        const SizedBox(height: 10),
                        _SwitchKanal(
                          selected: _kanal,
                          onChanged: (String value) {
                            if (_kanal == value) return;
                            setState(() => _kanal = value);
                            if (value == 'umum') {
                              _fetch(reset: true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
                  child: _kanal == 'vip'
                      ? _VipRoomBody(
                          isVipMember: _isVipMember,
                          onUpgradeTap: _showVipUpsell,
                        )
                      : RefreshIndicator(
                          onRefresh: () => _fetch(reset: true),
                          child: _items.isEmpty && _loading
                              ? const SizedBox(
                                  height: 320,
                                  child: Center(child: CircularProgressIndicator()),
                                )
                              : _items.isEmpty
                                  ? SizedBox(
                                      height: 320,
                                      child: Center(
                                        child: Text(
                                          'diskusi_no_threads'.tr,
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        ..._items.map(
                                          (item) => Padding(
                                            padding: const EdgeInsets.only(bottom: 14),
                                            child: _ThreadCard(
                                              item: item,
                                              onTap: () async {
                                                await Navigator.of(context).push(
                                                  MaterialPageRoute<void>(
                                                    builder: (_) => _DetailThreadPage(threadId: item.id),
                                                  ),
                                                );
                                                await _fetch(reset: true);
                                              },
                                            ),
                                          ),
                                        ),
                                        if (_loadingMore)
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: CircularProgressIndicator(),
                                          ),
                                      ],
                                    ),
                        ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 72,
            child: IgnorePointer(
              ignoring: _kanal == 'vip' && !_isVipMember,
              child: Opacity(
                opacity: _kanal == 'vip' && !_isVipMember ? 0.45 : 1,
                child: GestureDetector(
                  onTap: _openCreateSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13ECB9),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x4D13ECB9),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Symbols.add_comment, size: 20, color: Color(0xFF0D3D33)),
                        const SizedBox(width: 8),
                        Text(
                          _kanal == 'vip' ? 'diskusi_create_vip'.tr : 'diskusi_create_general'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0D3D33),
                          ),
                        ),
                      ],
                    ),
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

class _SwitchKanal extends StatelessWidget {
  const _SwitchKanal({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool umum = selected == 'umum';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged('umum'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: umum ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'diskusi_general'.tr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: umum ? const Color(0xFF0D3D33) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged('vip'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: umum ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Symbols.lock, size: 14, color: Color(0xFF0D3D33)),
                    const SizedBox(width: 4),
                    Text(
                      'diskusi_vip'.tr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: umum ? const Color(0xFF9CA3AF) : const Color(0xFF0D3D33),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VipRoomBody extends StatelessWidget {
  const _VipRoomBody({
    required this.isVipMember,
    required this.onUpgradeTap,
  });

  final bool isVipMember;
  final VoidCallback onUpgradeTap;

  @override
  Widget build(BuildContext context) {
    if (!isVipMember) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'diskusi_vip_paid'.tr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF92400E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'diskusi_vip_paid_desc'.tr,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFB45309),
              ),
            ),
            const SizedBox(height: 12),
            const _UstadzWatchList(),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onUpgradeTap,
              child: Text('diskusi_upgrade_vip'.tr),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD1FAE5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'diskusi_vip_active'.tr,
                style: TextStyle(
                  color: Color(0xFF065F46),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'diskusi_vip_active_desc'.tr,
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _UstadzWatchList(),
        const SizedBox(height: 12),
        ..._vipThreads.map(
          (DiskusiItem item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ThreadCard(
              item: item,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('diskusi_vip_thread_backend'.tr)),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UstadzWatchList extends StatelessWidget {
  const _UstadzWatchList();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _UstadzChip(name: 'Ustad Devin Halim Wijaya'),
        _UstadzChip(name: 'Ustad Fida Munadzir'),
        _UstadzChip(name: 'Ustad Ade Setiawan'),
      ],
    );
  }
}

class _UstadzChip extends StatelessWidget {
  const _UstadzChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Text(
        name,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF065F46),
        ),
      ),
    );
  }
}

final List<DiskusiItem> _vipThreads = <DiskusiItem>[
  DiskusiItem(
    id: '9001',
    userId: '100',
    parentId: null,
    judul: 'Strategi Menjaga Disiplin Trading Syariah',
    isi: 'Bagaimana cara jaga emosi saat market volatile tanpa melanggar prinsip syariah?',
    createdAt: DateTime.now(),
    namaUser: 'Member VIP',
    replyCount: 18,
  ),
  DiskusiItem(
    id: '9002',
    userId: '101',
    parentId: null,
    judul: 'Q&A Live Pekanan bersama Ustadz Pembimbing',
    isi: 'Thread ini khusus kumpulan pertanyaan untuk sesi live Jumat malam.',
    createdAt: DateTime.now(),
    namaUser: 'Moderator VIP',
    replyCount: 42,
  ),
];

class _ThreadCard extends StatelessWidget {
  const _ThreadCard({required this.item, required this.onTap});

  final DiskusiItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initial(item.namaUser),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0D9488),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.namaUser,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0D3D33),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _timeAgo(item.createdAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.judul,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.isi,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Symbols.chat_bubble, size: 18, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Text(
                      '${item.replyCount} komentar',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Lihat thread',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D9488),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return 'Baru saja';
    final now = DateTime.now().toUtc();
    final target = dt.toUtc();
    final d = now.difference(target);
    if (d.inMinutes < 1) return 'Baru saja';
    if (d.inHours < 1) return '${d.inMinutes} menit lalu';
    if (d.inDays < 1) return '${d.inHours} jam lalu';
    return '${d.inDays} hari lalu';
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
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF0D3D33)),
      ),
    );
  }
}

class _SwitchFilter extends StatelessWidget {
  const _SwitchFilter({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final terbaru = selected == 'terbaru';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged('terbaru'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: terbaru ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Terbaru',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: terbaru ? const Color(0xFF0D3D33) : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged('terpopuler'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: terbaru ? Colors.transparent : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Terpopuler',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: terbaru ? const Color(0xFF9CA3AF) : const Color(0xFF0D3D33),
                    ),
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

class _CreateThreadSheet extends StatefulWidget {
  const _CreateThreadSheet({required this.api});

  final DiskusiApi api;

  @override
  State<_CreateThreadSheet> createState() => _CreateThreadSheetState();
}

class _CreateThreadSheetState extends State<_CreateThreadSheet> {
  final TextEditingController _titleC = TextEditingController();
  final TextEditingController _bodyC = TextEditingController();
  final TextEditingController _attachmentC = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleC.dispose();
    _bodyC.dispose();
    _attachmentC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleC.text.trim();
    final body = _bodyC.text.trim();
    final attachmentUrl = _attachmentC.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Judul dan isi wajib diisi')));
      return;
    }
    setState(() => _saving = true);
    try {
      final composedBody = attachmentUrl.isEmpty ? body : '$body\n\nLampiran: $attachmentUrl';
      await widget.api.createThread(
        judul: title,
        isi: composedBody,
        lampiranUrl: attachmentUrl,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = _errorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorMessage(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      if (status == 404) {
        return 'Endpoint diskusi tidak ditemukan. Cek API_BASE_URL dan restart backend.';
      }
      if (status == 401) {
        return 'Sesi login habis. Silakan login ulang.';
      }
      if (status == 400) {
        return 'Data diskusi belum valid. Cek judul/isi.';
      }
    }
    return 'Gagal kirim thread.';
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.55,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        margin: EdgeInsets.only(top: 12 + MediaQuery.of(context).padding.top),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buat Diskusi Baru',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D3D33),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Symbols.close),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  const _FieldLabel(label: 'Judul Diskusi'),
                  const SizedBox(height: 6),
                  _PrettyInputField(
                    controller: _titleC,
                    hint: 'Contoh: Status halal koin Layer 1',
                    minLines: 1,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Isi Diskusi'),
                  const SizedBox(height: 6),
                  _PrettyInputField(
                    controller: _bodyC,
                    hint: 'Tulis pendapat atau pertanyaan kamu...',
                    minLines: 4,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel(label: 'Lampiran (opsional)'),
                  const SizedBox(height: 6),
                  _AttachmentInputCard(controller: _attachmentC),
                  const SizedBox(height: 16),
                  const _DisclaimerCard(),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13ECB9),
                        foregroundColor: const Color(0xFF0D3D33),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saving ? null : _submit,
                      child: Text(
                        _saving ? 'Menyimpan...' : 'Publikasikan',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF0D3D33),
      ),
    );
  }
}

class _PrettyInputField extends StatelessWidget {
  const _PrettyInputField({
    required this.controller,
    required this.hint,
    this.minLines,
    this.maxLines,
  });

  final TextEditingController controller;
  final String hint;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines ?? minLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _AttachmentInputCard extends StatelessWidget {
  const _AttachmentInputCard({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Symbols.attach_file, size: 18, color: Color(0xFF10B981)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Tempel URL gambar/dokumen',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Symbols.info, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pastikan diskusi beradab, tidak mengandung ajakan spekulasi, dan tidak memberikan fatwa.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailThreadPage extends StatefulWidget {
  const _DetailThreadPage({required this.threadId});

  final String threadId;

  @override
  State<_DetailThreadPage> createState() => _DetailThreadPageState();
}

class _DetailThreadPageState extends State<_DetailThreadPage> {
  final DiskusiApi _api = DiskusiApi();
  final TextEditingController _replyC = TextEditingController();
  DiskusiDetail? _detail;
  bool _loading = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _replyC.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final detail = await _api.fetchThreadDetail(widget.threadId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final isi = _replyC.text.trim();
    if (isi.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.replyThread(threadId: widget.threadId, isi: isi);
      _replyC.clear();
      await _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal kirim balasan: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: const Text('Thread Diskusi')),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Center(child: Text('Thread tidak ditemukan'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _ThreadCard(item: d.thread, onTap: () {}),
                          const SizedBox(height: 14),
                          Text(
                            'Balasan (${d.replies.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (d.replies.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Belum ada balasan'),
                            ),
                          ...d.replies.map(
                            (e) => Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.namaUser,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0D9488),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    e.isi,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: const Color(0xFF334155),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyC,
                                decoration: const InputDecoration(
                                  hintText: 'Tulis balasan...',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _sending ? null : _sendReply,
                              icon: Icon(_sending ? Symbols.sync : Symbols.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
