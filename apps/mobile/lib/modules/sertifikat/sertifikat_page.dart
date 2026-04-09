import 'package:dio/dio.dart';
import 'package:averroes_core/averroes_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config/app_config.dart';
import '../../app/services/api_error_mapper.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';
import '../../app/services/supabase_native_service.dart';

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
      if (AppConfig.isSupabaseNativeEnabled) {
        final String profileId = await SupabaseNativeService.ensureProfileId();
        final List<dynamic> rows = await SupabaseNativeService.client
            .from('user_certificates')
            .select('id,class_id,certificate_name,certificate_number,score_percent,generated_at,download_url')
            .eq('user_id', profileId)
            .order('generated_at', ascending: false);
        final List<String> classIds = rows
            .whereType<Map>()
            .map((Map row) => row['class_id']?.toString() ?? '')
            .where((String id) => id.isNotEmpty)
            .toSet()
            .toList();
        final Map<String, String> classTitles = <String, String>{};
        if (classIds.isNotEmpty) {
          final List<dynamic> classRows = await SupabaseNativeService.client
              .from('classes')
              .select('id,title')
              .inFilter('id', classIds);
          for (final dynamic row in classRows) {
            if (row is! Map) {
              continue;
            }
            final String id = row['id']?.toString() ?? '';
            if (id.isEmpty) {
              continue;
            }
            classTitles[id] = row['title']?.toString() ?? '-';
          }
        }
        _items = rows
            .whereType<Map>()
            .map((Map row) => _UserCertificate.fromSupabase(
                  Map<String, dynamic>.from(row),
                  classTitles: classTitles,
                ))
            .toList();
      } else {
        final rs = await _dio.get<dynamic>('/api/sertifikat/saya');
        final data = rs.data;
        final rows = (data is Map ? data['data'] : null);
        final list = rows is List ? rows : const [];
        _items = list
            .whereType<Map>()
            .map((e) => _UserCertificate.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } on DioException catch (e) {
      _error = ApiErrorMapper.humanize(e, fallback: 'Gagal memuat sertifikat.');
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
    final String fullUrl;
    if (cert.downloadUrl!.startsWith('http') ||
        AppConfig.isSupabaseNativeEnabled) {
      fullUrl = cert.downloadUrl!;
    } else {
      fullUrl = '${AppConfig.apiBaseUrl}${cert.downloadUrl}';
    }

    // Append auth token
    final String? token = AuthService.instance.token;
    final uri = Uri.parse(fullUrl);

    if (token != null && token.isNotEmpty) {
      // Open in browser with auth; use WebView
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.slate,
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
            CustomCard(
              padding: const EdgeInsets.all(14),
              backgroundColor: AppColors.emerald,
              border: const BorderSide(color: AppColors.emeraldDark),
              borderRadius: 14,
              child: Row(
                children: [
                  const Icon(Symbols.workspace_premium, color: Colors.white),
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

  factory _UserCertificate.fromSupabase(
    Map<String, dynamic> json, {
    required Map<String, String> classTitles,
  }) {
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

    final String? classId = parseNullable(json['class_id']);
    return _UserCertificate(
      kelas: classTitles[classId ?? ''] ?? '-',
      namaSertifikat: (json['certificate_name'] ?? '-').toString(),
      nomor: (json['certificate_number'] ?? '-').toString(),
      scorePercent: parseInt(json['score_percent']),
      generatedAt: parseNullable(json['generated_at']),
      downloadUrl: parseNullable(json['download_url']),
      kelasId: classId,
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
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      hasShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.mint),
                ),
                child: const Icon(Symbols.workspace_premium, color: AppColors.emerald, size: 22),
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.namaSertifikat,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _InfoChip(
                icon: Symbols.verified,
                label: 'Nilai: ${item.scorePercent}%',
                color: AppColors.emerald,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No: ${item.nomor}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          if (item.generatedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Terbit: ${_formatDate(item.generatedAt!)}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
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
                    foregroundColor: AppColors.emerald,
                    side: const BorderSide(color: AppColors.mint),
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
                    backgroundColor: AppColors.emerald,
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


class _SertifikatViewPage extends StatelessWidget {
  const _SertifikatViewPage({required this.cert});

  final _UserCertificate cert;

  @override
  Widget build(BuildContext context) {
    final namaUser = AuthService.instance.namaUser;
    final formattedDate = _formatDate(cert.generatedAt ?? '');

    return Scaffold(
      backgroundColor: AppColors.sand,
      appBar: AppBar(
        backgroundColor: AppColors.sand,
        elevation: 0,
        foregroundColor: AppColors.emerald,
        title: Text(
          'Sertifikat',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.emerald, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.emerald.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.emerald,
                ),
              ),
              // Logo
              Text(
                'AVERROES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emerald,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                cert.namaSertifikat,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Platform Edukasi Aset Kripto Syariah',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 28),
              // Given to
              Text(
                'DIBERIKAN KEPADA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.only(bottom: 4),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.emerald, width: 2),
                  ),
                ),
                child: Text(
                  namaUser,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Class
              Text(
                'Telah menyelesaikan kelas:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cert.kelas,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
              const SizedBox(height: 14),
              // Score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldSoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.mint),
                ),
                child: Text(
                  'Nilai: ${cert.scorePercent}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Footer
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.line, width: 1, style: BorderStyle.solid),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          formattedDate,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tanggal Terbit',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
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
                        color: AppColors.emerald,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'LULUS',
                        style: GoogleFonts.plusJakartaSans(
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
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Nomor Sertifikat',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
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
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: AppColors.emerald,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.slate,
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
            const Icon(Symbols.workspace_premium, size: 64, color: AppColors.emerald),
            const SizedBox(height: 16),
            Text(
              'Sertifikat siap di-download',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.emerald,
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
                  color: AppColors.muted,
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
                backgroundColor: AppColors.emerald,
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


class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: const Color(0xFFFEF2F2),
      border: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
      child: Column(
        children: <Widget>[
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(color: AppColors.error),
          ),
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
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Symbols.workspace_premium, size: 40, color: AppColors.lineDark),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}





