import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';

// ─────────────────────────────────────────────────────────────────────
// Kalam Reels — Simpel + Bagikan Gambar ke Sosmed
// ─────────────────────────────────────────────────────────────────────

// Pilihan warna gradient untuk share card
const List<List<Color>> _shareThemes = <List<Color>>[
  <Color>[Color(0xFF0D7377), Color(0xFF14BDAC)], // Teal
  <Color>[Color(0xFFE91E63), Color(0xFFFF5252)], // Pink-Red
  <Color>[Color(0xFF1A237E), Color(0xFF283593)], // Navy
  <Color>[Color(0xFF66BB6A), Color(0xFFAED581)], // Lime-Green
  <Color>[Color(0xFF212121), Color(0xFF424242)], // Dark
];

class HalamanReels extends StatefulWidget {
  const HalamanReels({super.key});

  @override
  State<HalamanReels> createState() => _HalamanReelsState();
}

class _HalamanReelsState extends State<HalamanReels>
    with WidgetsBindingObserver {
  final Dio _dio = ApiDio.create();
  final PageController _pageController = PageController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<_ReelItem> _items = <_ReelItem>[];
  bool _isLoading = true;
  int _currentPage = 0;
  bool _isPlaying = false;
  int _audioLoadTicket = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReels();

    _audioPlayer.playerStateStream.listen((PlayerState state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _audioPlayer.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─── Load Data ─────────────────────────────────────────────────────

  Future<void> _loadReels() async {
    setState(() => _isLoading = true);
    try {
      final response = await _dio.get<dynamic>(
        '${AppConfig.apiBaseUrl}/api/reels',
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      final List<dynamic> rows = _extractList(response.data);
      final List<_ReelItem> parsed = rows
          .whereType<Map<dynamic, dynamic>>()
          .map((Map<dynamic, dynamic> r) =>
              _ReelItem.fromJson(Map<String, dynamic>.from(r)))
          .toList();
      if (!mounted) return;
      setState(() {
        _items = parsed.isNotEmpty ? parsed : List<_ReelItem>.from(_fallback);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _items = List<_ReelItem>.from(_fallback);
        _isLoading = false;
      });
    }
    if (_items.isNotEmpty) _autoPlay(0);
  }

  List<dynamic> _extractList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final dynamic d = raw['data'];
      if (d is List<dynamic>) return d;
    }
    return <dynamic>[];
  }

  // ─── Audio ─────────────────────────────────────────────────────────

  Future<void> _autoPlay(int index) async {
    if (index < 0 || index >= _items.length) return;
    final int ticket = ++_audioLoadTicket;
    final String url = _items[index].audioUrl;
    if (url.isEmpty) {
      await _audioPlayer.stop();
      if (ticket != _audioLoadTicket) return;
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    try {
      await _audioPlayer.stop();
      if (ticket != _audioLoadTicket) return;
      await _audioPlayer.setUrl(url);
      if (ticket != _audioLoadTicket) return;
      await _audioPlayer.play();
      if (ticket != _audioLoadTicket) return;
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  void _toggleAudio() {
    if (_items.isEmpty) return;
    final String url = _items[_currentPage].audioUrl;
    if (url.isEmpty) return;
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _autoPlay(page);
  }

  // ─── Bagikan Gambar (Bottom Sheet) ─────────────────────────────────

  void _showShareSheet(_ReelItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return _ShareSheet(item: item);
      },
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  List<Color> _gradientFor(String kategori) {
    final String k = kategori.toLowerCase();
    if (k.contains('sabar')) {
      return const <Color>[Color(0xFF1B6B93), Color(0xFF4FC0D0)];
    }
    if (k.contains('tawakal')) {
      return const <Color>[Color(0xFF3A1078), Color(0xFF6C63FF)];
    }
    if (k.contains('qana') || k.contains('syukur')) {
      return const <Color>[Color(0xFF2E4057), Color(0xFF048A81)];
    }
    if (k.contains('tawadhu') || k.contains('ihsan')) {
      return const <Color>[Color(0xFF5C2D91), Color(0xFF9B59B6)];
    }
    if (k.contains('zakat')) {
      return const <Color>[Color(0xFF1A5653), Color(0xFF2ECC71)];
    }
    return const <Color>[Color(0xFF0D7377), Color(0xFF14BDAC)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0xFF0D7377), Color(0xFF14BDAC)],
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          : Stack(
              children: <Widget>[
                PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: _items.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (BuildContext context, int index) {
                    return _buildReelPage(_items[index], index);
                  },
                ),
                // Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Symbols.play_circle_rounded,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'reels_title'.tr,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _loadReels,
                            child: Icon(Symbols.refresh,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 22),
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

  Widget _buildReelPage(_ReelItem item, int index) {
    final List<Color> gradient = _gradientFor(item.kategori);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient,
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: <Widget>[
            // Konten utama
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 70, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // Badge sumber
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.sumber,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Ayat Arab
                    Text(
                      item.kutipanArab,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.notoNaskhArabic(
                        fontSize: 28,
                        height: 1.8,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Terjemah
                    Text(
                      '"${item.terjemah}"',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Side buttons
            Positioned(
              right: 14,
              bottom: 20,
              child: Column(
                children: <Widget>[
                  _SideButton(
                    icon: _isPlaying ? Symbols.volume_up : Symbols.volume_off,
                    label: _isPlaying ? 'reels_on'.tr : 'reels_off'.tr,
                    onTap: _toggleAudio,
                  ),
                  const SizedBox(height: 20),
                  _SideButton(
                    icon: Symbols.share,
                    label: 'reels_share'.tr,
                    onTap: () => _showShareSheet(item),
                  ),
                  const SizedBox(height: 20),
                  _SideButton(
                    icon: Symbols.bookmark_border,
                    label: 'reels_save'.tr,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('reels_saved_to_col'.tr),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
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

// ─────────────────────────────────────────────────────────────────────
// Bottom Sheet — Bagikan Ayat sebagai Gambar
// ─────────────────────────────────────────────────────────────────────

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.item});
  final _ReelItem item;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  int _selectedTheme = 0;
  bool _isSharing = false;

  Future<void> _shareAsImage() async {
    setState(() => _isSharing = true);
    try {
      // Capture widget as image
      final RenderRepaintBoundary boundary =
          _cardKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to temp
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath =
          '${tempDir.path}/averroes_kalam_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // Share
      final String caption = '${widget.item.sumber}\n\n'
          '"${widget.item.terjemah}"\n\n'
          '─────────────────\n'
          '📱 Dibagikan dari Averroes — Aplikasi Kajian Aset Kripto Syariah\n'
          '🌐 Download di: averroes.com';

      await Share.shareXFiles(
        <XFile>[XFile(filePath)],
        text: caption,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('reels_share_failed'.trParams({'error': '$e'}))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'reels_share_verse'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Icon(Icons.close, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Preview Card ──────────────────────────────
          RepaintBoundary(
            key: _cardKey,
            child: _ShareCard(
              item: widget.item,
              gradient: _shareThemes[_selectedTheme],
            ),
          ),

          const SizedBox(height: 16),

          // ─── Color Picker ──────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _shareThemes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final bool selected = _selectedTheme == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTheme = index),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: _shareThemes[index],
                      ),
                      border: selected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                      boxShadow: selected
                          ? <BoxShadow>[
                              BoxShadow(
                                color: _shareThemes[index][0]
                                    .withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check, color: Colors.white, size: 22)
                        : null,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ─── Tombol Bagikan Gambar ─────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareAsImage,
              style: ElevatedButton.styleFrom(
                backgroundColor: _shareThemes[_selectedTheme][0],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.share, size: 20),
              label: Text(
                _isSharing ? 'reels_process_share'.tr : 'reels_share_image'.tr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Share Card — Preview gambar yang akan dibagikan
// ─────────────────────────────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.item, required this.gradient});
  final _ReelItem item;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Branding Averroes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(Symbols.mosque,
                  color: Colors.white.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 6),
              Text(
                'Averroes App',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Ayat Arab
          Text(
            item.kutipanArab,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: GoogleFonts.notoNaskhArabic(
              fontSize: 24,
              height: 1.8,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // Terjemah
          Text(
            '"${item.terjemah}"',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.6,
              fontStyle: FontStyle.italic,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),

          const SizedBox(height: 20),

          // Badge sumber
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.sumber,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Link promo
          Text(
            'Download di averroes.com',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Side Button
// ─────────────────────────────────────────────────────────────────────

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Data Model
// ─────────────────────────────────────────────────────────────────────

class _ReelItem {
  const _ReelItem({
    required this.id,
    required this.kategori,
    required this.judul,
    required this.kutipanArab,
    required this.terjemah,
    required this.sumber,
    this.audioUrl = '',
  });

  final String id;
  final String kategori;
  final String judul;
  final String kutipanArab;
  final String terjemah;
  final String sumber;
  final String audioUrl;

  factory _ReelItem.fromJson(Map<String, dynamic> json) {
    return _ReelItem(
      id: (json['id'] ?? '').toString(),
      kategori: (json['kategori'] as String?)?.trim() ?? '',
      judul: (json['judul'] as String?)?.trim() ?? '-',
      kutipanArab: (json['kutipan_arab'] as String?)?.trim() ?? '',
      terjemah: (json['terjemah'] as String?)?.trim() ?? '',
      sumber: (json['sumber'] as String?)?.trim() ?? '',
      audioUrl: (json['audio_url'] as String?)?.trim() ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Fallback
// ─────────────────────────────────────────────────────────────────────

const List<_ReelItem> _fallback = <_ReelItem>[
  _ReelItem(
    id: 'fb-1',
    kategori: 'Fiqh Muamalah',
    judul: 'Al-Baqarah : 275',
    kutipanArab: 'وَأَحَلَّ اللَّهُ الْبَيْعَ وَحَرَّمَ الرِّبَا',
    terjemah: 'Dan Allah telah menghalalkan jual beli dan mengharamkan riba.',
    sumber: 'QS. Al-Baqarah : 275',
    audioUrl: 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/282.mp3',
  ),
  _ReelItem(
    id: 'fb-2',
    kategori: 'Sabar',
    judul: 'Al-Baqarah : 153',
    kutipanArab:
        'يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    terjemah:
        'Wahai orang-orang beriman, mohonlah pertolongan dengan sabar dan shalat. Sungguh, Allah bersama orang-orang yang sabar.',
    sumber: 'QS. Al-Baqarah : 153',
    audioUrl: 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/160.mp3',
  ),
  _ReelItem(
    id: 'fb-3',
    kategori: 'Tawakal',
    judul: 'At-Talaq : 3',
    kutipanArab: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    terjemah:
        'Dan barangsiapa bertawakal kepada Allah, niscaya Allah akan mencukupkan keperluannya.',
    sumber: 'QS. At-Talaq : 3',
    audioUrl: 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/5220.mp3',
  ),
];
