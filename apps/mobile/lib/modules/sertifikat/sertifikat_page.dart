import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';

class HalamanSertifikat extends StatefulWidget {
  const HalamanSertifikat({super.key});

  @override
  State<HalamanSertifikat> createState() => _HalamanSertifikatState();
}

class _HalamanSertifikatState extends State<HalamanSertifikat> {
  final Dio _dio = ApiDio.create();
  bool _loading = true;
  String? _error;
  List<_UserCertificate> _items = <_UserCertificate>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rs = await _dio.get<dynamic>('/api/sertifikat/saya');
      final data = rs.data;
      final rows = (data is Map ? data['data'] : null);
      final list = rows is List ? rows : const [];
      _items = list
          .whereType<Map>()
          .map((e) => _UserCertificate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      _error = e.response?.data is Map
          ? ((e.response!.data as Map)['message']?.toString() ?? 'Gagal memuat sertifikat.')
          : 'Gagal memuat sertifikat.';
    } catch (_) {
      _error = 'Gagal memuat sertifikat.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCertView(_UserCertificate cert) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _SertifikatViewPage(cert: cert),
      ),
    );
  }

  Future<void> _openDownload(_UserCertificate cert) async {
    if (cert.downloadUrl == null || cert.downloadUrl!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL download tidak tersedia')),
      );
      return;
    }
    final String base = AppConfig.apiBaseUrl;
    final String fullUrl = cert.downloadUrl!.startsWith('http')
        ? cert.downloadUrl!
        : '$base${cert.downloadUrl}';

    // Append auth token
    final String? token = AuthService.instance.token;
    final uri = Uri.parse(fullUrl);
    
    if (token != null && token.isNotEmpty) {
      // Open in browser with auth — use WebView
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _SertifikatWebViewPage(
            url: fullUrl,
            title: cert.namaSertifikat,
          ),
        ),
      );
    } else {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        title: Text(
          'Sertifikat Saya',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Symbols.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.workspace_premium, color: Color(0xFF13ECB9)),
                  const SizedBox(width: 10),
                  Text(
                    'Total Sertifikat: ${_items.length}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (!_loading && _error != null)
              _ErrorCard(message: _error!, onRetry: _load),
            if (!_loading && _error == null && _items.isEmpty)
              const _EmptyCard(text: 'Belum ada sertifikat. Selesaikan kuis dengan nilai >= 95%.'),
            if (!_loading && _error == null)
              ..._items.map((item) => _CertCard(
                item: item,
                onView: () => _openCertView(item),
                onDownload: () => _openDownload(item),
              )),
          ],
        ),
      ),
    );
  }
}

class _UserCertificate {
  _UserCertificate({
    required this.kelas,
    required this.namaSertifikat,
    required this.nomor,
    required this.scorePercent,
    this.generatedAt,
    this.downloadUrl,
    this.kelasId,
    this.userId,
  });

  final String kelas;
  final String namaSertifikat;
  final String nomor;
  final int scorePercent;
  final String? generatedAt;
  final String? downloadUrl;
  final String? kelasId;
  final String? userId;

  factory _UserCertificate.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    String? parseNullable(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return _UserCertificate(
      kelas: (json['kelas'] ?? '-').toString(),
      namaSertifikat: (json['nama_sertifikat'] ?? '-').toString(),
      nomor: (json['nomor'] ?? '-').toString(),
      scorePercent: parseInt(json['score_percent']),
      generatedAt: parseNullable(json['generated_at']),
      downloadUrl: parseNullable(json['download_url']),
      kelasId: parseNullable(json['kelas_id']),
      userId: parseNullable(json['user_id']),
    );
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard({
    required this.item,
    required this.onView,
    required this.onDownload,
  });

  final _UserCertificate item;
  final VoidCallback onView;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF065F46), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Symbols.workspace_premium, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.kelas,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.namaSertifikat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                _InfoChip(
                  icon: Symbols.verified,
                  label: 'Nilai: ${item.scorePercent}%',
                  color: const Color(0xFF059669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No: ${item.nomor}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (item.generatedAt != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Terbit: ${_formatDate(item.generatedAt!)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ),
          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Symbols.visibility, size: 16),
                    label: Text(
                      'Lihat Sertifikat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF065F46),
                      side: const BorderSide(color: Color(0xFFA7F3D0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Symbols.download, size: 16),
                    label: Text(
                      'Download',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF065F46),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr;
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── View Certificate ───────────────────────────────────────────────────────

class _SertifikatViewPage extends StatelessWidget {
  const _SertifikatViewPage({required this.cert});

  final _UserCertificate cert;

  @override
  Widget build(BuildContext context) {
    final namaUser = AuthService.instance.namaUser;
    final formattedDate = _formatDate(cert.generatedAt ?? '');

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0FDF4),
        elevation: 0,
        foregroundColor: const Color(0xFF065F46),
        title: Text(
          'Sertifikat',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF065F46), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A065F46),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top accent
              Container(
                height: 6,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF13ECB9), Color(0xFF065F46)],
                  ),
                ),
              ),
              // Logo
              Text(
                '✦ AVERROES ✦',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF065F46),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                cert.namaSertifikat,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Platform Edukasi Aset Kripto Syariah',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 28),
              // Given to
              Text(
                'DIBERIKAN KEPADA',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF9CA3AF),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF13ECB9), width: 2),
                  ),
                ),
                child: Text(
                  namaUser,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0D1B18),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Class
              Text(
                'Telah menyelesaikan kelas:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cert.kelas,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF065F46),
                ),
              ),
              const SizedBox(height: 14),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Text(
                  'Nilai: ${cert.scorePercent}%',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF065F46),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Footer
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFD1D5DB), width: 1, style: BorderStyle.solid),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          formattedDate,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tanggal Terbit',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    // Seal
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF065F46), Color(0xFF13ECB9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'LULUS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          cert.nomor.length > 16
                              ? '${cert.nomor.substring(0, 16)}...'
                              : cert.nomor,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nomor Sertifikat',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bottom accent
              const SizedBox(height: 24),
              Container(
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF065F46), Color(0xFF13ECB9), Color(0xFF065F46)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr.isEmpty ? '-' : dateStr;
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// ─── WebView for Download ───────────────────────────────────────────────────

class _SertifikatWebViewPage extends StatelessWidget {
  const _SertifikatWebViewPage({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Symbols.open_in_new),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.workspace_premium, size: 64, color: Color(0xFF065F46)),
            const SizedBox(height: 16),
            Text(
              'Sertifikat siap di-download',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF065F46),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Tekan tombol di bawah untuk membuka sertifikat di browser.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Symbols.open_in_browser),
              label: Text(
                'Buka di Browser',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF065F46),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared Widgets ─────────────────────────────────────────────────────────

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
          Text(message, style: GoogleFonts.plusJakartaSans(color: const Color(0xFFB91C1C))),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Symbols.workspace_premium, size: 40, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}
