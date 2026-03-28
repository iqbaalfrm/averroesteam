import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/services/api_dio.dart';

class HalamanZikir extends StatefulWidget {
  const HalamanZikir({super.key});

  @override
  State<HalamanZikir> createState() => _HalamanZikirState();
}

class _HalamanZikirState extends State<HalamanZikir> {
  static const String _bootstrapVideoId = '_j1GfNyYRJM';
  static const List<_KajianVideo> _fallbackVideos = <_KajianVideo>[
    _KajianVideo(
      id: 'ciamJjQ2ruU',
      title:
          'BITCOIN DIHARAMKAN? Ustadz Devin: Banyak yang Salah Paham, Ini Alasan Crypto Tidak Haram dalam Islam',
      channel: 'kasisolusi',
      duration: 'Kajian',
      category: 'Kajian Crypto Syariah',
      description:
          'Pembahasan awal tentang miskonsepsi hukum Bitcoin dan aset kripto dalam perspektif syariah.',
    ),
    _KajianVideo(
      id: 'rU56XmYmKcg',
      title: 'Bitcoin Zero Sum Game Jadi Haram?',
      channel: 'Mudacumasekali',
      duration: 'Kajian',
      category: 'Kajian Crypto Syariah',
      description:
          'Pembahasan singkat tentang isu zero sum game dan bagaimana memahami posisi Bitcoin secara lebih hati-hati.',
    ),
    _KajianVideo(
      id: 'P4R19e7bowg',
      title: 'Bedah Halal Haram Crypto Aset bersama Ustadz Devin Halim Wijaya',
      channel: 'Wakaf Ilmu',
      duration: 'Kajian',
      category: 'Kajian Crypto Syariah',
      description:
          'Kajian pengantar mengenai halal-haram crypto aset untuk referensi awal pengguna Averroes.',
    ),
  ];

  List<_KajianVideo> _videos = <_KajianVideo>[];
  _KajianVideo? _selectedVideo;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKajian();
  }

  Future<void> _loadKajian() async {
    setState(() {
      _loading = true;
    });

    try {
      final dio = ApiDio.create(attachAuthToken: false);
      final response = await dio.get<dynamic>('/api/kajian');
      final dynamic raw = response.data;

      final List<_KajianVideo> loadedVideos = <_KajianVideo>[];
      if (raw is Map<String, dynamic>) {
        final dynamic data = raw['data'];
        if (data is List) {
          for (final dynamic item in data) {
            if (item is Map) {
              final _KajianVideo? parsed =
                  _KajianVideo.fromApi(Map<String, dynamic>.from(item));
              if (parsed != null) {
                loadedVideos.add(parsed);
              }
            }
          }
        }
      }

      if (!mounted) return;

      final List<_KajianVideo> effectiveVideos =
          loadedVideos.isNotEmpty ? loadedVideos : _fallbackVideos;

      setState(() {
        _videos = effectiveVideos;
        _selectedVideo = effectiveVideos.isNotEmpty ? effectiveVideos.first : null;
        _loading = false;
      });

      if (_selectedVideo != null) {
        // Ready
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _videos = _fallbackVideos;
        _selectedVideo = _fallbackVideos.first;
        _loading = false;
      });
    }
  }

  void _selectVideo(_KajianVideo video) {
    if (_selectedVideo?.id == video.id) {
      return;
    }
    setState(() => _selectedVideo = video);
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Cegah crash pada Windows/Linux (karena webview_flutter butuh Android/iOS emulator)
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text('Kajian Averroes', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
          backgroundColor: const Color(0xFFF8FAFC),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: const _KajianStateCard(
              icon: Symbols.desktop_windows,
              title: 'Platform Tidak Didukung',
              message: 'Pemutar video (WebView) belum mendukung Windows Desktop secara bawaan. Harap jalankan menggunakan Emulator Android atau iOS.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFFF8FAFC),
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: <Widget>[
                  _HeaderIconButton(
                    icon: Symbols.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Kajian Averroes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Video kajian selaras dengan pandangan syariah',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _KajianStateCard(
        icon: Symbols.progress_activity,
        title: 'Memuat Kajian',
        message: 'Daftar video kajian sedang diambil dari backend.',
      );
    }

    if (_selectedVideo == null) {
      return const _KajianStateCard(
        icon: Symbols.smart_display,
        title: 'Belum Ada Kajian',
        message:
            'Input data kajian dulu lewat panel admin dengan judul, deskripsi, dan link YouTube.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          onTap: () async {
            final uri = Uri.parse('https://www.youtube.com/watch?v=${_selectedVideo!.id}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x1A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.network(
                      _selectedVideo!.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E293B)),
                    ),
                    Container(color: Colors.black.withValues(alpha: 0.45)),
                    const Center(
                      child: Icon(Symbols.play_circle_filled, size: 64, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _KajianDetailCard(video: _selectedVideo!),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Kajian Lainnya',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_videos.length} video',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._videos.map(
          (_KajianVideo video) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _KajianCard(
              video: video,
              selected: _selectedVideo?.id == video.id,
              onTap: () => _selectVideo(video),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF475569)),
      ),
    );
  }
}

class _KajianStateCard extends StatelessWidget {
  const _KajianStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: const Color(0xFF047857)),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
              height: 1.6,
            ),
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class _KajianDetailCard extends StatelessWidget {
  const _KajianDetailCard({required this.video});

  final _KajianVideo video;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              video.category,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF047857),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            video.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Icon(
                Symbols.smart_display,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  video.channel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                video.duration,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            video.description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _KajianCard extends StatelessWidget {
  const _KajianCard({
    required this.video,
    required this.selected,
    required this.onTap,
  });

  final _KajianVideo video;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    video.thumbnailUrl,
                    width: 144,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 144,
                      height: 88,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Symbols.play_circle,
                        size: 34,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Symbols.play_arrow,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Play',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      video.duration,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    video.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF064E3B)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF064E3B)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      selected ? 'Sedang Dipilih' : video.category,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            selected ? Colors.white : const Color(0xFF475569),
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

class _KajianVideo {
  const _KajianVideo({
    required this.id,
    required this.title,
    required this.channel,
    required this.duration,
    required this.category,
    required this.description,
  });

  final String id;
  final String title;
  final String channel;
  final String duration;
  final String category;
  final String description;

  static _KajianVideo? fromApi(Map<String, dynamic> json) {
    final String youtubeUrl = (json['youtube_url'] as String? ?? '').trim();
    final String? videoId = _extractYoutubeId(youtubeUrl);
    if (videoId == null || videoId.isEmpty) {
      return null;
    }

    return _KajianVideo(
      id: videoId,
      title: (json['judul'] as String? ?? '').trim().isNotEmpty
          ? (json['judul'] as String).trim()
          : 'Kajian Averroes',
      channel: (json['channel'] as String? ?? '').trim().isNotEmpty
          ? (json['channel'] as String).trim()
          : 'Averroes',
      duration: (json['durasi_label'] as String? ?? '').trim().isNotEmpty
          ? (json['durasi_label'] as String).trim()
          : 'Kajian',
      category: (json['kategori'] as String? ?? '').trim().isNotEmpty
          ? (json['kategori'] as String).trim()
          : 'Kajian',
      description: (json['deskripsi'] as String? ?? '').trim().isNotEmpty
          ? (json['deskripsi'] as String).trim()
          : 'Belum ada deskripsi kajian.',
    );
  }

  String get thumbnailUrl => 'https://img.youtube.com/vi/$id/hqdefault.jpg';

  static String? _extractYoutubeId(String url) {
    if (url.isEmpty) return null;

    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return null;

    if ((uri.host.contains('youtube.com') ||
            uri.host.contains('m.youtube.com')) &&
        uri.queryParameters['v'] != null) {
      final String? id = uri.queryParameters['v'];
      if (id != null && id.length == 11) {
        return id;
      }
    }

    if (uri.host.contains('youtu.be')) {
      final String id =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
      if (id.length == 11) {
        return id;
      }
    }

    final List<String> segments = uri.pathSegments;
    if (segments.length >= 2 &&
        (segments.first == 'embed' || segments.first == 'shorts')) {
      final String id = segments[1];
      if (id.length == 11) {
        return id;
      }
    }

    return null;
  }
}
