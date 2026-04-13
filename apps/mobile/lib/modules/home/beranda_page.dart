import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide Response;
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:averroes_core/averroes_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/config/app_config.dart';
import '../../app/routes/app_routes.dart';
import '../../app/services/api_dio.dart';
import '../../app/services/auth_service.dart';
import '../../app/services/shalat_notification_service.dart';
import '../../app/widgets/guest_guard.dart';
import '../portofolio/portofolio_api.dart';
import '../portofolio/portofolio_sync.dart';
import '../edukasi/edukasi_api.dart';

class _BerandaUi {
  const _BerandaUi._();

  static const double screenPadding = 20;
  static const double sectionGap = 20;
  static const Color softLine = AppColors.line;
}

String _normalizeNewsText(String raw) {
  return raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _extractNewsSummary(Map<String, dynamic> item) {
  final String judul = (item['judul'] as String?)?.trim() ?? '';
  final String ringkasan = (item['ringkasan'] as String?)?.trim() ?? '';
  if (ringkasan.isEmpty) {
    return '';
  }
  if (_normalizeNewsText(ringkasan) == _normalizeNewsText(judul)) {
    return '';
  }
  return ringkasan;
}

Future<List<Map<String, dynamic>>> _fetchSupabaseNewsItems({
  required int perPage,
}) async {
  final List<dynamic> rows = await Supabase.instance.client
      .from('news_items')
      .select(
          'id,title,summary,content,source_url,source_name,image_url,provider,published_at')
      .order('published_at', ascending: false)
      .limit(perPage);

  return rows.whereType<Map>().map((Map row) {
    final Map<String, dynamic> item = <String, dynamic>{
      'id': row['id']?.toString() ?? '',
      'judul': row['title']?.toString() ?? '-',
      'ringkasan': row['summary']?.toString() ?? '',
      'konten': row['content']?.toString() ?? '',
      'source_url': row['source_url']?.toString() ?? '',
      'source_name': row['source_name']?.toString(),
      'image_url': row['image_url']?.toString(),
      'provider': row['provider']?.toString(),
      'published_at': row['published_at']?.toString(),
    };
    return item;
  }).toList();
}

String _formatPublishedAt(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) {
    return '';
  }
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) {
    return value;
  }
  final DateTime local = parsed.toLocal();
  const List<String> bulan = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final String jam = local.hour.toString().padLeft(2, '0');
  final String menit = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${bulan[local.month - 1]} ${local.year}, $jam:$menit';
}

String _extractNewsDate(Map<String, dynamic> item) {
  final String tanggalAsli = (item['tanggal_asli'] as String?)?.trim() ?? '';
  if (tanggalAsli.isNotEmpty) {
    return tanggalAsli;
  }
  return _formatPublishedAt((item['published_at'] as String?)?.trim() ?? '');
}

String _extractNewsSource(Map<String, dynamic> item) {
  final String sumberNama = (item['sumber_nama'] as String?)?.trim() ?? '';
  if (sumberNama.isNotEmpty) {
    return sumberNama;
  }
  final String sourceName = (item['source_name'] as String?)?.trim() ?? '';
  if (sourceName.isNotEmpty) {
    return sourceName;
  }
  final String judul = (item['judul'] as String?)?.trim() ?? '';
  if (judul.contains(' - ')) {
    final String suffix = judul.split(' - ').last.trim();
    if (suffix.isNotEmpty && suffix.length <= 64) {
      return suffix;
    }
  }
  return (item['penulis'] as String?)?.trim() ?? '';
}

String _extractNewsSourceUrl(Map<String, dynamic> item) {
  return ((item['source_url'] ?? item['sumber_url']) as String?)?.trim() ?? '';
}

Future<bool> _openNewsSourceUrl(Map<String, dynamic> item) async {
  final String sourceUrl = _extractNewsSourceUrl(item);
  if (sourceUrl.isEmpty) {
    return false;
  }
  final Uri? uri = Uri.tryParse(sourceUrl);
  if (uri == null) {
    return false;
  }
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Row(
                children: <Widget>[
                  if (leadingIcon != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        leadingIcon,
                        size: 18,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.slate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      backgroundColor: backgroundColor,
      border: BorderSide(color: borderColor),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: foregroundColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: foregroundColor),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: foregroundColor,
            ),
            textAlign: TextAlign.center,
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

class HalamanBeranda extends StatelessWidget {
  const HalamanBeranda({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: Container(
        color: AppColors.background,
        child: CustomScrollView(
          slivers: <Widget>[
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderBerandaDelegate(
                topPadding: MediaQuery.of(context).padding.top,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _BerandaUi.screenPadding,
                  16,
                  _BerandaUi.screenPadding,
                  140,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _KartuJadwalShalat(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _KartuPortofolio(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _GridFitur(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _KartuLanjutkanBelajar(),
                    const SizedBox(height: _BerandaUi.sectionGap),
                    _BagianBeritaTerbaru(),
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

class _HeaderBerandaDelegate extends SliverPersistentHeaderDelegate {
  _HeaderBerandaDelegate({required this.topPadding});

  final double topPadding;

  @override
  double get minExtent => topPadding + 70;

  @override
  double get maxExtent => topPadding + 70;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.85),
            border: const Border(
              bottom: BorderSide(
                color: AppColors.line,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emerald,
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x16000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                          border: Border.all(
                              color: AppColors.emeraldSoft, width: 2),
                        ),
                        child: const Icon(
                          Symbols.person,
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'assalamualaikum'.tr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    AuthService.instance.namaUser,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.slate,
                                    ),
                                  ),
                                ),
                                if (AuthService
                                    .instance.adalahTamu) ...<Widget>[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.amberSoft,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                          color: AppColors.amber
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      'guest_mode'.tr,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Get.toNamed(RuteAplikasi.notifikasi),
                  child: Stack(
                    children: <Widget>[
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.lineDark),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x0A0F172A),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Symbols.notifications_active,
                          color: AppColors.inkSoft,
                          size: 20,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: AppColors.surface, width: 2),
                          ),
                        ),
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

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}

class _KartuJadwalShalat extends StatefulWidget {
  @override
  State<_KartuJadwalShalat> createState() => _KartuJadwalShalatState();
}

class _KartuJadwalShalatState extends State<_KartuJadwalShalat> {
  _PrayerCityData _jakarta =
      const _PrayerCityData(city: 'Jakarta', prayer: 'Subuh', time: '--:--');
  _PrayerCityData _makkah =
      const _PrayerCityData(city: 'Makkah', prayer: 'Subuh', time: '--:--');
  String _hijriDate = '';
  bool _loading = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
  }

  Future<void> _fetchPrayerTimes() async {
    setState(() => _loading = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://api.aladhan.com/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final rs = await Future.wait<Response<dynamic>>([
        dio.get('/timingsByCity', queryParameters: {
          'city': 'Jakarta',
          'country': 'Indonesia',
          'method': 11,
        }),
        dio.get('/timingsByCity', queryParameters: {
          'city': 'Makkah',
          'country': 'Saudi Arabia',
          'method': 4,
        }),
      ]);
      _jakarta = _PrayerCityData.fromAladhan(
        city: 'Jakarta',
        utcOffsetHours: 7,
        raw: rs[0].data,
      );
      _hijriDate = _extractHijriDate(rs[0].data);
      _makkah = _PrayerCityData.fromAladhan(
        city: 'Makkah',
        utcOffsetHours: 3,
        raw: rs[1].data,
      );
      await ShalatNotificationService.instance.scheduleFromAladhanRaw(
        city: 'Jakarta',
        timezoneName: 'Asia/Jakarta',
        raw: rs[0].data,
      );
      await ShalatNotificationService.instance.scheduleFromAladhanRaw(
        city: 'Makkah',
        timezoneName: 'Asia/Riyadh',
        raw: rs[1].data,
      );
      await ShalatNotificationService.instance.debugPrintPending();
      _loadFailed = false;
    } catch (_) {
      _loadFailed = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final badgeDate = _formatDateId(now);
    return CustomCard(
      backgroundColor: AppColors.surface,
      border: BorderSide(color: AppColors.lineDark.withValues(alpha: 0.7)),
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      hasShadow: true,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -24,
            top: -24,
            child: Opacity(
              opacity: 0.1,
              child: Transform.rotate(
                angle: 0.2,
                child: const Icon(
                  Symbols.mosque,
                  size: 120,
                  color: AppColors.emerald,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Symbols.schedule,
                          size: 20,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'prayer_schedule'.tr,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.lineDark.withValues(alpha: 0.85)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _loading ? 'loading'.tr : badgeDate,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                        if (_hijriDate.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            _hijriDate,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_loadFailed) ...<Widget>[
                Text(
                  'failed_load_schedule'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _jakarta.city,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _jakarta.prayer,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _jakarta.time,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          AppColors.line,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          _makkah.city,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(
                              _makkah.prayer,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _makkah.time,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateId(DateTime d) {
    final hari = [
      'mon'.tr,
      'tue'.tr,
      'wed'.tr,
      'thu'.tr,
      'fri'.tr,
      'sat'.tr,
      'sun'.tr
    ];
    final bulan = [
      'jan'.tr,
      'feb'.tr,
      'mar'.tr,
      'apr'.tr,
      'may'.tr,
      'jun'.tr,
      'jul'.tr,
      'aug'.tr,
      'sep'.tr,
      'oct'.tr,
      'nov'.tr,
      'dec'.tr
    ];
    final h = hari[(d.weekday - 1).clamp(0, 6)];
    final b = bulan[(d.month - 1).clamp(0, 11)];
    return '$h, ${d.day} $b';
  }

  String _extractHijriDate(dynamic raw) {
    final data = raw is Map ? raw['data'] : null;
    final date = data is Map ? data['date'] : null;
    final hijri = date is Map ? date['hijri'] : null;
    if (hijri is! Map) return '';

    final day = (hijri['day'] ?? '').toString().trim();
    final year = (hijri['year'] ?? '').toString().trim();
    final monthRaw = hijri['month'];
    final monthName =
        monthRaw is Map ? (monthRaw['en'] ?? '').toString().trim() : '';
    if (day.isEmpty || year.isEmpty || monthName.isEmpty) return '';
    return '$day $monthName $year H';
  }
}

class _PrayerCityData {
  const _PrayerCityData({
    required this.city,
    required this.prayer,
    required this.time,
  });

  final String city;
  final String prayer;
  final String time;

  factory _PrayerCityData.fromAladhan({
    required String city,
    required int utcOffsetHours,
    required dynamic raw,
  }) {
    final data = raw is Map ? raw['data'] : null;
    final timings = data is Map ? data['timings'] : null;
    final timingMap = timings is Map ? timings : const {};
    const prayerOrder = <String>[
      'Fajr',
      'Dhuhr',
      'Asr',
      'Maghrib',
      'Isha',
    ];
    const prayerLabel = <String, String>{
      'Fajr': 'Subuh',
      'Dhuhr': 'Dzuhur',
      'Asr': 'Ashar',
      'Maghrib': 'Maghrib',
      'Isha': 'Isya',
    };

    final nowUtc = DateTime.now().toUtc();
    final cityNow = nowUtc.add(Duration(hours: utcOffsetHours));
    final cityNowMinutes = (cityNow.hour * 60) + cityNow.minute;
    String chosenPrayer = 'Maghrib';
    String chosenTime = '--';

    for (final key in prayerOrder) {
      final rawValue =
          (timingMap[key] ?? '').toString().split(' ').first.trim();
      final hhmm = _parseHourMinute(rawValue);
      if (hhmm == null) continue;
      final prayerMinutes = (hhmm.$1 * 60) + hhmm.$2;
      if (prayerMinutes > cityNowMinutes) {
        chosenPrayer = key;
        chosenTime = _formatHm(hhmm.$1, hhmm.$2);
        break;
      }
    }

    if (chosenTime == '--') {
      final rawFajr =
          (timingMap['Fajr'] ?? '').toString().split(' ').first.trim();
      final hhmm = _parseHourMinute(rawFajr);
      if (hhmm != null) {
        chosenPrayer = 'Fajr';
        chosenTime = _formatHm(hhmm.$1, hhmm.$2);
      }
    }

    return _PrayerCityData(
      city: city,
      prayer: prayerLabel[chosenPrayer] ?? chosenPrayer,
      time: chosenTime,
    );
  }

  static (int, int)? _parseHourMinute(String value) {
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }

  static String _formatHm(int h, int m) {
    final hs = h.toString().padLeft(2, '0');
    final ms = m.toString().padLeft(2, '0');
    return '$hs:$ms';
  }
}

class _GridFitur extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool isTamu = AuthService.instance.adalahTamu;
    const List<Color> paletSenada = <Color>[
      Color(0xFFEAFBF6),
      Color(0xFFE3F8F2),
      Color(0xFFDCF4EE),
      Color(0xFFD5F1EA),
    ];

    final List<_ItemFitur> fitur = <_ItemFitur>[
      _ItemFitur(
        judul: 'screener'.tr,
        ikon: Symbols.rule_folder,
        warna: paletSenada[0],
        tujuan: RuteAplikasi.penyaring,
      ),
      _ItemFitur(
        judul: 'market'.tr,
        ikon: Symbols.candlestick_chart,
        warna: paletSenada[1],
        tujuan: RuteAplikasi.pasar,
      ),
      _ItemFitur(
        judul: 'library'.tr,
        ikon: Symbols.menu_book,
        warna: paletSenada[2],
        tujuan: RuteAplikasi.pustaka,
      ),
      _ItemFitur(
        judul: 'chatbot'.tr,
        ikon: Symbols.smart_toy,
        warna: paletSenada[3],
        tujuan: RuteAplikasi.chatbot,
      ),
      _ItemFitur(
        judul: 'zakat'.tr,
        ikon: Symbols.calculate,
        warna: paletSenada[1],
        tujuan: RuteAplikasi.zakat,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'psychologist'.tr,
        ikon: Symbols.psychology,
        warna: paletSenada[0],
        tujuan: RuteAplikasi.psikolog,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'consultation'.tr,
        ikon: Symbols.support_agent,
        warna: paletSenada[2],
        tujuan: RuteAplikasi.konsultasi,
        terbatasGuest: true,
      ),
      _ItemFitur(
        judul: 'dhikr'.tr,
        ikon: Symbols.smart_display,
        warna: paletSenada[3],
        tujuan: RuteAplikasi.kajian,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: 'main_features'.tr,
          leadingIcon: Symbols.apps,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: fitur.length,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            childAspectRatio: 0.68,
          ),
          itemBuilder: (BuildContext context, int index) {
            final _ItemFitur item = fitur[index];
            final bool terkunci = isTamu && item.terbatasGuest;

            return CustomCard(
              onTap: () {
                if (cekAksesGuest(context, item.tujuan)) {
                  return;
                }
                Get.toNamed(item.tujuan);
              },
              padding: const EdgeInsets.all(12),
              backgroundColor: terkunci ? AppColors.cloud : AppColors.surface,
              border: BorderSide(
                color: terkunci
                    ? AppColors.line
                    : AppColors.lineDark.withValues(alpha: 0.7),
              ),
              borderRadius: 16,
              hasShadow: !terkunci,
              child: Stack(
                children: <Widget>[
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: terkunci
                                ? AppColors.line.withValues(alpha: 0.5)
                                : item.warna,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: terkunci
                                  ? AppColors.line
                                  : AppColors.emeraldSoft,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            item.ikon,
                            size: 21,
                            color: terkunci ? AppColors.muted : AppColors.slate,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.judul,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color:
                                terkunci ? AppColors.muted : AppColors.inkSoft,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (terkunci)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.emeraldSoft,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.emerald.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Symbols.lock,
                          size: 11,
                          color: AppColors.emerald,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _KartuLanjutkanBelajar extends StatefulWidget {
  @override
  State<_KartuLanjutkanBelajar> createState() => _KartuLanjutkanBelajarState();
}

class _KartuLanjutkanBelajarState extends State<_KartuLanjutkanBelajar> {
  final EdukasiApi _api = EdukasiApi();
  LastLearningEdukasi? _last;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!AuthService.instance.sudahLogin) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _last = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _api.fetchLastLearning();
      if (!mounted) return;
      setState(() => _last = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _last = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdukasi() async {
    await Get.toNamed(RuteAplikasi.edukasi);
    await _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _loading
        ? 'loading_last_class'.tr
        : _last == null
            ? 'no_material_progress'.tr
            : "${'class_label'.tr}${_last!.kelasJudul} "
                "${'material_label'.tr}${_last!.nextMateriIndex}/${_last!.totalMateri}";
    return CustomCard(
      onTap: _openEdukasi,
      padding: const EdgeInsets.all(20),
      backgroundColor: AppColors.emeraldSoft,
      border: BorderSide(color: AppColors.emerald.withValues(alpha: 0.15)),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.emerald,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Symbols.menu_book,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'continue_learning'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Symbols.chevron_right,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _ItemFitur {
  const _ItemFitur({
    required this.judul,
    required this.ikon,
    required this.warna,
    required this.tujuan,
    this.terbatasGuest = false,
  });

  final String judul;
  final IconData ikon;
  final Color warna;
  final String tujuan;
  final bool terbatasGuest;
}

class _BagianBeritaTerbaru extends StatefulWidget {
  @override
  State<_BagianBeritaTerbaru> createState() => _BagianBeritaTerbaruState();
}

class _BagianBeritaTerbaruState extends State<_BagianBeritaTerbaru> {
  List<Map<String, dynamic>> _beritaList = <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchBerita();
  }

  Future<void> _fetchBerita() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (AppConfig.isSupabaseNativeEnabled) {
        final List<Map<String, dynamic>> rows =
            await _fetchSupabaseNewsItems(perPage: 5);
        setState(() {
          _beritaList = rows;
          _isLoading = false;
        });
        return;
      }

      final Dio dio = ApiDio.create(attachAuthToken: false);
      final Response<dynamic> response = await dio.get<dynamic>(
        '${AppConfig.apiBaseUrl}/api/berita?per_page=5',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;

        final dynamic rawStatus = data['status'];
        final bool isSuccess = rawStatus == true ||
            rawStatus?.toString().toLowerCase() == 'success';

        if (isSuccess && data['data'] != null) {
          final Map<String, dynamic> innerData =
              data['data'] as Map<String, dynamic>;
          final List<dynamic> beritaRaw = (innerData['berita'] is List<dynamic>)
              ? innerData['berita'] as List<dynamic>
              : (innerData['items'] as List<dynamic>? ?? <dynamic>[]);

          setState(() {
            _beritaList = beritaRaw
                .map((dynamic e) => e as Map<String, dynamic>)
                .toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = data['pesan']?.toString() ??
                data['message']?.toString() ??
                'failed_load_news'.tr;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'failed_load_news'.tr;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'cannot_connect_server'.tr;
        _isLoading = false;
      });
    }
  }

  Future<void> _bukaDetailBerita(Map<String, dynamic> item) async {
    if (await _openNewsSourceUrl(item)) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HalamanDetailBerita(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionHeader(
          title: 'crypto_asset_news'.tr,
          subtitle: 'source_google_news'.tr,
          leadingIcon: Symbols.newspaper,
          trailing: !_isLoading
              ? GestureDetector(
                  onTap: _fetchBerita,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1FAE5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(
                          Symbols.refresh,
                          size: 14,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'refresh'.tr,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          _buildLoadingShimmer()
        else if (_errorMessage != null)
          _buildError()
        else if (_beritaList.isEmpty)
          _buildEmpty()
        else ...[
          ..._beritaList.map(
            (Map<String, dynamic> item) => _buildKartuBerita(item),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const _HalamanDaftarBeritaTerbaru(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _BerandaUi.softLine),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Symbols.newspaper,
                      size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Text(
                    'see_news'.tr,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Symbols.arrow_forward,
                      size: 14, color: Color(0xFF059669)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List<Widget>.generate(
        3,
        (int i) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _BerandaUi.softLine),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 150,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return _StateCard(
      icon: Symbols.cloud_off,
      message: _errorMessage ?? 'error_loading_news'.tr,
      backgroundColor: const Color(0xFFFEF2F2),
      borderColor: const Color(0xFFFECACA),
      foregroundColor: const Color(0xFFB91C1C),
      action: GestureDetector(
        onTap: _fetchBerita,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'try_again'.tr,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return _StateCard(
      icon: Symbols.article,
      message: 'no_latest_news'.tr,
      backgroundColor: Colors.white,
      borderColor: _BerandaUi.softLine,
      foregroundColor: AppColors.muted,
    );
  }

  Widget _buildKartuBerita(Map<String, dynamic> item) {
    final String judul = (item['judul'] as String?) ?? '';
    final String ringkasan = _extractNewsSummary(item);
    final String penulis = _extractNewsSource(item);
    final String tanggal = _extractNewsDate(item);
    final String gambarUrl = ((item['gambar_url'] ??
            item['thumbnail'] ??
            item['image_url'] ??
            item['urlToImage']) as String?) ??
        '';

    return CustomCard(
      onTap: () => _bukaDetailBerita(item),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      hasShadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: gambarUrl.isNotEmpty
                ? Image.network(
                    gambarUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error,
                        StackTrace? stackTrace) {
                      return Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Symbols.newspaper,
                          size: 28,
                          color: Color(0xFF059669),
                        ),
                      );
                    },
                  )
                : Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Symbols.newspaper,
                      size: 28,
                      color: Color(0xFF059669),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // Konten
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  judul,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ringkasan.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    ringkasan,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    if (penulis.isNotEmpty) ...[
                      const Icon(
                        Symbols.person,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          penulis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    if (penulis.isNotEmpty && tanggal.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: Color(0xFFCBD5E1),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    if (tanggal.isNotEmpty)
                      Flexible(
                        child: Text(
                          tanggal,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Symbols.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}

class _HalamanDaftarBeritaTerbaru extends StatefulWidget {
  const _HalamanDaftarBeritaTerbaru();

  @override
  State<_HalamanDaftarBeritaTerbaru> createState() =>
      _HalamanDaftarBeritaTerbaruState();
}

class _HalamanDaftarBeritaTerbaruState
    extends State<_HalamanDaftarBeritaTerbaru> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (AppConfig.isSupabaseNativeEnabled) {
        final List<Map<String, dynamic>> rows =
            await _fetchSupabaseNewsItems(perPage: 20);
        setState(() {
          _items = rows;
          _loading = false;
        });
        return;
      }
      final Dio dio = ApiDio.create(attachAuthToken: false);
      final Response<dynamic> response = await dio.get<dynamic>(
        '/api/berita?per_page=20',
      );
      final raw = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      final data = raw['data'];
      final rows = data is Map
          ? (data['items'] as List<dynamic>? ?? <dynamic>[])
          : <dynamic>[];
      setState(() {
        _items = rows
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'failed_load_news'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    if (await _openNewsSourceUrl(item)) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HalamanDetailBerita(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'latest_20_news'.tr,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: _StateCard(
                  icon: Symbols.newspaper,
                  message: 'Kami sedang menyiapkan kabar terbaru untuk kamu.',
                  backgroundColor: Colors.white,
                  borderColor: Color(0xFFE2E8F0),
                  foregroundColor: Color(0xFF475569),
                ),
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: _StateCard(
                      icon: Symbols.cloud_off,
                      message: _error!,
                      backgroundColor: Color(0xFFFEF2F2),
                      borderColor: Color(0xFFFECACA),
                      foregroundColor: Color(0xFFB91C1C),
                      action: GestureDetector(
                        onTap: _fetch,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'try_again'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: _StateCard(
                          icon: Symbols.newspaper,
                          message: 'Belum ada berita baru saat ini.',
                          backgroundColor: Colors.white,
                          borderColor: Color(0xFFE2E8F0),
                          foregroundColor: Color(0xFF475569),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final judul = (item['judul'] as String?) ?? '';
                        final ringkasan = _extractNewsSummary(item);
                        final tanggal = _extractNewsDate(item);
                        final sumber = _extractNewsSource(item);
                        final gambarUrl = ((item['gambar_url'] ??
                                item['thumbnail'] ??
                                item['image_url'] ??
                                item['urlToImage']) as String?) ??
                            '';
                        return GestureDetector(
                          onTap: () => _openDetail(item),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border:
                                  Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: gambarUrl.isNotEmpty
                                      ? Image.network(
                                          gambarUrl,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _newsThumbFallback(),
                                        )
                                      : _newsThumbFallback(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        judul,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (ringkasan.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          ringkasan,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: <Widget>[
                                          if (sumber.isNotEmpty)
                                            Flexible(
                                              child: Text(
                                                sumber,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF64748B),
                                                ),
                                              ),
                                            ),
                                          if (sumber.isNotEmpty &&
                                              tanggal.isNotEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6),
                                              child: Container(
                                                width: 3,
                                                height: 3,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFCBD5E1),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            ),
                                          if (tanggal.isNotEmpty)
                                            Flexible(
                                              child: Text(
                                                tanggal,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  color:
                                                      const Color(0xFF94A3B8),
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
                        );
                      },
                    ),
    );
  }

  Widget _newsThumbFallback() => Container(
        width: 72,
        height: 72,
        color: const Color(0xFFECFDF5),
        child: const Icon(Symbols.newspaper, color: Color(0xFF059669)),
      );
}

class _HalamanDetailBerita extends StatefulWidget {
  const _HalamanDetailBerita({required this.item});

  final Map<String, dynamic> item;

  @override
  State<_HalamanDetailBerita> createState() => _HalamanDetailBeritaState();
}

class _HalamanDetailBeritaState extends State<_HalamanDetailBerita> {
  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> item = widget.item;
    final String judul = (item['judul'] as String?)?.trim() ?? 'Berita';
    final String ringkasan = _extractNewsSummary(item);
    final String tanggal = _extractNewsDate(item);
    final String sumberNama = _extractNewsSource(item);
    final String sumberUrl = _extractNewsSourceUrl(item);
    final String gambarUrl = ((item['gambar_url'] ??
                item['thumbnail'] ??
                item['image_url'] ??
                item['urlToImage']) as String?)
            ?.trim() ??
        '';
    final String isi = _cleanArticleText(ringkasan);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'news_detail'.tr,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          if (gambarUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                gambarUrl,
                height: 190,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _detailThumbFallback(),
              ),
            )
          else
            _detailThumbFallback(),
          const SizedBox(height: 14),
          Text(
            judul,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              height: 1.25,
            ),
          ),
          if (sumberNama.isNotEmpty || tanggal.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (sumberNama.isNotEmpty)
                  _DetailMetaChip(
                    icon: Symbols.public,
                    label: sumberNama,
                  ),
                if (tanggal.isNotEmpty)
                  _DetailMetaChip(
                    icon: Symbols.schedule,
                    label: tanggal,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'news_preview_title'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  isi.isEmpty ? 'no_content_available'.tr : isi,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF334155),
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'news_preview_notice'.tr,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (sumberUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(sumberUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Symbols.open_in_new, size: 18),
              label: Text(
                'open_original_source'.tr,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailThumbFallback() {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Symbols.newspaper, size: 44, color: Color(0xFF059669)),
    );
  }

  String _cleanArticleText(String raw) {
    final String noTags = raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final lines = noTags
        .split('\n')
        .map((e) => e.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return lines.join('\n\n').trim();
  }
}

class _DetailMetaChip extends StatelessWidget {
  const _DetailMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPortofolio extends StatefulWidget {
  @override
  State<_KartuPortofolio> createState() => _KartuPortofolioState();
}

class _KartuPortofolioState extends State<_KartuPortofolio> {
  final PortofolioApi _portofolioApi = PortofolioApi();
  double _total = 0;
  int _jumlahAset = 0;
  bool _loading = true;
  bool _fetching = false;
  bool _isHidden = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetch();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 8), (_) => _fetch(silent: true));
    PortofolioSync.revision.addListener(_onPortofolioChanged);
  }

  @override
  void dispose() {
    PortofolioSync.revision.removeListener(_onPortofolioChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onPortofolioChanged() {
    _fetch(silent: false);
  }

  Future<void> _fetch({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!AuthService.instance.sudahLogin) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _total = 0;
        _jumlahAset = 0;
      });
      _fetching = false;
      return;
    }
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final result = await _portofolioApi.fetchPortofolio();
      _total = result.totalNilai;
      _jumlahAset = result.items.length;
    } catch (_) {
      _total = 0;
      _jumlahAset = 0;
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPortofolio() async {
    await Get.toNamed(RuteAplikasi.portofolio);
    await _fetch(silent: false);
  }

  String _idr(double v) {
    final raw = v.toStringAsFixed(0);
    final sb = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      sb.write(raw[i]);
      final remain = raw.length - i - 1;
      if (remain > 0 && remain % 3 == 0) sb.write('.');
    }
    return 'Rp ${sb.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final totalLabel = _loading
        ? '...'
        : _isHidden
            ? 'Rp •••••••'
            : _idr(_total);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.lineDark.withValues(alpha: 0.7)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Colors.white,
            Color(0xFFF1FBF6),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -16,
            top: -16,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5).withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDF7EE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFB7E3D3)),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Symbols.account_balance_wallet,
                          color: AppColors.emerald,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'total_portfolio'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _isHidden = !_isHidden),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: AppColors.lineDark.withValues(alpha: 0.7)),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x0D0F172A),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isHidden ? Symbols.visibility : Symbols.visibility_off,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                height: 1,
                color: const Color(0xFFDCEFE8),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _loading
                        ? 'loading_portfolio'.tr
                        : '$_jumlahAset${'crypto_assets'.tr}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                  GestureDetector(
                    onTap: _openPortofolio,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x260F766E),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: <Widget>[
                          Text(
                            'view_portfolio'.tr,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Symbols.arrow_forward,
                            size: 14,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
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
